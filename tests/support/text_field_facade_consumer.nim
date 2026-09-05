## Facade-only compile fixture for the validated form API.

import std/options
import terminal_widgets

let required: TextValidator = proc(value: string): Option[string] =
  if value.len == 0: some("required") else: none(string)

let name = newTextField(newWidgetId("name"), label = "Name",
  placeholder = "Ada", maxRunes = 40, validator = required)
let email = newTextField(newWidgetId("email"), label = "Email",
  readOnly = false)
let form = newColumn(newWidgetId("form"), [Widget(name), Widget(email)])
let tree = newWidgetTree(form)
discard tree.layout(newSize(40, 2))

doAssert tree.dispatch(keyInput(keyEnter)).events[0].kind == validationFailed
discard tree.dispatch(keyInput(keyText, "Ada"))
doAssert tree.dispatch(keyInput(keyEnter)).events[0].kind == submitted
doAssert name.value == "Ada"
