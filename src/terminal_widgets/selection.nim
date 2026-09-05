## Shared keyed item values and collection validation.

import std/[options, sets]
import terminal_widgets/types

type ChoiceItem* = object
  ## One stable, application-keyed choice. Business payloads stay outside it.
  idValue: ItemId
  labelValue: string
  enabledValue: bool

type SelectionModel* = object
  ## Shared stable-key navigation and viewport state for list-like controls.
  activeValue: Option[ItemId]
  topValue: int

proc newChoiceItem*(id: ItemId; label: string; enabled = true): ChoiceItem =
  id.requireValid()
  ChoiceItem(idValue: id, labelValue: label, enabledValue: enabled)

proc id*(item: ChoiceItem): ItemId = item.idValue
proc label*(item: ChoiceItem): string = item.labelValue
proc enabled*(item: ChoiceItem): bool = item.enabledValue

proc setLabel*(item: var ChoiceItem; value: string) = item.labelValue = value
proc setEnabled*(item: var ChoiceItem; value: bool) = item.enabledValue = value

proc validateItems*(items: openArray[ChoiceItem]) =
  ## Rejects empty and duplicate IDs before a control stores a collection.
  var seen = initHashSet[ItemId]()
  for item in items:
    item.id.requireValid()
    if item.id in seen:
      raise newException(ValueError, "duplicate item ID: " & $item.id)
    seen.incl item.id

proc snapshotItems*(items: openArray[ChoiceItem]): seq[ChoiceItem] =
  ## Returns a sequence with storage independent from the caller's sequence.
  result = newSeqOfCap[ChoiceItem](items.len)
  for item in items:
    result.add item

proc hasEnabled*(items: openArray[ChoiceItem]): bool =
  for item in items:
    if item.enabled:
      return true

proc itemIndex*(items: openArray[ChoiceItem]; id: ItemId): int =
  for index, item in items:
    if item.id == id: return index
  -1

proc firstEnabled*(items: openArray[ChoiceItem]): Option[ItemId] =
  for item in items:
    if item.enabled: return some(item.id)
  none(ItemId)

proc accepts*(items: openArray[ChoiceItem]; id: ItemId): bool =
  let index = items.itemIndex(id)
  index >= 0 and items[index].enabled

proc initSelectionModel*(items: openArray[ChoiceItem]): SelectionModel =
  SelectionModel(activeValue: firstEnabled(items), topValue: 0)

proc active*(model: SelectionModel): Option[ItemId] = model.activeValue
proc topIndex*(model: SelectionModel): int = model.topValue

proc clampViewport(model: var SelectionModel; items: openArray[ChoiceItem];
                   viewportHeight: int) =
  if viewportHeight <= 0 or items.len == 0:
    model.topValue = 0
    return
  model.topValue = min(model.topValue, max(0, items.len - viewportHeight))
  if model.activeValue.isSome:
    let index = items.itemIndex(model.activeValue.get)
    if index >= 0:
      if index < model.topValue: model.topValue = index
      elif index - model.topValue >= viewportHeight:
        model.topValue = index - viewportHeight + 1

proc setActive*(model: var SelectionModel; items: openArray[ChoiceItem];
                value: Option[ItemId]; viewportHeight: int): bool =
  if value.isSome and not items.accepts(value.get):
    raise newException(ValueError, "active item must exist and be enabled")
  if model.activeValue != value:
    model.activeValue = value
    model.clampViewport(items, viewportHeight)
    return true

proc replacement(items, oldItems: openArray[ChoiceItem];
                 previous: Option[ItemId]): Option[ItemId] =
  if previous.isSome and items.accepts(previous.get): return previous
  if items.len == 0: return none(ItemId)
  var oldIndex = 0
  if previous.isSome:
    let found = oldItems.itemIndex(previous.get)
    if found >= 0: oldIndex = found
  let start = min(oldIndex, items.high)
  for index in start .. items.high:
    if items[index].enabled: return some(items[index].id)
  if start > 0:
    for index in countdown(start - 1, 0):
      if items[index].enabled: return some(items[index].id)
  none(ItemId)

proc replace*(model: var SelectionModel; oldItems, items: openArray[ChoiceItem];
              viewportHeight: int): bool =
  let next = replacement(items, oldItems, model.activeValue)
  result = model.activeValue != next
  model.activeValue = next
  let previousTop = model.topValue
  model.clampViewport(items, viewportHeight)
  result = result or model.topValue != previousTop

proc navigate*(model: var SelectionModel; items: openArray[ChoiceItem]; key: Key;
               viewportHeight: int): bool =
  if not items.hasEnabled: return false
  var current = if model.activeValue.isSome: items.itemIndex(model.activeValue.get) else: -1
  var target = current
  case key
  of keyHome: target = 0
  of keyEnd: target = items.high
  of keyArrowUp: target = max(0, current - 1)
  of keyArrowDown: target = min(items.high, current + 1)
  of keyPageUp: target = max(0, current - max(1, viewportHeight))
  of keyPageDown:
    let distance = max(1, viewportHeight)
    target = if current > items.high - min(items.high, distance): items.high
             else: min(items.high, current + distance)
  else: return false
  var found = -1
  if key in {keyArrowUp, keyPageUp, keyEnd}:
    for index in countdown(target, 0):
      if items[index].enabled:
        found = index
        break
    if found < 0:
      for index in 0 .. items.high:
        if items[index].enabled:
          found = index
          break
  else:
    for index in target .. items.high:
      if items[index].enabled:
        found = index
        break
    if found < 0:
      for index in countdown(items.high, 0):
        if items[index].enabled:
          found = index
          break
  if found >= 0:
    result = model.setActive(items, some(items[found].id), viewportHeight)
