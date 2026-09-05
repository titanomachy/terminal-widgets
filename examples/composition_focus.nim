## Build and run this headless composition example with:
##
## .. code-block:: console
##   nim r --path:src examples/composition_focus.nim

import terminal_widgets

let navigation = newMenu(newWidgetId("navigation"), [
  newChoiceItem(newItemId("home"), "Home"),
  newChoiceItem(newItemId("settings"), "Settings")
])
let content = newTextField(newWidgetId("search"), "Search")
let root = newRow(newWidgetId("workspace"),
  [Widget(navigation), Widget(content)])
root.setGap(1)
root.setPadding(newPadding(1))
root.setSizing(navigation.id, fixed(18))
root.setSizing(content.id, flex(1))

let tree = newWidgetTree(root)
discard tree.layout(newSize(60, 5))
echo "focus: ", tree.focused
echo "navigation: ", navigation.allocation
echo "content: ", content.allocation

discard tree.dispatch(keyInput(keyTab))
echo "focus after Tab: ", tree.focused
