import std/[options, sequtils, strutils, unittest]
import terminal_style
import terminal_widgets
import terminal_widgets/runtime
import terminal_widgets/widget

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

type InputProbe = ref object of Checkbox
  inputs: seq[InputEventKind]

method handleInput(control: InputProbe; input: InputEvent): DispatchResult =
  control.inputs.add input.kind
  dispatchResult()

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

  test "tabs deliver documented unhandled activation keys to applications":
    let backend = scripted([keyInput(keySpace)])
    let tabs = newTabs(newWidgetId("runtime-tabs"), [
      newTabPage(newItemId("runtime-page"), "Page",
        newCheckbox(newWidgetId("runtime-page-child"), "Child"))])
    let tree = newWidgetTree(tabs)
    var delivered = false
    let result = runWidgetsWithBackend(tree, backend,
      onEvents = proc(context: RuntimeEventContext): RunAction =
        delivered = true
        check context.input.keyEvent.key == keySpace
        check not context.outcome.handled
        stopRunning)
    check delivered
    check result.termination == requestedStop

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

  test "timeout callbacks run once per timeout without dispatch or event delivery":
    for withCallback in [false, true]:
      let backend = scripted([timeoutInput(), timeoutInput(),
        keyInput(keyUnknown), timeoutInput(), endOfInput()])
      let control = InputProbe()
      control.initializeWidgetState(newWidgetId("idle-probe"), "Probe")
      let tree = newWidgetTree(control)
      var timeouts = 0
      var callbacks = 0
      let idle: RuntimeTimeoutHandler = if withCallback:
        proc(): RunAction =
          inc timeouts
          continueRunning
        else: nil
      let result = runWidgetsWithBackend(tree, backend,
        onEvents = proc(context: RuntimeEventContext): RunAction =
          inc callbacks
          check context.input.kind == eventKey
          continueRunning,
        onTimeout = idle)
      check result.termination == endOfInput
      check result.framesPresented == 1
      check backend.frames.len == 1
      check timeouts == (if withCallback: 3 else: 0)
      check callbacks == 1
      check control.inputs == @[eventKey]

  test "timeout content changes redraw once and unchanged setters stay idle":
    let backend = scripted([timeoutInput(), timeoutInput(), endOfInput()])
    let status = newStaticText(newWidgetId("idle-status"), "Updates: 0")
    let tree = newWidgetTree(status)
    var callbacks = 0
    var options = defaultRuntimeOptions()
    options.pollTimeoutMs = 250
    let result = runWidgetsWithBackend(tree, backend, options,
      onTimeout = proc(): RunAction =
        inc callbacks
        status.setContent("Updates: 1")
        continueRunning)
    check result.termination == endOfInput
    check callbacks == 2
    check result.framesPresented == 2
    check stripAnsi(backend.frames[^1].rows[0]) == "Updates: 1".alignLeft(20)
    check backend.operations.count("read:250") == 3

  test "timeout changes to multiple widgets produce one frame":
    let backend = scripted([timeoutInput(), endOfInput()])
    let status = newStaticText(newWidgetId("idle-multi-status"), "Waiting")
    let control = newCheckbox(newWidgetId("idle-multi-control"), "Ready")
    let tree = newWidgetTree(newColumn(newWidgetId("idle-multi-root"),
      [Widget(status), Widget(control)]))
    let result = runWidgetsWithBackend(tree, backend,
      onTimeout = proc(): RunAction =
        status.setContent("Finished")
        control.setChecked(true)
        continueRunning)
    check result.framesPresented == 2
    check stripAnsi(backend.frames[^1].rows[0]) == "Finished".alignLeft(20)
    check stripAnsi(backend.frames[^1].rows[1]) == "> [x] Ready".alignLeft(20)

  test "timeout focus changes redraw markers and cursor without revisions":
    let backend = scripted([timeoutInput(), timeoutInput(), endOfInput()])
    let first = newTextField(newWidgetId("idle-focus-first"), label = "First")
    let second = newTextField(newWidgetId("idle-focus-second"), label = "Second")
    let tree = newWidgetTree(newColumn(newWidgetId("idle-focus-root"),
      [Widget(first), Widget(second)]))
    let revisions = (first.revision, second.revision)
    var callbacks = 0
    let result = runWidgetsWithBackend(tree, backend,
      onTimeout = proc(): RunAction =
        inc callbacks
        discard tree.requestFocus(second.id)
        continueRunning)
    check callbacks == 2
    check result.framesPresented == 2
    check (first.revision, second.revision) == revisions
    check tree.focused == some(second.id)
    check stripAnsi(backend.frames[^1].rows[0]).startsWith("  First: ")
    check stripAnsi(backend.frames[^1].rows[1]).startsWith("> Second: ")
    check backend.frames[^1].cursor == some(CursorCell(column: 10, row: 1))

  test "timeout visibility and enablement changes deliver focus repair events":
    for hide in [false, true]:
      let backend = scripted([timeoutInput(), endOfInput()])
      let first = newCheckbox(newWidgetId("idle-repair-first"), "First")
      let second = newCheckbox(newWidgetId("idle-repair-second"), "Second")
      let tree = newWidgetTree(newColumn(newWidgetId("idle-repair-root"),
        [Widget(first), Widget(second)]))
      var callbacks = 0
      var repaired: seq[WidgetEvent]
      let result = runWidgetsWithBackend(tree, backend,
        onEvents = proc(context: RuntimeEventContext): RunAction =
          inc callbacks
          check context.input.kind == eventTimeout
          repaired = context.outcome.events
          # Repair callbacks may also update the frame before presentation.
          second.setChecked(true)
          continueRunning,
        onTimeout = proc(): RunAction =
          if hide: first.setVisible(false)
          else: first.setEnabled(false)
          continueRunning)
      check result.termination == endOfInput
      check result.framesPresented == 2
      check callbacks == 1
      check tree.focused == some(second.id)
      require repaired.len == 1
      check repaired[0].kind == focusChanged
      check repaired[0].previousFocus == some(first.id)
      check repaired[0].newFocus == some(second.id)
      if hide:
        check first.allocation.isNone
        check stripAnsi(backend.frames[^1].rows[0]) == "> [x] Second".alignLeft(20)
      else:
        check stripAnsi(backend.frames[^1].rows[1]) == "> [x] Second".alignLeft(20)

  test "timeout changes repair focus even without an event handler":
    let backend = scripted([timeoutInput(), endOfInput()])
    let first = newCheckbox(newWidgetId("idle-unobserved-first"), "First")
    let second = newCheckbox(newWidgetId("idle-unobserved-second"), "Second")
    let tree = newWidgetTree(newColumn(newWidgetId("idle-unobserved-root"),
      [Widget(first), Widget(second)]))
    let result = runWidgetsWithBackend(tree, backend,
      onTimeout = proc(): RunAction =
        first.setVisible(false)
        continueRunning)
    check result.framesPresented == 2
    check tree.focused == some(second.id)
    check stripAnsi(backend.frames[^1].rows[0]) == "> [ ] Second".alignLeft(20)

  test "timeout stop skips redraw and further reads with owned and borrowed modes":
    for owned in [false, true]:
      for presentation in [false, true]:
        let backend = scripted([timeoutInput(), keyInput(keySpace)])
        let control = newCheckbox(newWidgetId("idle-stop"), "Stop")
        let tree = newWidgetTree(control)
        # Positional ownership arguments retain their original meaning.
        let result = runWidgetsWithBackend(tree, backend,
          defaultRuntimeOptions(), nil, owned, presentation,
          proc(): RunAction =
            control.setChecked(true)
            stopRunning)
        check result.termination == requestedStop
        check result.framesPresented == 1
        check backend.nextEvent == 1
        check backend.operations.count("read:50") == 1
        check control.checked
        check backend.operations.count("open") == int(owned)
        check backend.operations.count("close") == int(owned)
        check backend.operations.count("enter-screen") == int(presentation)
        check backend.operations.count("leave-screen") == int(presentation)
        check backend.operations.count("hide-cursor") == int(presentation)
        check backend.operations.count("show-cursor") == int(presentation)
        check backend.operations.count("disable-wrap") == int(presentation)
        check backend.operations.count("enable-wrap") == int(presentation)
        check backend.operations.count("reset") == 1

  test "timeout focus repair can request stop before redraw":
    let backend = scripted([timeoutInput(), keyInput(keySpace)])
    let control = newCheckbox(newWidgetId("idle-repair-stop"), "Stop")
    let tree = newWidgetTree(control)
    let result = runWidgetsWithBackend(tree, backend,
      onEvents = proc(context: RuntimeEventContext): RunAction =
        check context.input.kind == eventTimeout
        check context.outcome.events[0].kind == focusChanged
        stopRunning,
      onTimeout = proc(): RunAction =
        control.setVisible(false)
        continueRunning)
    check result.termination == requestedStop
    check result.framesPresented == 1
    check backend.nextEvent == 1
    check backend.operations[^1] == "close"

  test "timeouts are not synthesized for keys resize cancellation or EOF":
    for ending in [endOfInput(), keyInput(keyCtrlC)]:
      let backend = scripted([keyInput(keySpace),
        resizeInput(terminalSize(12, 1)), ending, timeoutInput()])
      let control = newCheckbox(newWidgetId("idle-busy"), "Busy")
      let tree = newWidgetTree(control)
      var timeouts = 0
      var events = 0
      let result = runWidgetsWithBackend(tree, backend,
        onEvents = proc(context: RuntimeEventContext): RunAction =
          inc events
          check context.input.kind in {eventKey, eventResize}
          continueRunning,
        onTimeout = proc(): RunAction =
          inc timeouts
          continueRunning)
      check result.termination == (if ending.kind == eventEndOfInput:
        RunTermination.endOfInput else: cancelled)
      check result.framesPresented == 3
      check backend.nextEvent == 3
      check control.checked
      check timeouts == 0
      check events == 2

  test "timeout exceptions preserve the primary error and attempt all cleanup":
    for owned in [false, true]:
      for presentation in [false, true]:
        let backend = scripted([timeoutInput(), keyInput(keySpace)])
        backend.failures = @[
          "reset", "enable-wrap", "show-cursor", "leave-screen", "close"]
        let tree = newWidgetTree(newCheckbox(newWidgetId("idle-error"), "Error"))
        var message = ""
        try:
          discard runWidgetsWithBackend(tree, backend,
            ownedSession = owned, ownPresentation = presentation,
            onTimeout = proc(): RunAction =
              raise newException(ValueError, "idle callback failed"))
        except ValueError as error:
          message = error.msg
        check message.startsWith("idle callback failed; cleanup failures: ")
        check "reset styles: injected reset" in message
        check backend.nextEvent == 1
        check backend.frames.len == 1
        var expected = @["reset"]
        if presentation:
          expected.add @["enable-wrap", "show-cursor", "leave-screen"]
          check "restore cursor: injected show-cursor" in message
        if owned: expected.add "close"
        check backend.operations[^expected.len .. ^1] == expected

  test "timeout assertion defects also restore every acquired stage":
    let backend = scripted([timeoutInput()])
    let tree = newWidgetTree(newCheckbox(newWidgetId("idle-defect"), "Defect"))
    expect AssertionDefect:
      discard runWidgetsWithBackend(tree, backend,
        onTimeout = proc(): RunAction =
          doAssert false, "idle invariant failed"
          continueRunning)
    check backend.operations[^5 .. ^1] == @[
      "reset", "enable-wrap", "show-cursor", "leave-screen", "close"]

  test "resize callbacks can hide focused controls and deliver focus repair":
    let backend = scripted([resizeInput(terminalSize(12, 2)), endOfInput()])
    let first = newCheckbox(newWidgetId("resize-first"), "First")
    let second = newCheckbox(newWidgetId("resize-second"), "Second")
    let tree = newWidgetTree(newColumn(newWidgetId("resize-root"),
      [Widget(first), Widget(second)]))
    var callbacks = 0
    var repaired: seq[WidgetEvent]
    let result = runWidgetsWithBackend(tree, backend,
      onEvents = proc(context: RuntimeEventContext): RunAction =
        inc callbacks
        check context.input.kind == eventResize
        if callbacks == 1:
          first.setVisible(false)
        else:
          repaired = context.outcome.events
        continueRunning)
    check result.termination == endOfInput
    check result.framesPresented == 2
    check callbacks == 2
    check first.allocation.isNone
    check second.allocation == some(newRect(0, 0, 12, 2))
    check tree.focused == some(second.id)
    require repaired.len == 1
    check repaired[0].kind == focusChanged
    check repaired[0].previousFocus == some(first.id)
    check repaired[0].newFocus == some(second.id)
    check stripAnsi(backend.frames[^1].rows[0]) == "> [ ] Second"

  test "resize callbacks can switch retained tab pages before presentation":
    let backend = scripted([resizeInput(terminalSize(16, 2)), endOfInput()])
    let first = newTextField(newWidgetId("resize-page-first"), value = "First")
    let second = newTextField(newWidgetId("resize-page-second"), value = "Second")
    let secondPage = newItemId("resize-page-two")
    let tabs = newTabs(newWidgetId("resize-tabs"), [
      newTabPage(newItemId("resize-page-one"), "One", first),
      newTabPage(secondPage, "Two", second)])
    let tree = newWidgetTree(tabs)
    let result = runWidgetsWithBackend(tree, backend,
      onEvents = proc(context: RuntimeEventContext): RunAction =
        tabs.setActive(some(secondPage))
        continueRunning)
    check result.termination == endOfInput
    check result.framesPresented == 2
    check first.allocation.isNone
    check second.allocation == some(newRect(0, 1, 16, 1))
    check first.value == "First"
    check second.value == "Second"
    check stripAnsi(backend.frames[^1].rows[1]).contains("Second")

  test "submission callbacks redraw focus and cursor before the next input":
    let backend = scripted([
      keyInput(keyEnter), timeoutInput(), keyInput(keyText, text = "x"),
      endOfInput()])
    let first = newTextField(newWidgetId("submit-first"), label = "First")
    let second = newTextField(newWidgetId("submit-second"), label = "Second")
    let tree = newWidgetTree(newColumn(newWidgetId("submit-root"),
      [Widget(first), Widget(second)]))
    var callbacks = 0
    let result = runWidgetsWithBackend(tree, backend,
      onEvents = proc(context: RuntimeEventContext): RunAction =
        inc callbacks
        for event in context.outcome.events:
          if event.kind == submitted:
            discard tree.requestFocus(second.id)
        continueRunning)
    check result.termination == endOfInput
    check result.framesPresented == 3
    check callbacks == 2
    check tree.focused == some(second.id)
    check first.value == ""
    check second.value == "x"
    require backend.frames.len == 3
    check stripAnsi(backend.frames[1].rows[0]).startsWith("  First: ")
    check stripAnsi(backend.frames[1].rows[1]).startsWith("> Second: ")
    check backend.frames[1].cursor == some(CursorCell(column: 10, row: 1))
    check backend.frames[2].cursor == some(CursorCell(column: 11, row: 1))

  test "requesting the current focus in a callback does not redraw":
    let backend = scripted([keyInput(keyEnter), endOfInput()])
    let field = newTextField(newWidgetId("same-focus"), label = "Name")
    let tree = newWidgetTree(field)
    let result = runWidgetsWithBackend(tree, backend,
      onEvents = proc(context: RuntimeEventContext): RunAction =
        discard tree.requestFocus(field.id)
        continueRunning)
    check result.termination == endOfInput
    check result.framesPresented == 1

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

  test "callback assertion failures restore every acquired terminal stage":
    let backend = scripted([keyInput(keyUnknown)])
    let tree = newWidgetTree(newCheckbox(newWidgetId("callback-defect"),
      "Callback"))
    expect AssertionDefect:
      discard runWidgetsWithBackend(tree, backend,
        onEvents = proc(context: RuntimeEventContext): RunAction =
          doAssert false, "application invariant failed"
          continueRunning)
    check backend.operations[^5 .. ^1] == @[
      "reset", "enable-wrap", "show-cursor", "leave-screen", "close"]

  test "validator defects remain primary when terminal restoration fails":
    let backend = scripted([keyInput(keyEnter)])
    backend.failures = @["show-cursor"]
    let field = newTextField(newWidgetId("validator-defect"), value = "x",
      validator = proc(value: string): Option[string] =
        # Bounds-defect unwinding must return an initialized managed value so
        # caller cleanup is safe on ARM64 as well as x86-64.
        result = none(string)
        let values = @["only entry"]
        discard values[value.len])
    let tree = newWidgetTree(field)
    var message = ""
    try:
      discard runWidgetsWithBackend(tree, backend)
    except IndexDefect as error:
      message = error.msg
    check "index" in message
    check "cleanup failures" in message
    check "restore cursor: injected show-cursor" in message
    check backend.operations[^5 .. ^1] == @[
      "reset", "enable-wrap", "show-cursor", "leave-screen", "close"]

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
