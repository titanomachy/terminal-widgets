## Persistent switch state. Keyboard behavior is added in Phase 03.

import terminal_widgets/[types, widget]

type Switch* = ref object of Widget
  onValue: bool

proc newSwitch*(id: WidgetId; label: string; on = false): Switch =
  new result
  result.initializeWidgetState(id, label)
  result.onValue = on

proc isOn*(switch: Switch): bool = switch.onValue

method canFocus*(switch: Switch): bool = true

proc marker*(switch: Switch): string =
  ## Returns the stable plain-mode switch marker.
  if switch.onValue: "[on]" else: "[off]"

method handleInput*(switch: Switch; input: InputEvent): DispatchResult =
  if input.kind == eventKey and input.keyEvent.key in {keySpace, keyEnter}:
    switch.onValue = not switch.onValue
    switch.touchWidgetState()
    result = dispatchResult(handled = true, needsRender = true)
    result.events.add WidgetEvent(kind: boolChanged, source: switch.id,
      boolValue: switch.onValue)

proc setOn*(switch: Switch; value: bool) =
  ## Programmatic changes invalidate rendering but emit no user event.
  if switch.onValue != value:
    switch.onValue = value
    switch.touchWidgetState()
