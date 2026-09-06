## Real-terminal child used by the Linux PTY restoration smoke test.

import terminal_widgets
import terminal_widgets/runtime

let control = newCheckbox(newWidgetId("pty-smoke"), "PTY smoke")
let tree = newWidgetTree(control)
let result = runWidgets(tree,
  onEvents = proc(context: RuntimeEventContext): RunAction = stopRunning)
echo "runtime-smoke:", $result.termination
