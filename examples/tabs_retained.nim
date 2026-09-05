## Build and run this headless tabs example with:
##
## .. code-block:: console
##   nim r --path:src examples/tabs_retained.nim

import terminal_widgets

let profile = newTextField(newWidgetId("profile"), value = "Ada")
let activity = newScrollList(newWidgetId("activity"), [
  newChoiceItem(newItemId("first"), "First"),
  newChoiceItem(newItemId("second"), "Second")])
let settings = newCheckbox(newWidgetId("settings"), "Compact layout")
let tabs = newTabs(newWidgetId("tabs"), [
  newTabPage(newItemId("profile-page"), "Profile", profile),
  newTabPage(newItemId("activity-page"), "Activity", activity),
  newTabPage(newItemId("settings-page"), "Settings", settings)])
let tree = newWidgetTree(tabs)
discard tree.layout(newSize(24, 4))

profile.setValue("Grace")
discard tree.dispatch(keyInput(keyArrowRight))
discard tree.dispatch(keyInput(keyTab))
discard tree.dispatch(keyInput(keyEnd))
discard tree.requestFocus(tabs.id)
discard tree.dispatch(keyInput(keyArrowLeft))

for line in renderControl(tabs, plainWidgetTheme(), focused = true):
  echo line
echo "active tab: ", tabs.active
echo "retained profile: ", profile.value
echo "retained activity: ", activity.selected

# Remove the active middle page and reorder the retained pages. The tree owns
# this mutation so focus, allocation, and descendant ownership stay coherent.
discard tree.dispatch(keyInput(keyArrowRight))
discard tree.dispatch(keyInput(keyTab))
discard tree.replacePages(tabs.id, [
  newTabPage(newItemId("profile-page"), "Profile", profile),
  newTabPage(newItemId("settings-page"), "Settings", settings)])
echo "replacement active tab: ", tabs.active
echo "focus after replacement: ", tree.focused
