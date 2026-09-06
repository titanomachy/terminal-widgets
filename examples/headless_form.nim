## Compile and run with: nim c -r --path:src examples/headless_form.nim
## This finite mixed-form session needs no TTY and is safe to run in CI.

import std/options
import terminal_widgets

let enabled = newCheckbox(newWidgetId("enabled"), "Enabled")
let name = newTextField(newWidgetId("name"), label = "Name")
let mode = newScrollList(newWidgetId("mode"), [
  newChoiceItem(newItemId("safe"), "Safe"),
  newChoiceItem(newItemId("fast"), "Fast")])
let root = newColumn(newWidgetId("form"),
  [Widget(enabled), Widget(name), Widget(mode)])
root.setSizing(enabled.id, fixed(1))
root.setSizing(name.id, fixed(1))
let tree = newWidgetTree(root)

discard tree.layout(newSize(28, 4))
discard tree.requestFocus(enabled.id)
discard tree.dispatch(keyInput(keySpace))
discard tree.dispatch(keyInput(keyTab))
for character in ["A", "d", "a"]:
  discard tree.dispatch(keyInput(keyText, text = character))
discard tree.dispatch(keyInput(keyTab))
discard tree.dispatch(keyInput(keyArrowDown))

let frame = tree.render(newSize(28, 4), plainWidgetTheme())
doAssert enabled.checked
doAssert name.value == "Ada"
doAssert mode.selected == some(newItemId("fast"))
for row in frame.rows:
  echo row
