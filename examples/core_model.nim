## Build and run this side-effect-free model example with:
##
## .. code-block:: console
##   nim r --path:src examples/core_model.nim

import std/options
import terminal_widgets

let delivery = newCheckbox(newWidgetId("delivery"), "Send status updates")
delivery.setHelpText("You can change this preference later.")
delivery.setChecked(true)

let density = newRadioGroup(
  newWidgetId("density"),
  [
    newChoiceItem(newItemId("comfortable"), "Comfortable"),
    newChoiceItem(newItemId("compact"), "Compact")
  ],
  selected = some(newItemId("comfortable"))
)

let form = newColumn(newWidgetId("preferences"),
  [Widget(delivery), Widget(density)])
let tree = newWidgetTree(form)

echo tree.root.id, ": ", form.children.len, " retained widgets"
echo delivery.label, " = ", delivery.checked
echo "density = ", density.selected.get
