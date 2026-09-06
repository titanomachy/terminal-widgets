## Compile with the isolated package store prepared by `nimble packageTest`.
## This imports both the side-effect-free facade and the opt-in runtime module;
## constructing their public values must not touch a terminal.

import terminal_widgets
import terminal_widgets/runtime

let checkbox = newCheckbox(newWidgetId("consumer-check"), "Installed package")
let tree = newWidgetTree(checkbox)
discard tree.layout(newSize(24, 1))
let frame = tree.render(newSize(24, 1), plainWidgetTheme())
let options = defaultRuntimeOptions()

doAssert frame.rows == @["> [ ] Installed package "]
doAssert options.pollTimeoutMs > 0
echo "isolated-consumer:ok"
