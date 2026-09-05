import std/[options, unittest]
import terminal_style
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
    let header = renderControl(tabs, plainWidgetTheme(), focused = true)
    check header.len == 1
    check displayWidth(header[0]) == 8

    let wide = newTabs(newWidgetId("wide-tabs"), [
      newTabPage(newItemId("wide-page"), "界",
        newCheckbox(newWidgetId("wide-child"), "Wide"))])
    let wideTree = newWidgetTree(wide)
    discard wideTree.layout(newSize(1, 1))
    check renderControl(wide, plainWidgetTheme()) == @["["]

  test "empty and all-disabled tabs have inert padded headers":
    let empty = newTabs(newWidgetId("empty"), newSeq[TabPage]())
    let emptyTree = newWidgetTree(empty)
    discard emptyTree.layout(newSize(6, 2))
    check empty.active.isNone
    check emptyTree.focusOrder.len == 0
    check renderControl(empty, plainWidgetTheme()) == @["      "]
    check not emptyTree.dispatch(keyInput(keyArrowRight)).handled

    let unavailable = newTabs(newWidgetId("unavailable"), [
      newTabPage(newItemId("one"), "One",
        newCheckbox(newWidgetId("one-child"), "One"), enabled = false),
      newTabPage(newItemId("two"), "Two",
        newCheckbox(newWidgetId("two-child"), "Two"), enabled = false)])
    let unavailableTree = newWidgetTree(unavailable)
    discard unavailableTree.layout(newSize(20, 2))
    check unavailable.active.isNone
    check unavailableTree.focusOrder.len == 0
    check renderControl(unavailable, plainWidgetTheme()) ==
      @["(One)|(Two)         "]

  test "detached replacement preserves keys and uses positional fallback":
    let first = newCheckbox(newWidgetId("first"), "First")
    let second = newCheckbox(newWidgetId("second"), "Second")
    let third = newCheckbox(newWidgetId("third"), "Third")
    let tabs = newTabs(newWidgetId("tabs"), [
      newTabPage(newItemId("first-page"), "First", first),
      newTabPage(newItemId("second-page"), "Second", second),
      newTabPage(newItemId("third-page"), "Third", third)])
    tabs.setActive(some(newItemId("second-page")))
    tabs.setPages([
      newTabPage(newItemId("third-page"), "Third renamed", third),
      newTabPage(newItemId("second-page"), "Second", second),
      newTabPage(newItemId("first-page"), "First", first)])
    check tabs.active == some(newItemId("second-page"))
    tabs.setPages([
      newTabPage(newItemId("first-page"), "First", first),
      newTabPage(newItemId("third-page"), "Third", third)])
    check tabs.active == some(newItemId("third-page"))

  test "tree replacement releases removed pages and repairs descendant focus":
    let first = newTextField(newWidgetId("first"), value = "retained")
    let second = newCheckbox(newWidgetId("second"), "Second")
    let third = newCheckbox(newWidgetId("third"), "Third")
    let tabs = newTabs(newWidgetId("tabs"), [
      newTabPage(newItemId("first-page"), "First", first),
      newTabPage(newItemId("second-page"), "Second", second),
      newTabPage(newItemId("third-page"), "Third", third)])
    let tree = newWidgetTree(tabs)
    discard tree.layout(newSize(16, 3))
    tabs.setActive(some(newItemId("second-page")))
    discard tree.layout(newSize(16, 3))
    discard tree.requestFocus(second.id)

    let changed = tree.replacePages(tabs.id, [
      newTabPage(newItemId("first-page"), "First", first),
      newTabPage(newItemId("third-page"), "Third", third)])
    check changed.needsRender
    check changed.events.len == 1
    check changed.events[0].kind == focusChanged
    check tabs.active == some(newItemId("third-page"))
    check tree.focused == some(tabs.id)
    check tree.focusOrder == @[tabs.id, third.id]
    check second.allocation.isNone
    discard newWidgetTree(second)
    expect ValueError:
      tabs.setPages(tabs.pages)

  test "tree replacement rejects foreign ownership without mutation":
    let kept = newCheckbox(newWidgetId("kept"), "Kept")
    let tabs = newTabs(newWidgetId("tabs"), [
      newTabPage(newItemId("kept-page"), "Kept", kept)])
    let tree = newWidgetTree(tabs)
    discard tree.layout(newSize(12, 2))
    let foreign = newCheckbox(newWidgetId("foreign"), "Foreign")
    discard newWidgetTree(foreign)
    expect ValueError:
      discard tree.replacePages(tabs.id, [
        newTabPage(newItemId("foreign-page"), "Foreign", foreign)])
    check tabs.pages.len == 1
    check tabs.pages[0].child == Widget(kept)
    check tabs.active == some(newItemId("kept-page"))

  test "nested tabs expose and dispatch only the active page":
    let innerFirst = newScrollList(newWidgetId("inner-first"), [
      newChoiceItem(newItemId("a"), "A"),
      newChoiceItem(newItemId("b"), "B")])
    let innerSecond = newCheckbox(newWidgetId("inner-second"), "Second")
    let inner = newTabs(newWidgetId("inner"), [
      newTabPage(newItemId("inner-first-page"), "List", innerFirst),
      newTabPage(newItemId("inner-second-page"), "Check", innerSecond)])
    let outerOther = newCheckbox(newWidgetId("outer-other"), "Other")
    let outer = newTabs(newWidgetId("outer"), [
      newTabPage(newItemId("nested-page"), "Nested", inner),
      newTabPage(newItemId("other-page"), "Other", outerOther)])
    let tree = newWidgetTree(outer)
    discard tree.layout(newSize(14, 4))
    check tree.focusOrder == @[outer.id, inner.id, innerFirst.id]
    discard tree.requestFocus(innerFirst.id)
    let moved = tree.dispatch(keyInput(keyArrowDown))
    check moved.handled
    check innerFirst.selected == some(newItemId("b"))
    check inner.active == some(newItemId("inner-first-page"))
    check outer.active == some(newItemId("nested-page"))
    discard tree.requestFocus(outer.id)
    discard tree.dispatch(keyInput(keyArrowRight))
    check inner.allocation.isNone
    check tree.focusOrder == @[outer.id, outerOther.id]
