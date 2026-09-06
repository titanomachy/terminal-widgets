## Compile and run with: nim c -r --path:src examples/scroll_list.nim

import terminal_widgets

let control = newScrollList(newWidgetId("releases"), [
  newChoiceItem(newItemId("stable"), "Stable"),
  newChoiceItem(newItemId("preview"), "Preview", enabled = false),
  newChoiceItem(newItemId("nightly"), "Nightly")])
let tree = newWidgetTree(control)
discard tree.layout(newSize(20, 2))
discard tree.dispatch(keyInput(keyArrowDown))
for row in tree.render(newSize(20, 2), plainWidgetTheme()).rows:
  echo row
