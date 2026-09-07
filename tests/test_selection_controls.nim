import std/[options, unittest]
import terminal_widgets

proc choices(): seq[ChoiceItem] = @[
  newChoiceItem(newItemId("zero"), "Zero"),
  newChoiceItem(newItemId("one"), "One", enabled = false),
  newChoiceItem(newItemId("two"), "Two"),
  newChoiceItem(newItemId("three"), "Three"),
  newChoiceItem(newItemId("four"), "Four")
]

suite "scroll list and menu selection model":
  test "list navigation changes selection and keeps it visible":
    let list = newScrollList(newWidgetId("list"), choices())
    let tree = newWidgetTree(list)
    discard tree.layout(newSize(20, 2))
    check list.selected == some(newItemId("zero"))
    check list.topIndex == 0

    let down = tree.dispatch(keyInput(keyArrowDown))
    check down.handled and down.events.len == 1
    check list.selected == some(newItemId("two"))
    check list.topIndex == 1
    let page = tree.dispatch(keyInput(keyPageDown))
    check page.events.len == 1
    check list.selected == some(newItemId("four"))
    check list.topIndex == 3
    check not tree.dispatch(keyInput(keyEnter)).handled
    check not tree.dispatch(keyInput(keySpace)).handled

  test "menu navigation and activation are distinct":
    let menu = newMenu(newWidgetId("menu"), choices())
    let tree = newWidgetTree(menu)
    discard tree.layout(newSize(20, 3))
    let moved = tree.dispatch(keyInput(keyEnd))
    check moved.events.len == 1
    check moved.events[0].kind == selectionChanged
    check menu.active == some(newItemId("four"))
    let firstActivation = tree.dispatch(keyInput(keyEnter))
    let secondActivation = tree.dispatch(keyInput(keyEnter))
    check firstActivation.events.len == 1
    check secondActivation.events.len == 1
    check firstActivation.events[0].kind == activated
    check firstActivation.events[0].item == newItemId("four")
    check not tree.dispatch(keyInput(keySpace)).handled

  test "item replacement reconciles stable selection and viewport":
    let list = newScrollList(newWidgetId("list"), choices())
    let tree = newWidgetTree(list)
    discard tree.layout(newSize(20, 2))
    list.setSelected(some(newItemId("three")))
    check list.topIndex == 2
    list.setItems([
      newChoiceItem(newItemId("new"), "New"),
      newChoiceItem(newItemId("three"), "Renamed Three")
    ])
    check list.selected == some(newItemId("three"))
    check list.topIndex == 0
    list.setItems([newChoiceItem(newItemId("fallback"), "Fallback")])
    check list.selected == some(newItemId("fallback"))
    check list.topIndex == 0

  test "list and menu clamp their viewport after shrinking allocation":
    let list = newScrollList(newWidgetId("resized-list"), choices())
    let menu = newMenu(newWidgetId("resized-menu"), choices())
    let root = newRow(newWidgetId("resized-root"),
      [Widget(list), Widget(menu)])
    let tree = newWidgetTree(root)
    discard tree.layout(newSize(20, 4))
    list.setSelected(some(newItemId("four")))
    menu.setActive(some(newItemId("four")))
    check list.topIndex == 1
    check menu.topIndex == 1
    discard tree.dispatch(resizeInput(terminalSize(20, 1)))
    check list.topIndex == 4
    check menu.topIndex == 4

  test "boundaries disabled data empty data and zero height are inert":
    let list = newScrollList(newWidgetId("list"), choices())
    let tree = newWidgetTree(list)
    discard tree.layout(newSize(20, 2))
    check tree.dispatch(keyInput(keyArrowUp)).events.len == 0
    check tree.dispatch(keyInput(keyHome)).events.len == 0

    let disabled = newMenu(newWidgetId("disabled"), [
      newChoiceItem(newItemId("one"), "One", enabled = false)])
    let disabledTree = newWidgetTree(disabled)
    discard disabledTree.layout(newSize(20, 1))
    check disabledTree.focused.isNone

    let empty = newScrollList(newWidgetId("empty"), [])
    let emptyTree = newWidgetTree(empty)
    discard emptyTree.layout(newSize(20, 1))
    check renderControl(empty, plainWidgetTheme()) == @["  (empty)"]
    discard emptyTree.layout(newSize(20, 0))
    check renderControl(empty, plainWidgetTheme()).len == 0

  test "large-list rendering visits only allocated visible rows":
    var items = newSeqOfCap[ChoiceItem](100_000)
    for index in 0 ..< 100_000:
      items.add newChoiceItem(newItemId($index), "Item " & $index)
    let list = newScrollList(newWidgetId("large"), items)
    let tree = newWidgetTree(list)
    discard tree.layout(newSize(24, 5))
    list.setSelected(some(newItemId("99999")))
    var metrics: RenderMetrics
    let rows = renderControl(list, plainWidgetTheme(), metrics, focused = true)
    check rows.len == 5
    check metrics.visitedItems == 5
    check list.topIndex == 99_995
    check rows[^1] == "> Item 99999"
