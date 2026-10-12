## Compile with: nim c --path:src examples/idle_updates.nim
## Run from an interactive ANSI terminal. Updates on input timeouts only:
## continuous typing may delay updates. Escape exits; Ctrl+C cancels.
## Four updates are displayed; the following timeout stops without a redraw.

import terminal_widgets
import terminal_widgets/runtime

let status = newStaticText(newWidgetId("status"), "Updates: 0")
let hint = newStaticText(newWidgetId("hint"),
  "Idle updates only • Escape exits • Ctrl+C cancels")
let tree = newWidgetTree(newColumn(newWidgetId("idle-updates"),
  [Widget(status), Widget(hint)]))
var updates = 0
var options = defaultRuntimeOptions()
options.pollTimeoutMs = 250

discard runWidgets(tree, options = options,
  onEvents = proc(context: RuntimeEventContext): RunAction =
    if context.input.kind == eventKey and context.input.keyEvent.key == keyEscape:
      return stopRunning
    continueRunning,
  onTimeout = proc(): RunAction =
    if updates == 4:
      return stopRunning
    inc updates
    status.setContent("Updates: " & $updates)
    continueRunning)
