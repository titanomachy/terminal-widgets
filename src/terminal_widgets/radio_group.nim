## Persistent exclusive-choice radio group model.

import std/options
import terminal_widgets/[selection, types, widget]

type RadioGroup* = ref object of Widget
  itemsValue: seq[ChoiceItem]
  selectedValue: Option[ItemId]
  modelValue: SelectionModel

proc accepts(items: openArray[ChoiceItem]; selected: ItemId): bool =
  for item in items:
    if item.id == selected:
      return item.enabled

proc newRadioGroup*(id: WidgetId; items: openArray[ChoiceItem];
                    selected: Option[ItemId] = none(ItemId)): RadioGroup =
  validateItems(items)
  if selected.isSome and not items.accepts(selected.get):
    raise newException(ValueError, "selected item must exist and be enabled")
  new result
  result.initializeWidgetState(id, "")
  result.itemsValue = snapshotItems(items)
  result.selectedValue = selected
  result.modelValue = initSelectionModel(items)
  if selected.isSome:
    discard result.modelValue.setActive(items, selected, 0)

proc items*(group: RadioGroup): seq[ChoiceItem] = snapshotItems(group.itemsValue)
proc selected*(group: RadioGroup): Option[ItemId] = group.selectedValue
proc active*(group: RadioGroup): Option[ItemId] =
  ## Returns the enabled choice targeted by navigation and activation.
  group.modelValue.active
proc topIndex*(group: RadioGroup): int = group.modelValue.topIndex
proc itemCount*(group: RadioGroup): int = group.itemsValue.len

proc viewportHeight(group: RadioGroup): int =
  if group.allocation.isSome: group.allocation.get.height else: 0

proc visibleItems*(group: RadioGroup): seq[ChoiceItem] =
  ## Copies only rows intersecting the current allocated viewport.
  let height = group.viewportHeight
  if height <= 0 or group.itemsValue.len == 0: return
  let stop = if height >= group.itemsValue.len - group.topIndex:
               group.itemsValue.len
             else: group.topIndex + height
  result = newSeqOfCap[ChoiceItem](stop - group.topIndex)
  for index in group.topIndex ..< stop:
    result.add group.itemsValue[index]

method canFocus*(group: RadioGroup): bool = group.itemsValue.hasEnabled

proc setSelected*(group: RadioGroup; value: Option[ItemId]) =
  if value.isSome and not group.itemsValue.accepts(value.get):
    raise newException(ValueError, "selected item must exist and be enabled")
  var changed = group.selectedValue != value
  if value.isSome:
    changed = group.modelValue.setActive(group.itemsValue, value,
      group.viewportHeight) or changed
  if changed:
    group.selectedValue = value
    group.touchWidgetState()

proc replacement(items: openArray[ChoiceItem]; oldItems: openArray[ChoiceItem];
                 oldValue: Option[ItemId]): Option[ItemId] =
  if oldValue.isNone: return none(ItemId)
  for item in items:
    if item.id == oldValue.get and item.enabled: return oldValue
  var oldIndex = 0
  for index, item in oldItems:
    if item.id == oldValue.get:
      oldIndex = index
      break
  if items.len == 0: return none(ItemId)
  let start = min(oldIndex, items.high)
  for index in start .. items.high:
    if items[index].enabled: return some(items[index].id)
  if start > 0:
    for index in countdown(start - 1, 0):
      if items[index].enabled: return some(items[index].id)
  none(ItemId)

proc setItems*(group: RadioGroup; items: openArray[ChoiceItem]) =
  ## Atomically replaces choices while reconciling active and selected IDs.
  validateItems(items)
  let stored = snapshotItems(items)
  var model = group.modelValue
  let modelChanged = model.replace(group.itemsValue, stored,
    group.viewportHeight)
  let nextSelected = replacement(stored, group.itemsValue, group.selectedValue)
  if group.itemsValue != stored or modelChanged or
      group.selectedValue != nextSelected:
    group.itemsValue = stored
    group.modelValue = model
    group.selectedValue = nextSelected
    group.touchWidgetState()

method afterAllocation*(group: RadioGroup) =
  discard group.modelValue.clampViewport(group.itemsValue,
    group.viewportHeight)

method handleInput*(group: RadioGroup; input: InputEvent): DispatchResult =
  if input.kind != eventKey: return
  case input.keyEvent.key
  of keyArrowUp, keyArrowDown, keyHome, keyEnd:
    result.handled = true
    result.needsRender = group.modelValue.navigate(group.itemsValue,
      input.keyEvent.key, group.viewportHeight)
    if result.needsRender:
      group.touchWidgetState()
  of keySpace, keyEnter:
    if group.active.isSome:
      result.handled = true
      if group.selectedValue != group.active:
        group.selectedValue = group.active
        group.touchWidgetState()
        result.needsRender = true
        result.events.add WidgetEvent(kind: selectionChanged, source: group.id,
          selection: group.selectedValue)
  else:
    discard
