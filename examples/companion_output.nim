## Compose static string output from a companion-style producer without adding
## that producer as a TerminalWidgets dependency.
## Run with: nim r --path:src examples/companion_output.nim

import terminal_widgets

# In an application this string can come from TerminalGraph, TerminalTable,
# TerminalStatus, or another library owned and imported by that application.
proc renderCompanionGraph(): string =
  "Requests  ▁▂▄▆█\nLatency   █▅▃▂▁"

let content = newStaticText(newWidgetId("metrics"), renderCompanionGraph())
let tree = newWidgetTree(content)
let size = newSize(24, 2)
discard tree.layout(size)

for row in tree.render(size, plainWidgetTheme()).rows:
  echo row
