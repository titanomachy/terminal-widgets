## Compile with the isolated package store prepared by `nimble packageTest`.
## This imports both the side-effect-free facade and the opt-in runtime module;
## constructing their public values must not touch a terminal.

import terminal_screen
import terminal_widgets
import terminal_widgets/runtime

let checkbox = newCheckbox(newWidgetId("consumer-check"), "Installed package")
let tree = newWidgetTree(checkbox)
discard tree.layout(newSize(24, 1))
let frame = tree.render(newSize(24, 1), plainWidgetTheme())
let options = defaultRuntimeOptions()

proc compileRuntimeEntrypoints(tree: WidgetTree; session: TerminalSession;
                               output: File; backend: RuntimeBackend) =
  # Type-check the old positional calls and the appended idle callback without
  # opening an actual terminal in this isolated-consumer check.
  let idle: RuntimeTimeoutHandler = proc(): RunAction = stopRunning
  discard runWidgets(tree, options, nil)
  discard runWidgets(tree, options, nil, idle)
  discard runWidgets(tree, onTimeout = idle)
  discard runWidgets(tree, session, output, options, nil)
  discard runWidgets(tree, session, output, options, nil, idle)
  discard runWidgets(tree, session, output, onTimeout = idle)
  discard runWidgetsWithBackend(tree, backend, options, nil, false, false)
  discard runWidgetsWithBackend(tree, backend, options, nil, false, false, idle)
  discard runWidgetsWithBackend(tree, backend, onTimeout = idle)

doAssert frame.rows == @["> [ ] Installed package "]
doAssert options.pollTimeoutMs > 0
echo "isolated-consumer:ok"
