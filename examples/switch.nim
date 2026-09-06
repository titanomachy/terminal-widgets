## Compile and run with: nim c -r --path:src examples/switch.nim

import terminal_widgets

let control = newSwitch(newWidgetId("compact"), "Compact mode")
let tree = newWidgetTree(control)
discard tree.layout(newSize(24, 1))
discard tree.dispatch(keyInput(keyEnter))
echo tree.render(newSize(24, 1), plainWidgetTheme()).rows[0]
