## Build and run this headless control example with:
##
## .. code-block:: console
##   nim r --path:src examples/basic_controls.nim

import std/options
import terminal_widgets

let updates = newCheckbox(newWidgetId("updates"), "Install updates")
let network = newSwitch(newWidgetId("network"), "Network")
let mode = newRadioGroup(newWidgetId("mode"), [
  newChoiceItem(newItemId("normal"), "Normal"),
  newChoiceItem(newItemId("safe"), "Safe mode")
])
let root = newColumn(newWidgetId("controls"),
  [Widget(updates), Widget(network), Widget(mode)])
let tree = newWidgetTree(root)
discard tree.layout(newSize(32, 6))

discard tree.dispatch(keyInput(keySpace))
discard tree.requestFocus(network.id)
discard tree.dispatch(keyInput(keyEnter))
discard tree.requestFocus(mode.id)
discard tree.dispatch(keyInput(keyArrowDown))
let selection = tree.dispatch(keyInput(keySpace))

echo updates.marker, " ", updates.label
echo network.marker, " ", network.label
echo "selected: ", mode.selected.get
echo "events: ", selection.events.len
