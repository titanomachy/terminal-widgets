## Compile and run with: nim c -r --path:src examples/radio_group.nim

import terminal_widgets

let control = newRadioGroup(newWidgetId("density"), [
  newChoiceItem(newItemId("comfortable"), "Comfortable"),
  newChoiceItem(newItemId("balanced"), "Balanced"),
  newChoiceItem(newItemId("compact"), "Compact")])
let tree = newWidgetTree(control)
discard tree.layout(newSize(24, 2))
discard tree.dispatch(keyInput(keyEnd))
discard tree.dispatch(keyInput(keySpace))
for row in tree.render(newSize(24, 2), plainWidgetTheme()).rows:
  echo row
echo "top index: ", control.topIndex
