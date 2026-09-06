## Compile and run with: nim c -r --path:src examples/text_field.nim

import terminal_widgets

let control = newTextField(newWidgetId("name"), label = "Name",
  placeholder = "Ada Lovelace", maxRunes = 40)
let tree = newWidgetTree(control)
discard tree.layout(newSize(28, 1))
for character in ["A", "d", "a"]:
  discard tree.dispatch(keyInput(keyText, text = character))
echo tree.render(newSize(28, 1), plainWidgetTheme()).rows[0]
