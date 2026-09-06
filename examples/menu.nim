## Compile and run with: nim c -r --path:src examples/menu.nim

import terminal_widgets

let control = newMenu(newWidgetId("actions"), [
  newChoiceItem(newItemId("open"), "Open"),
  newChoiceItem(newItemId("save"), "Save")])
let tree = newWidgetTree(control)
discard tree.layout(newSize(20, 2))
discard tree.dispatch(keyInput(keyArrowDown))
let outcome = tree.dispatch(keyInput(keyEnter))
doAssert outcome.events.len == 1 and outcome.events[0].kind == activated
echo outcome.events[0].item
