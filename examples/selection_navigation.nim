## Build and run this headless selection example with:
##
## .. code-block:: console
##   nim r --path:src examples/selection_navigation.nim

import terminal_widgets

let items = @[
  newChoiceItem(newItemId("first"), "First"),
  newChoiceItem(newItemId("disabled"), "Unavailable", enabled = false),
  newChoiceItem(newItemId("last"), "Last")
]
let list = newScrollList(newWidgetId("results"), items)
let menu = newMenu(newWidgetId("actions"), items)
let root = newRow(newWidgetId("root"), [Widget(list), Widget(menu)])
let tree = newWidgetTree(root)
discard tree.layout(newSize(40, 2))

discard tree.dispatch(keyInput(keyArrowDown))
discard tree.requestFocus(menu.id)
discard tree.dispatch(keyInput(keyEnd))
let activation = tree.dispatch(keyInput(keyEnter))

echo "list selection: ", list.selected
echo "menu active: ", menu.active
echo "activation events: ", activation.events.len
