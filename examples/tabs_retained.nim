## Build and run this headless tabs example with:
##
## .. code-block:: console
##   nim r --path:src examples/tabs_retained.nim

import terminal_widgets

let profile = newTextField(newWidgetId("profile"), value = "Ada")
let activity = newScrollList(newWidgetId("activity"), [
  newChoiceItem(newItemId("first"), "First"),
  newChoiceItem(newItemId("second"), "Second")])
let tabs = newTabs(newWidgetId("tabs"), [
  newTabPage(newItemId("profile-page"), "Profile", profile),
  newTabPage(newItemId("activity-page"), "Activity", activity)])
let tree = newWidgetTree(tabs)
discard tree.layout(newSize(24, 4))

profile.setValue("Grace")
discard tree.dispatch(keyInput(keyArrowRight))
discard tree.dispatch(keyInput(keyTab))
discard tree.dispatch(keyInput(keyEnd))
discard tree.requestFocus(tabs.id)
discard tree.dispatch(keyInput(keyArrowLeft))

echo "active tab: ", tabs.active
echo "retained profile: ", profile.value
echo "retained activity: ", activity.selected
