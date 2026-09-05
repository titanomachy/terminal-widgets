## Headless text-field editing example.
## Run with: nim r --path:src examples/text_field_editing.nim

import std/options
import terminal_widgets

let validator: TextValidator = proc(value: string): Option[string] =
  if value.len == 0: some("A value is required") else: none(string)

let field = newTextField(newWidgetId("query"), label = "Query",
  placeholder = "Type a search", maxRunes = 32, validator = validator)
let tree = newWidgetTree(field)
discard tree.layout(newSize(32, 1))

proc send(input: InputEvent) =
  let outcome = tree.dispatch(input)
  for event in outcome.events:
    case event.kind
    of textChanged:
      echo "changed: ", event.text
    of submitted:
      echo "submitted: ", event.text
    of validationFailed:
      echo "invalid: ", event.validationMessage
    else:
      discard

send(keyInput(keyEnter))
send(keyInput(keyText, "café"))
send(keyInput(keyText, "界"))
send(keyInput(keyArrowLeft))
send(keyInput(keyBackspace))
send(keyInput(keyEnter))
echo "value=", field.value
echo "cursorByte=", field.cursorByte, " horizontalOffset=", field.horizontalOffset
echo "window=", field.visibleText(field.contentWidth)
