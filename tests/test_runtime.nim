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
  failures: seq[string]
  presentCalls: int
  failPresentAt: int
  nonInteractive: bool

proc step(backend: ScriptedBackend; operation: string) =
  backend.operations.add operation
  if operation in backend.failures:
    raise newException(TerminalIOError, "injected " & operation)

proc interactiveCapabilities(): TerminalCapabilities =
  TerminalCapabilities(inputIsTerminal: true, outputIsTerminal: true,
    supportsAnsi: true, supportsRawMode: true, supportsResizeEvents: true)

method openOwned(backend: ScriptedBackend) = backend.step("open")
method capabilities(backend: ScriptedBackend): TerminalCapabilities =
  backend.step("capabilities")
  if backend.nonInteractive: TerminalCapabilities()
  else: interactiveCapabilities()
method initialSize(backend: ScriptedBackend): Option[TerminalSize] =
  backend.step("size")
  backend.size
method enterAlternateScreen(backend: ScriptedBackend) =
  backend.step("enter-screen")
method hideCursor(backend: ScriptedBackend) = backend.step("hide-cursor")
method disableAutoWrap(backend: ScriptedBackend) =
  backend.step("disable-wrap")
method present(backend: ScriptedBackend; frame: Frame; ownsCursor: bool) =
  backend.step("present:" & $ownsCursor)
  inc backend.presentCalls
  if backend.failPresentAt == backend.presentCalls:
    raise newException(TerminalIOError, "injected present #" & $backend.presentCalls)
  backend.frames.add frame
method readInput(backend: ScriptedBackend; timeoutMs: int): InputEvent =
  backend.step("read:" & $timeoutMs)
  if backend.nextEvent >= backend.events.len: return endOfInput()
  result = backend.events[backend.nextEvent]
  inc backend.nextEvent
method resetStyles(backend: ScriptedBackend) = backend.step("reset")
method enableAutoWrap(backend: ScriptedBackend) =
  backend.step("enable-wrap")
method showCursor(backend: ScriptedBackend) = backend.step("show-cursor")
method leaveAlternateScreen(backend: ScriptedBackend) =
  backend.step("leave-screen")
method closeOwned(backend: ScriptedBackend) = backend.step("close")

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

  test "unsupported redirected capabilities close before emitting ANSI":
    let backend = scripted([endOfInput()])
    backend.nonInteractive = true
    let tree = newWidgetTree(newCheckbox(newWidgetId("unsupported"), "No TTY"))
    expect TerminalUnavailableError:
      discard runWidgetsWithBackend(tree, backend)
    check backend.operations == @["open", "capabilities", "close"]
    check backend.frames.len == 0

  test "partial mode and first-presentation failures restore acquired stages":
    for failed in ["enter-screen", "hide-cursor", "disable-wrap", "present:true"]:
      let backend = scripted([endOfInput()])
      backend.failures = @[failed]
      let tree = newWidgetTree(newCheckbox(newWidgetId("partial-" & failed),
        "Partial"))
      expect TerminalIOError:
        discard runWidgetsWithBackend(tree, backend)
      check backend.operations[^1] == "close"
      check "leave-screen" in backend.operations
      if failed in ["hide-cursor", "disable-wrap", "present:true"]:
        check "show-cursor" in backend.operations
      if failed in ["disable-wrap", "present:true"]:
        check "enable-wrap" in backend.operations

  test "open read callback validator and redraw failures all clean up":
    block openFailure:
      let backend = scripted([endOfInput()])
      backend.failures = @["open"]
      let tree = newWidgetTree(newCheckbox(newWidgetId("open-fail"), "Open"))
      expect TerminalIOError:
        discard runWidgetsWithBackend(tree, backend)
      check backend.operations == @["open"]

    block readFailure:
      let backend = scripted([endOfInput()])
      backend.failures = @["read:50"]
      let tree = newWidgetTree(newCheckbox(newWidgetId("read-fail"), "Read"))
      expect TerminalIOError:
        discard runWidgetsWithBackend(tree, backend)
      check backend.operations[^1] == "close"

    block callbackFailure:
      let backend = scripted([keyInput(keyUnknown)])
      let tree = newWidgetTree(newCheckbox(newWidgetId("callback-fail"),
        "Callback"))
      expect ValueError:
        discard runWidgetsWithBackend(tree, backend,
          onEvents = proc(context: RuntimeEventContext): RunAction =
            raise newException(ValueError, "callback failed"))
      check backend.operations[^1] == "close"

    block validatorFailure:
      let backend = scripted([keyInput(keyEnter)])
      let field = newTextField(newWidgetId("validator-fail"),
        validator = proc(value: string): Option[string] =
          raise newException(ValueError, "validator failed"))
      let tree = newWidgetTree(field)
      expect ValueError:
        discard runWidgetsWithBackend(tree, backend)
      check backend.operations[^1] == "close"

    block redrawFailure:
      let backend = scripted([keyInput(keySpace)])
      backend.failPresentAt = 2
      let tree = newWidgetTree(newCheckbox(newWidgetId("redraw-fail"),
        "Redraw"))
      expect TerminalIOError:
        discard runWidgetsWithBackend(tree, backend)
      check backend.presentCalls == 2
      check backend.operations[^1] == "close"

  test "cleanup attempts every stage and preserves the primary exception":
    let cleanupBackend = scripted([endOfInput()])
    cleanupBackend.failures = @[
      "reset", "enable-wrap", "show-cursor", "leave-screen", "close"]
    let cleanupTree = newWidgetTree(newCheckbox(newWidgetId("cleanup"),
      "Cleanup"))
    expect TerminalStateError:
      discard runWidgetsWithBackend(cleanupTree, cleanupBackend)
    for operation in ["reset", "enable-wrap", "show-cursor", "leave-screen",
        "close"]:
      check operation in cleanupBackend.operations

    let primaryBackend = scripted([keyInput(keyUnknown)])
    primaryBackend.failures = @["show-cursor"]
    let primaryTree = newWidgetTree(newCheckbox(newWidgetId("primary"),
      "Primary"))
    var message = ""
    try:
      discard runWidgetsWithBackend(primaryTree, primaryBackend,
        onEvents = proc(context: RuntimeEventContext): RunAction =
          raise newException(ValueError, "original failure"))
    except ValueError as error:
      message = error.msg
    check message.startsWith("original failure")
    check "cleanup failures" in message
    check "leave-screen" in primaryBackend.operations
    check primaryBackend.operations[^1] == "close"
