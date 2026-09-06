## Compile and run with: nim c -r --path:src examples/checkbox.nim

import terminal_widgets

let control = newCheckbox(newWidgetId("updates"), "Install updates")
let tree = newWidgetTree(control)
discard tree.layout(newSize(24, 1))
discard tree.dispatch(keyInput(keySpace))
echo tree.render(newSize(24, 1), plainWidgetTheme()).rows[0]
