## Compile and run with: nim c -r --path:src examples/tabs.nim

import terminal_widgets

let profile = newTextField(newWidgetId("profile"), value = "Ada")
let settings = newCheckbox(newWidgetId("settings"), "Enable feature")
let control = newTabs(newWidgetId("pages"), [
  newTabPage(newItemId("profile-page"), "Profile", profile),
  newTabPage(newItemId("settings-page"), "Settings", settings)])
let tree = newWidgetTree(control)
discard tree.layout(newSize(28, 3))
discard tree.dispatch(keyInput(keyArrowRight))
for row in tree.render(newSize(28, 3), plainWidgetTheme()).rows:
  echo row
