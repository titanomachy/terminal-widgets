## Persistent checkbox state. Keyboard behavior is added in Phase 03.

import terminal_widgets/[types, widget]

type Checkbox* = ref object of Widget
  checkedValue: bool

proc newCheckbox*(id: WidgetId; label: string; checked = false): Checkbox =
  new result
  result.initializeWidgetState(id, label)
  result.checkedValue = checked

proc checked*(checkbox: Checkbox): bool = checkbox.checkedValue

method canFocus*(checkbox: Checkbox): bool = true

proc marker*(checkbox: Checkbox): string =
  ## Returns the stable plain-mode checkbox marker.
  if checkbox.checkedValue: "[x]" else: "[ ]"

method handleInput*(checkbox: Checkbox; input: InputEvent): DispatchResult =
  if input.kind == eventKey and input.keyEvent.key in {keySpace, keyEnter}:
    checkbox.checkedValue = not checkbox.checkedValue
    checkbox.touchWidgetState()
    result = dispatchResult(handled = true, needsRender = true)
    result.events.add WidgetEvent(kind: boolChanged, source: checkbox.id,
      boolValue: checkbox.checkedValue)

proc setChecked*(checkbox: Checkbox; value: bool) =
  ## Programmatic changes invalidate rendering but emit no user event.
  if checkbox.checkedValue != value:
    checkbox.checkedValue = value
    checkbox.touchWidgetState()
