import std/[options, unittest]
import terminal_widgets

suite "tabs composition":
  test "headers navigate enabled pages and active children define focus order":
    let profile = newTextField(newWidgetId("profile"), value = "Ada")
    let disabled = newCheckbox(newWidgetId("disabled-child"), "Disabled")
    let logs = newScrollList(newWidgetId("logs"), [
      newChoiceItem(newItemId("one"), "One"),
      newChoiceItem(newItemId("two"), "Two")])
    let tabs = newTabs(newWidgetId("tabs"), [
      newTabPage(newItemId("profile-page"), "Profile", profile),
      newTabPage(newItemId("disabled-page"), "Disabled", disabled,
        enabled = false),
      newTabPage(newItemId("logs-page"), "Logs", logs)
    ])
    let tree = newWidgetTree(tabs)
    discard tree.layout(newSize(20, 4))
    check tree.focusOrder == @[tabs.id, profile.id]
    check profile.allocation == some(newRect(0, 1, 20, 3))
    check disabled.allocation.isNone

    let changed = tree.dispatch(keyInput(keyArrowRight))
    check changed.handled and changed.events.len == 1
    check changed.events[0].kind == selectionChanged
    check tabs.active == some(newItemId("logs-page"))
    check tree.focusOrder == @[tabs.id, logs.id]
    check profile.allocation.isNone
    check logs.allocation == some(newRect(0, 1, 20, 3))
    check tree.dispatch(keyInput(keyEnter)).handled
    check tree.dispatch(keyInput(keySpace)).handled

  test "page values and scroll offsets survive tab round trips":
    let field = newTextField(newWidgetId("field"), value = "kept")
    let list = newScrollList(newWidgetId("list"), [
      newChoiceItem(newItemId("zero"), "Zero"),
      newChoiceItem(newItemId("one"), "One"),
      newChoiceItem(newItemId("two"), "Two")])
    let tabs = newTabs(newWidgetId("tabs"), [
      newTabPage(newItemId("field-page"), "Field", field),
      newTabPage(newItemId("list-page"), "List", list)])
    let tree = newWidgetTree(tabs)
    discard tree.layout(newSize(12, 3))
    field.setValue("changed")
    discard tree.dispatch(keyInput(keyArrowRight))
    discard tree.dispatch(keyInput(keyTab))
    discard tree.dispatch(keyInput(keyEnd))
    check list.selected == some(newItemId("two"))
    check list.topIndex == 1
    discard tree.requestFocus(tabs.id)
    discard tree.dispatch(keyInput(keyArrowLeft))
    check field.value == "changed"
    discard tree.dispatch(keyInput(keyArrowRight))
    check list.selected == some(newItemId("two"))
    check list.topIndex == 1

  test "narrow headers scroll by display cells to keep active visible":
    let first = newCheckbox(newWidgetId("first"), "First")
    let second = newCheckbox(newWidgetId("second"), "Second")
    let tabs = newTabs(newWidgetId("tabs"), [
      newTabPage(newItemId("first-page"), "Long first", first),
      newTabPage(newItemId("second-page"), "Long second", second)])
    let tree = newWidgetTree(tabs)
    discard tree.layout(newSize(8, 2))
    check tabs.headerOffset == 0
    discard tree.dispatch(keyInput(keyArrowRight))
    check tabs.headerOffset > 0
