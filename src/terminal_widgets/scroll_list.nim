## Persistent scrollable-list collection model.

import std/options
import terminal_widgets/[selection, types, widget]

type ScrollList* = ref object of Widget
  itemsValue: seq[ChoiceItem]
  modelValue: SelectionModel

proc newScrollList*(id: WidgetId; items: openArray[ChoiceItem]): ScrollList =
  validateItems(items)
  new result
  result.initializeWidgetState(id, "")
  result.itemsValue = snapshotItems(items)
  result.modelValue = initSelectionModel(items)

proc items*(list: ScrollList): seq[ChoiceItem] = snapshotItems(list.itemsValue)
proc selected*(list: ScrollList): Option[ItemId] = list.modelValue.active
proc topIndex*(list: ScrollList): int = list.modelValue.topIndex
proc itemCount*(list: ScrollList): int = list.itemsValue.len

proc visibleItems*(list: ScrollList): seq[ChoiceItem] =
  ## Copies only rows intersecting the current allocated viewport.
  let height = if list.allocation.isSome: list.allocation.get.height else: 0
  if height <= 0 or list.itemsValue.len == 0: return
  let stop = if height >= list.itemsValue.len - list.topIndex:
               list.itemsValue.len
             else: list.topIndex + height
  result = newSeqOfCap[ChoiceItem](stop - list.topIndex)
  for index in list.topIndex ..< stop:
    result.add list.itemsValue[index]

proc viewportHeight(list: ScrollList): int =
  if list.allocation.isSome: list.allocation.get.height else: 0

proc setSelected*(list: ScrollList; value: Option[ItemId]) =
  if list.modelValue.setActive(list.itemsValue, value, list.viewportHeight):
    list.touchWidgetState()

proc setItems*(list: ScrollList; items: openArray[ChoiceItem]) =
  validateItems(items)
  let stored = snapshotItems(items)
  var model = list.modelValue
  let stateChanged = model.replace(list.itemsValue, stored, list.viewportHeight)
  if list.itemsValue != stored or stateChanged:
    list.itemsValue = stored
    list.modelValue = model
    list.touchWidgetState()

method canFocus*(list: ScrollList): bool = list.itemsValue.hasEnabled

method afterAllocation*(list: ScrollList) =
  discard list.modelValue.clampViewport(list.itemsValue, list.viewportHeight)

method handleInput*(list: ScrollList; input: InputEvent): DispatchResult =
  if input.kind != eventKey or input.keyEvent.key notin {
      keyArrowUp, keyArrowDown, keyHome, keyEnd, keyPageUp, keyPageDown}:
    return
  result.handled = true
  if list.modelValue.navigate(list.itemsValue, input.keyEvent.key,
      list.viewportHeight):
    list.touchWidgetState()
    result.needsRender = true
    result.events.add WidgetEvent(kind: selectionChanged, source: list.id,
      selection: list.selected)
