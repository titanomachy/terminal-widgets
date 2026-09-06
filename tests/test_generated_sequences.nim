import std/[options, random, sets, unicode, unittest]
import terminal_style
import terminal_widgets

const Seeds = [0x5eed'u64, 0xc0ffee'u64, 0xdecafbad'u64]

proc choices(enabled = true): seq[ChoiceItem] = @[
  newChoiceItem(newItemId("zero"), "Zero", enabled),
  newChoiceItem(newItemId("one"), "One", enabled),
  newChoiceItem(newItemId("two"), "Two", enabled)
]

proc containsEnabled(items: seq[ChoiceItem]; selected: Option[ItemId]): bool =
  if selected.isNone: return false
  for item in items:
    if item.id == selected.get:
      return item.enabled

proc verifyInvariants(tree: WidgetTree; widgets: openArray[Widget];
                      list: ScrollList; menu: Menu; size: Size;
                      checkAttached: bool) =
  var ids = initHashSet[WidgetId]()
  for id in tree.focusOrder:
    check id notin ids
    ids.incl id
  if tree.focusOrder.len == 0:
    check tree.focused.isNone
  else:
    check tree.focused.isSome
    check tree.focused.get in ids

  for widget in widgets:
    if widget.allocation.isSome:
      let bounds = widget.allocation.get
      check bounds.x >= 0 and bounds.y >= 0
      check bounds.x + bounds.width <= size.width
      check bounds.y + bounds.height <= size.height
  if not checkAttached:
    check widgets[1].allocation.isNone

  if list.items.len == 0:
    check list.selected.isNone
  else:
    check containsEnabled(list.items, list.selected)
  if menu.items.len == 0 or not menu.items.containsEnabled(menu.active):
    check menu.active.isNone

  let frame = tree.render(size, plainWidgetTheme())
  check frame.rows.len == size.height
  for row in frame.rows:
    check validateUtf8(row) == -1
    check displayWidth(row) == size.width
  if frame.cursor.isSome:
    check frame.cursor.get.column in 0 ..< size.width
    check frame.cursor.get.row in 0 ..< size.height

suite "seeded generated tree and event sequences":
  test "edge fixtures reject duplicates and repair removed or disabled focus":
    let checkbox = newCheckbox(newWidgetId("checkbox"), "Checkbox")
    let field = newTextField(newWidgetId("field"), value = "kept")
    let list = newScrollList(newWidgetId("list"), choices())
    let menu = newMenu(newWidgetId("menu"), choices())
    let root = newColumn(newWidgetId("root"),
      [Widget(checkbox), Widget(field), Widget(list), Widget(menu)])
    let tree = newWidgetTree(root)
    let size = newSize(18, 8)
    discard tree.layout(size)

    expect ValueError:
      discard tree.attach(root.id,
        newSwitch(newWidgetId("field"), "Duplicate ID"))
    let oldItems = list.items
    expect ValueError:
      list.setItems([
        newChoiceItem(newItemId("same"), "First"),
        newChoiceItem(newItemId("same"), "Second")])
    check list.items == oldItems

    discard tree.requestFocus(checkbox.id)
    discard tree.detach(checkbox.id)
    check checkbox.allocation.isNone
    check tree.focused.isSome and tree.focused.get != checkbox.id
    discard tree.attach(root.id, checkbox, 0)

    for widget in [Widget(checkbox), Widget(field), Widget(list), Widget(menu)]:
      widget.setEnabled(false)
    discard tree.layout(size)
    check tree.focusOrder.len == 0
    check tree.focused.isNone
    for widget in [Widget(checkbox), Widget(field), Widget(list), Widget(menu)]:
      widget.setEnabled(true)
    list.setItems([])
    menu.setItems([])
    discard tree.layout(size)
    check list.selected.isNone
    check menu.active.isNone

  test "three reproducible sequences preserve invariants after every step":
    for seed in Seeds:
      checkpoint "generated sequence seed=" & $seed
      let checkbox = newCheckbox(newWidgetId("checkbox"), "Checkbox")
      let field = newTextField(newWidgetId("field"), maxRunes = 64)
      let list = newScrollList(newWidgetId("list"), choices())
      let menu = newMenu(newWidgetId("menu"), choices())
      let root = newColumn(newWidgetId("root"),
        [Widget(checkbox), Widget(field), Widget(list), Widget(menu)])
      root.setSizing(checkbox.id, fixed(1))
      root.setSizing(field.id, fixed(1))
      let tree = newWidgetTree(root)
      var size = newSize(18, 8)
      var checkAttached = true
      discard tree.layout(size)
      var generator = initRand(int64(seed))
      let keys = [keyTab, keyBacktab, keyArrowUp, keyArrowDown, keyHome,
        keyEnd, keyPageUp, keyPageDown, keySpace, keyEnter]

      for step in 0 ..< 750:
        checkpoint "seed=" & $seed & " step=" & $step
        case generator.rand(9)
        of 0:
          discard tree.dispatch(keyInput(keys[generator.rand(keys.high)]))
        of 1:
          if checkAttached:
            checkbox.setVisible(not checkbox.visible)
            discard tree.layout(size)
        of 2:
          field.setEnabled(not field.enabled)
          discard tree.layout(size)
        of 3:
          if generator.rand(1) == 0: list.setItems([])
          else: list.setItems(choices())
          discard tree.layout(size)
        of 4:
          if generator.rand(1) == 0: menu.setItems(choices(enabled = false))
          else: menu.setItems(choices())
          discard tree.layout(size)
        of 5:
          size = newSize(generator.rand(24), generator.rand(10))
          discard tree.layout(size)
        of 6:
          if tree.focusOrder.len > 0:
            discard tree.requestFocus(
              tree.focusOrder[generator.rand(tree.focusOrder.high)])
        of 7:
          if checkAttached:
            if tree.focused == some(checkbox.id):
              discard tree.detach(checkbox.id)
              checkAttached = false
          else:
            discard tree.attach(root.id, checkbox, 0)
            checkAttached = true
        of 8:
          if field.enabled and field.visible and field.id in tree.focusOrder:
            discard tree.requestFocus(field.id)
            discard tree.dispatch(keyInput(keyText,
              text = $char(ord('a') + generator.rand(25))))
        else:
          discard tree.layout(size)

        verifyInvariants(tree,
          [Widget(root), Widget(checkbox), Widget(field), Widget(list), Widget(menu)],
          list, menu, size, checkAttached)
