import std/[options, strutils, unittest]
import terminal_style
import terminal_widgets
import terminal_widgets/runtime

type ScriptedBackend = ref object of RuntimeBackend
  operations: seq[string]
  events: seq[InputEvent]
  nextEvent: int
  size: Option[TerminalSize]
  frames: seq[Frame]

proc interactiveCapabilities(): TerminalCapabilities =
  TerminalCapabilities(inputIsTerminal: true, outputIsTerminal: true,
    supportsAnsi: true, supportsRawMode: true, supportsResizeEvents: true)

method openOwned(backend: ScriptedBackend) = backend.operations.add "open"
method capabilities(backend: ScriptedBackend): TerminalCapabilities =
  backend.operations.add "capabilities"
  interactiveCapabilities()
method initialSize(backend: ScriptedBackend): Option[TerminalSize] =
  backend.operations.add "size"
  backend.size
method enterAlternateScreen(backend: ScriptedBackend) =
  backend.operations.add "enter-screen"
method hideCursor(backend: ScriptedBackend) = backend.operations.add "hide-cursor"
method disableAutoWrap(backend: ScriptedBackend) =
  backend.operations.add "disable-wrap"
method present(backend: ScriptedBackend; frame: Frame; ownsCursor: bool) =
  backend.operations.add "present:" & $ownsCursor
  backend.frames.add frame
method readInput(backend: ScriptedBackend; timeoutMs: int): InputEvent =
  backend.operations.add "read:" & $timeoutMs
  if backend.nextEvent >= backend.events.len: return endOfInput()
  result = backend.events[backend.nextEvent]
  inc backend.nextEvent
method resetStyles(backend: ScriptedBackend) = backend.operations.add "reset"
method enableAutoWrap(backend: ScriptedBackend) =
  backend.operations.add "enable-wrap"
method showCursor(backend: ScriptedBackend) = backend.operations.add "show-cursor"
method leaveAlternateScreen(backend: ScriptedBackend) =
  backend.operations.add "leave-screen"
method closeOwned(backend: ScriptedBackend) = backend.operations.add "close"

proc scripted(events: openArray[InputEvent];
              size = some(terminalSize(20, 2))): ScriptedBackend =
  ScriptedBackend(events: @events, size: size)

suite "runtime lifecycle and event loop":
  test "owned session acquires presents and restores in exact order":
    let backend = scripted([keyInput(keyUnknown, sequence = "?")])
    let control = newCheckbox(newWidgetId("owned"), "Owned")
    let tree = newWidgetTree(control)
    var callbackCount = 0
    let result = runWidgetsWithBackend(tree, backend,
      onEvents = proc(context: RuntimeEventContext): RunAction =
        inc callbackCount
        check not context.outcome.handled
        check context.input.keyEvent.sequence == "?"
        stopRunning)
    check result.termination == requestedStop
    check result.framesPresented == 1
    check callbackCount == 1
    check backend.operations == @[
      "open", "capabilities", "size", "enter-screen", "hide-cursor",
      "disable-wrap", "present:true", "read:50", "reset", "enable-wrap",
      "show-cursor", "leave-screen", "close"]

  test "timeouts stay idle while resize and value changes redraw once":
    let backend = scripted([
      timeoutInput(),
      resizeInput(terminalSize(12, 1)),
      keyInput(keySpace),
      endOfInput()
    ])
    let control = newCheckbox(newWidgetId("loop"), "Loop")
    let tree = newWidgetTree(control)
    var delivered: seq[WidgetEventKind]
    let result = runWidgetsWithBackend(tree, backend,
      onEvents = proc(context: RuntimeEventContext): RunAction =
        for event in context.outcome.events: delivered.add event.kind
        continueRunning)
    check result.termination == endOfInput
    check result.framesPresented == 3
    check backend.frames.len == 3
    check backend.frames[0].width == 20
    check backend.frames[1].width == 12
    check backend.frames[2].width == 12
    check control.checked
    check delivered == @[boolChanged]

  test "application updates after dispatch trigger layout and one redraw":
    let backend = scripted([keyInput(keyUnknown), endOfInput()])
    let control = newCheckbox(newWidgetId("updated"), "Updated")
    let tree = newWidgetTree(control)
    let result = runWidgetsWithBackend(tree, backend,
      onEvents = proc(context: RuntimeEventContext): RunAction =
        control.setChecked(true)
        continueRunning)
    check result.termination == endOfInput
    check result.framesPresented == 2
    check stripAnsi(backend.frames[^1].rows[0]).contains("[x]")

  test "Ctrl+C cancels before dispatch or application delivery":
    let backend = scripted([keyInput(keyCtrlC)])
    let control = newCheckbox(newWidgetId("cancel"), "Cancel")
    let tree = newWidgetTree(control)
    var delivered = false
    let result = runWidgetsWithBackend(tree, backend,
      onEvents = proc(context: RuntimeEventContext): RunAction =
        delivered = true
        continueRunning)
    check result.termination == cancelled
    check not delivered
    check not control.checked

  test "borrowed caller-owned presentation changes no terminal modes or session":
    let backend = scripted([endOfInput()])
    let tree = newWidgetTree(newCheckbox(newWidgetId("borrowed"), "Borrowed"))
    let result = runWidgetsWithBackend(tree, backend,
      ownedSession = false, ownPresentation = false)
    check result.termination == endOfInput
    check backend.operations == @[
      "capabilities", "size", "present:false", "read:50", "reset"]

  test "fallback geometry and poll validation are explicit":
    let backend = scripted([endOfInput()], none(TerminalSize))
    let tree = newWidgetTree(newCheckbox(newWidgetId("fallback"), "Fallback"))
    var options = defaultRuntimeOptions()
    options.fallbackSize = newSize(33, 7)
    let result = runWidgetsWithBackend(tree, backend, options)
    check result.framesPresented == 1
    check backend.frames[0].width == 33 and backend.frames[0].height == 7

    options.pollTimeoutMs = 0
    expect ValueError:
      discard runWidgetsWithBackend(tree, scripted([endOfInput()]), options)
