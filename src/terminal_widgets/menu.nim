## Persistent menu collection model.

import std/options
import terminal_widgets/[selection, types, widget]

type Menu* = ref object of Widget
  itemsValue: seq[ChoiceItem]
  activeValue: Option[ItemId]

proc firstEnabled(items: openArray[ChoiceItem]): Option[ItemId] =
  for item in items:
    if item.enabled:
      return some(item.id)
  none(ItemId)

proc newMenu*(id: WidgetId; items: openArray[ChoiceItem]): Menu =
  validateItems(items)
  new result
  result.initializeWidgetState(id, "")
  result.itemsValue = snapshotItems(items)
  result.activeValue = firstEnabled(items)

proc items*(menu: Menu): seq[ChoiceItem] = snapshotItems(menu.itemsValue)
proc active*(menu: Menu): Option[ItemId] = menu.activeValue
