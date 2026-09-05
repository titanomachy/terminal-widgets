## Persistent scrollable-list collection model.

import std/options
import terminal_widgets/[selection, types, widget]

type ScrollList* = ref object of Widget
  itemsValue: seq[ChoiceItem]
  selectedValue: Option[ItemId]

proc firstEnabled(items: openArray[ChoiceItem]): Option[ItemId] =
  for item in items:
    if item.enabled:
      return some(item.id)
  none(ItemId)

proc newScrollList*(id: WidgetId; items: openArray[ChoiceItem]): ScrollList =
  validateItems(items)
  new result
  result.initializeWidgetState(id, "")
  result.itemsValue = snapshotItems(items)
  result.selectedValue = firstEnabled(items)

proc items*(list: ScrollList): seq[ChoiceItem] = snapshotItems(list.itemsValue)
proc selected*(list: ScrollList): Option[ItemId] = list.selectedValue
