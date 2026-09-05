## Compile with: nim c --path:src examples/interactive_form.nim
## Run from an interactive ANSI terminal; Enter submits and exits, Ctrl+C
## cancels. Terminal state is restored on normal returns and exceptions.

import std/options
import terminal_widgets
import terminal_widgets/runtime

let required: TextValidator = proc(value: string): Option[string] =
  if value.len == 0: some("Type a name before submitting") else: none(string)

let name = newTextField(newWidgetId("name"), label = "Name",
  placeholder = "Ada Lovelace", maxRunes = 80, validator = required)
let hint = newStaticText(newWidgetId("hint"),
  "Enter submits • Ctrl+C cancels")
let root = newColumn(newWidgetId("interactive-form"),
  [Widget(name), Widget(hint)])
root.setSizing(name.id, fixed(1))
let tree = newWidgetTree(root)

discard runWidgets(tree,
  onEvents = proc(context: RuntimeEventContext): RunAction =
    for event in context.outcome.events:
      if event.kind == submitted:
        return stopRunning
    continueRunning)
