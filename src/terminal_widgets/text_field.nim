## Persistent single-line text field model. Editing is added in Phase 06.

import std/unicode
import terminal_widgets/[types, widget]

type TextField* = ref object of Widget
  valueText: string

proc validateFieldText(value: string) =
  if validateUtf8(value) >= 0:
    raise newException(ValueError, "text field value must be valid UTF-8")
  for rune in value.runes:
    let scalar = int(rune)
    if scalar <= 0x1f or scalar == 0x7f or scalar in 0x80 .. 0x9f:
      raise newException(ValueError,
        "text field value must not contain terminal control characters")

proc newTextField*(id: WidgetId; label = ""; value = ""): TextField =
  validateFieldText(value)
  new result
  result.initializeWidgetState(id, label)
  result.valueText = value

proc value*(field: TextField): string = field.valueText

proc setValue*(field: TextField; value: string) =
  ## Replaces the value atomically after single-line text validation.
  validateFieldText(value)
  if field.valueText != value:
    field.valueText = value
    field.touchWidgetState()
