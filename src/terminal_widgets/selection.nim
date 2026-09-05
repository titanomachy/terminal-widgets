## Shared keyed item values and collection validation.

import std/sets
import terminal_widgets/types

type ChoiceItem* = object
  ## One stable, application-keyed choice. Business payloads stay outside it.
  idValue: ItemId
  labelValue: string
  enabledValue: bool

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
