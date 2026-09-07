## Persistent menu collection model.

import std/options
import terminal_widgets/[selection, types, widget]

type Menu* = ref object of Widget
  itemsValue: seq[ChoiceItem]
  modelValue: SelectionModel

proc newMenu*(id: WidgetId; items: openArray[ChoiceItem]): Menu =
  validateItems(items)
  new result
  result.initializeWidgetState(id, "")
  result.itemsValue = snapshotItems(items)
  result.modelValue = initSelectionModel(items)

proc items*(menu: Menu): seq[ChoiceItem] = snapshotItems(menu.itemsValue)
proc active*(menu: Menu): Option[ItemId] = menu.modelValue.active
proc topIndex*(menu: Menu): int = menu.modelValue.topIndex
proc itemCount*(menu: Menu): int = menu.itemsValue.len

proc visibleItems*(menu: Menu): seq[ChoiceItem] =
  ## Copies only rows intersecting the current allocated viewport.
  let height = if menu.allocation.isSome: menu.allocation.get.height else: 0
  if height <= 0 or menu.itemsValue.len == 0: return
  let stop = if height >= menu.itemsValue.len - menu.topIndex:
               menu.itemsValue.len
             else: menu.topIndex + height
  result = newSeqOfCap[ChoiceItem](stop - menu.topIndex)
  for index in menu.topIndex ..< stop:
    result.add menu.itemsValue[index]

proc viewportHeight(menu: Menu): int =
  if menu.allocation.isSome: menu.allocation.get.height else: 0

proc setActive*(menu: Menu; value: Option[ItemId]) =
  if menu.modelValue.setActive(menu.itemsValue, value, menu.viewportHeight):
    menu.touchWidgetState()

proc setItems*(menu: Menu; items: openArray[ChoiceItem]) =
  validateItems(items)
  let stored = snapshotItems(items)
  var model = menu.modelValue
  let stateChanged = model.replace(menu.itemsValue, stored, menu.viewportHeight)
  if menu.itemsValue != stored or stateChanged:
    menu.itemsValue = stored
    menu.modelValue = model
    menu.touchWidgetState()

method canFocus*(menu: Menu): bool = menu.itemsValue.hasEnabled

method afterAllocation*(menu: Menu) =
  discard menu.modelValue.clampViewport(menu.itemsValue, menu.viewportHeight)

method handleInput*(menu: Menu; input: InputEvent): DispatchResult =
  if input.kind != eventKey: return
  if input.keyEvent.key in {
      keyArrowUp, keyArrowDown, keyHome, keyEnd, keyPageUp, keyPageDown}:
    result.handled = true
    if menu.modelValue.navigate(menu.itemsValue, input.keyEvent.key,
        menu.viewportHeight):
      menu.touchWidgetState()
      result.needsRender = true
      result.events.add WidgetEvent(kind: selectionChanged, source: menu.id,
        selection: menu.active)
  elif input.keyEvent.key == keyEnter and menu.active.isSome:
    result.handled = true
    result.events.add WidgetEvent(kind: activated, source: menu.id,
      item: menu.active.get)
