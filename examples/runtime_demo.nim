## Deterministic finite runtime animation used by the README recording.
## Compile with: nim c --path:src examples/runtime_demo.nim

import std/[options, os]
import terminal_screen
import terminal_style
import terminal_widgets
import terminal_widgets/runtime

type DemoBackend = ref object of RuntimeBackend
  events: seq[InputEvent]
  index: int

method capabilities(backend: DemoBackend): TerminalCapabilities =
  TerminalCapabilities(inputIsTerminal: true, outputIsTerminal: true,
    supportsAnsi: true, supportsRawMode: true, supportsResizeEvents: true)
method initialSize(backend: DemoBackend): Option[TerminalSize] =
  some(terminalSize(48, 6))
method enterAlternateScreen(backend: DemoBackend) = stdout.write EnterAlternateScreen
method hideCursor(backend: DemoBackend) = stdout.write HideCursorCode
method disableAutoWrap(backend: DemoBackend) = stdout.write DisableAutoWrap
method present(backend: DemoBackend; frame: Frame; ownsCursor: bool) =
  for row, line in frame.rows:
    stdout.write cursorPositionCode(1, row + 1), line
  if frame.cursor.isSome:
    stdout.write cursorPositionCode(frame.cursor.get.column + 1,
      frame.cursor.get.row + 1), ShowCursorCode
  stdout.flushFile()
method readInput(backend: DemoBackend; timeoutMs: int): InputEvent =
  sleep(350)
  result = backend.events[backend.index]
  inc backend.index
method resetStyles(backend: DemoBackend) = stdout.write ansiReset
method enableAutoWrap(backend: DemoBackend) = stdout.write EnableAutoWrap
method showCursor(backend: DemoBackend) = stdout.write ShowCursorCode
method leaveAlternateScreen(backend: DemoBackend) =
  sleep(800)
  stdout.write LeaveAlternateScreen
  stdout.flushFile()

let required: TextValidator = proc(value: string): Option[string] =
  if value.len == 0: some("Type a name") else: none(string)
let name = newTextField(newWidgetId("demo-name"), label = "Name",
  placeholder = "Ada Lovelace", validator = required)
let subscribed = newCheckbox(newWidgetId("demo-news"), "Product updates")
let hint = newStaticText(newWidgetId("demo-hint"),
  "Type a name, then submit with Enter")
let root = newColumn(newWidgetId("demo"),
  [Widget(name), Widget(subscribed), Widget(hint)])
root.setSizing(name.id, fixed(2))
root.setSizing(subscribed.id, fixed(1))
let tree = newWidgetTree(root)
let backend = DemoBackend(events: @[
  keyInput(keyEnter),
  keyInput(keyText, "A"),
  keyInput(keyText, "d"),
  keyInput(keyText, "a"),
  keyInput(keyEnter)])

discard runWidgetsWithBackend(tree, backend,
  onEvents = proc(context: RuntimeEventContext): RunAction =
    for event in context.outcome.events:
      if event.kind == submitted: return stopRunning
    continueRunning,
  ownedSession = false,
  ownPresentation = true)
