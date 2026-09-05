## Persistent checkbox state. Keyboard behavior is added in Phase 03.

import terminal_widgets/[types, widget]

type Checkbox* = ref object of Widget
  checkedValue: bool

proc newCheckbox*(id: WidgetId; label: string; checked = false): Checkbox =
  new result
  result.initializeWidgetState(id, label)
  result.checkedValue = checked

proc checked*(checkbox: Checkbox): bool = checkbox.checkedValue

proc setChecked*(checkbox: Checkbox; value: bool) =
  ## Programmatic changes invalidate rendering but emit no user event.
  if checkbox.checkedValue != value:
    checkbox.checkedValue = value
    checkbox.touchWidgetState()
