## Persistent exclusive-choice radio group model.

import std/options
import terminal_widgets/[selection, types, widget]

type RadioGroup* = ref object of Widget
  itemsValue: seq[ChoiceItem]
  selectedValue: Option[ItemId]

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

proc items*(group: RadioGroup): seq[ChoiceItem] = snapshotItems(group.itemsValue)
proc selected*(group: RadioGroup): Option[ItemId] = group.selectedValue

method canFocus*(group: RadioGroup): bool = group.itemsValue.hasEnabled

proc setSelected*(group: RadioGroup; value: Option[ItemId]) =
  if value.isSome and not group.itemsValue.accepts(value.get):
    raise newException(ValueError, "selected item must exist and be enabled")
  if group.selectedValue != value:
    group.selectedValue = value
    group.touchWidgetState()
