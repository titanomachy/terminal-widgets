## Compile with: nim c --path:src examples/form.nim
## Run from an interactive ANSI terminal. Enter submits and exits; Escape also
## exits; Ctrl+C cancels. `runWidgets` restores its acquired terminal state.

import terminal_widgets
import terminal_widgets/runtime

let name = newTextField(newWidgetId("name"), label = "Name",
  placeholder = "Ada Lovelace")
let updates = newCheckbox(newWidgetId("updates"), "Install updates")
let root = newColumn(newWidgetId("form"), [Widget(name), Widget(updates)])
root.setSizing(name.id, fixed(1))
let tree = newWidgetTree(root)

discard runWidgets(tree,
  onEvents = proc(context: RuntimeEventContext): RunAction =
    if context.input.kind == eventKey and context.input.keyEvent.key == keyEscape:
      return stopRunning
    for event in context.outcome.events:
      if event.kind == submitted:
        return stopRunning
    continueRunning)
