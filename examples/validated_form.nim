## Headless validated-form example using only the public facade.
## Run with: nim r --path:src examples/validated_form.nim

import std/options
import terminal_widgets

let required: TextValidator = proc(value: string): Option[string] =
  if value.len == 0: some("This field is required") else: none(string)

let name = newTextField(newWidgetId("name"), label = "Name",
  placeholder = "Your name", maxRunes = 80, validator = required)
let email = newTextField(newWidgetId("email"), label = "Email",
  placeholder = "name@example.com", maxRunes = 254, validator = required)
let form = newColumn(newWidgetId("profile-form"),
  [Widget(name), Widget(email)])
let tree = newWidgetTree(form)
discard tree.layout(newSize(48, 2))

proc report(outcome: DispatchResult) =
  for event in outcome.events:
    case event.kind
    of validationFailed:
      echo $event.source, " invalid: ", event.validationMessage
    of submitted:
      echo $event.source, " submitted: ", event.text
    else:
      discard

report(tree.dispatch(keyInput(keyEnter)))
discard tree.dispatch(keyInput(keyText, "Ada Lovelace"))
report(tree.dispatch(keyInput(keyEnter)))
discard tree.dispatch(keyInput(keyTab))
discard tree.dispatch(keyInput(keyText, "ada@example.com"))
report(tree.dispatch(keyInput(keyEnter)))
