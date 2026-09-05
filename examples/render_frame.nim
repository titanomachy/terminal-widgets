## Build and run this pure full-frame example with:
##
## .. code-block:: console
##   nim r --path:src examples/render_frame.nim

import std/options
import terminal_widgets

let name = newTextField(newWidgetId("name"), label = "Name",
  value = "Ada")
let enabled = newCheckbox(newWidgetId("enabled"), "Enabled", checked = true)
let root = newColumn(newWidgetId("form"), [Widget(name), Widget(enabled)])
let tree = newWidgetTree(root)
let size = newSize(24, 2)
discard tree.layout(size)

let frame = tree.render(size, plainWidgetTheme())
for row in frame.rows:
  echo row
if frame.cursor.isSome:
  echo "cursor=", frame.cursor.get.column, ",", frame.cursor.get.row
