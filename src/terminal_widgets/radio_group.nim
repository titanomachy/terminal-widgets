## Persistent exclusive-choice radio group model.

import std/options
import terminal_widgets/[selection, types, widget]

type RadioGroup* = ref object of Widget
  itemsValue: seq[ChoiceItem]
  selectedValue: Option[ItemId]
  activeValue: Option[ItemId]

proc accepts(items: openArray[ChoiceItem]; selected: ItemId): bool =
  for item in items:
    if item.id == selected:
      return item.enabled

proc firstEnabled(items: openArray[ChoiceItem]): Option[ItemId] =
  for item in items:
    if item.enabled: return some(item.id)
  none(ItemId)

proc newRadioGroup*(id: WidgetId; items: openArray[ChoiceItem];
                    selected: Option[ItemId] = none(ItemId)): RadioGroup =
  validateItems(items)
  if selected.isSome and not items.accepts(selected.get):
    raise newException(ValueError, "selected item must exist and be enabled")
  new result
  result.initializeWidgetState(id, "")
  result.itemsValue = snapshotItems(items)
  result.selectedValue = selected
  result.activeValue = if selected.isSome: selected else: firstEnabled(items)

proc items*(group: RadioGroup): seq[ChoiceItem] = snapshotItems(group.itemsValue)
proc selected*(group: RadioGroup): Option[ItemId] = group.selectedValue
proc active*(group: RadioGroup): Option[ItemId] =
  ## Returns the enabled choice targeted by navigation and activation.
  group.activeValue

method canFocus*(group: RadioGroup): bool = group.itemsValue.hasEnabled

proc setSelected*(group: RadioGroup; value: Option[ItemId]) =
  if value.isSome and not group.itemsValue.accepts(value.get):
    raise newException(ValueError, "selected item must exist and be enabled")
  if group.selectedValue != value:
    group.selectedValue = value
    if value.isSome:
      group.activeValue = value
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
  var nextActive = replacement(stored, group.itemsValue, group.activeValue)
  if group.activeValue.isNone: nextActive = firstEnabled(stored)
  let nextSelected = replacement(stored, group.itemsValue, group.selectedValue)
  if group.itemsValue != stored or group.activeValue != nextActive or
      group.selectedValue != nextSelected:
    group.itemsValue = stored
    group.activeValue = nextActive
    group.selectedValue = nextSelected
    group.touchWidgetState()

proc enabledIds(group: RadioGroup): seq[ItemId] =
  for item in group.itemsValue:
    if item.enabled: result.add item.id

proc moveActive(group: RadioGroup; key: Key): bool =
  let ids = group.enabledIds()
  if ids.len == 0: return false
  var index = if group.activeValue.isSome: ids.find(group.activeValue.get) else: 0
  if index < 0: index = 0
  let next = case key
    of keyArrowUp: max(0, index - 1)
    of keyArrowDown: min(ids.high, index + 1)
    of keyHome: 0
    of keyEnd: ids.high
    else: index
  let value = some(ids[next])
  if group.activeValue != value:
    group.activeValue = value
    group.touchWidgetState()
    return true

method handleInput*(group: RadioGroup; input: InputEvent): DispatchResult =
  if input.kind != eventKey: return
  case input.keyEvent.key
  of keyArrowUp, keyArrowDown, keyHome, keyEnd:
    result.handled = true
    result.needsRender = group.moveActive(input.keyEvent.key)
  of keySpace, keyEnter:
    if group.activeValue.isSome:
      result.handled = true
      if group.selectedValue != group.activeValue:
        group.selectedValue = group.activeValue
        group.touchWidgetState()
        result.needsRender = true
        result.events.add WidgetEvent(kind: selectionChanged, source: group.id,
          selection: group.selectedValue)
  else:
    discard
