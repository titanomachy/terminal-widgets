## Persistent, single-line UTF-8 text field.
##
## Text editing is independent from terminal I/O. The field stores a byte
## cursor at a bounded editing boundary, a cell-based horizontal viewport, and
## typed submission/validation outcomes returned by ``WidgetTree.dispatch``.

import std/[options, unicode]
import terminal_style
import terminal_widgets/[editor, text_policy, theme, types, widget]

const DefaultTextFieldMaxRunes* = 4096

type TextValidator* = proc(value: string): Option[string] {.closure.}

type TextField* = ref object of Widget
  valueText: string
  cursorByteValue: int
  horizontalOffsetValue: int
  maxRunesValue: int
  placeholderValue: string
  readOnlyValue: bool
  validatorValue: TextValidator
  validationErrorValue: Option[string]

proc hasUnsafeScalar(scalar: int): bool {.inline.} =
  isControlScalar(scalar)

proc validateFieldText(value: string) =
  if validateUtf8(value) >= 0:
    raise newException(ValueError, "text field value must be valid UTF-8")
  for rune in value.runes:
    if hasUnsafeScalar(int(rune)):
      raise newException(ValueError,
        "text field value must not contain terminal control characters")

proc fieldTextIsSafe(value: string): bool =
  if validateUtf8(value) >= 0:
    return false
  for rune in value.runes:
    if hasUnsafeScalar(int(rune)):
      return false
  true

proc validateMaxRunes(value: int) =
  if value <= 0:
    raise newException(ValueError, "text field maxRunes must be positive")

proc labelCells(field: TextField): int {.inline.} =
  if field.label.len == 0: 0
  else: displayWidth(sanitizePlainText(field.label)) + 2

proc contentStartCells*(field: TextField;
                        theme = defaultWidgetTheme()): int =
  ## Number of frame cells reserved before content for the selected theme.
  theme.validateTheme()
  displayWidth(theme.focusMarker) + 1 + field.labelCells

proc contentWidth*(field: TextField; theme = defaultWidgetTheme()): int =
  ## Width left after the measured theme marker and sanitized label.
  if field.allocation.isNone:
    return 0
  max(0, field.allocation.get.width - field.contentStartCells(theme))

proc cursorValueCells(field: TextField): int {.inline.} =
  if field.cursorByteValue == 0:
    return 0
  displayWidth(field.valueText[0 ..< field.cursorByteValue])

proc totalValueCells(field: TextField): int {.inline.} =
  displayWidth(field.valueText)

proc calculatedHorizontalOffset(field: TextField; viewport: int): int =
  if viewport <= 0:
    return 0
  let cursorCells = field.cursorValueCells
  let totalCells = field.totalValueCells
  # One extra scroll cell at the end leaves a blank caret cell when content
  # exactly fills the viewport. This is intentional and frame-local.
  let maximum = max(0, totalCells - viewport + 1)
  var offset = min(max(0, field.horizontalOffsetValue), maximum)
  if cursorCells < offset:
    offset = cursorCells
  elif cursorCells > offset + viewport - 1:
    offset = min(maximum, cursorCells - viewport + 1)
  offset

proc adjustHorizontalOffset(field: TextField;
                            theme = defaultWidgetTheme()) =
  field.horizontalOffsetValue = field.calculatedHorizontalOffset(
    field.contentWidth(theme))

proc clearValidationError(field: TextField): bool =
  if field.validationErrorValue.isSome:
    field.validationErrorValue = none(string)
    return true
  false

proc newTextField*(id: WidgetId; label = ""; value = "";
                   maxRunes = DefaultTextFieldMaxRunes; placeholder = "";
                   readOnly = false; validator: TextValidator = nil): TextField =
  ## Creates a field. ``maxRunes`` counts Unicode scalars, not bytes/cells.
  validateMaxRunes(maxRunes)
  validateFieldText(value)
  validateFieldText(placeholder)
  if scalarCount(value) > maxRunes:
    raise newException(ValueError,
      "text field value exceeds maxRunes scalar limit")
  new result
  result.initializeWidgetState(id, label)
  result.valueText = value
  result.cursorByteValue = 0
  result.horizontalOffsetValue = 0
  result.maxRunesValue = maxRunes
  result.placeholderValue = placeholder
  result.readOnlyValue = readOnly
  result.validatorValue = validator
  result.validationErrorValue = none(string)

proc value*(field: TextField): string = field.valueText
proc cursorByte*(field: TextField): int = field.cursorByteValue
proc cursor*(field: TextField): int = field.cursorByteValue
proc horizontalOffset*(field: TextField): int = field.horizontalOffsetValue
proc horizontalOffset*(field: TextField; theme: WidgetTheme): int =
  ## Returns the effective offset for a theme without mutating retained state.
  field.calculatedHorizontalOffset(field.contentWidth(theme))
proc viewportOffset*(field: TextField): int = field.horizontalOffsetValue
proc maxRunes*(field: TextField): int = field.maxRunesValue
proc placeholder*(field: TextField): string = field.placeholderValue
proc readOnly*(field: TextField): bool = field.readOnlyValue
proc validator*(field: TextField): TextValidator = field.validatorValue
proc validationError*(field: TextField): Option[string] =
  field.validationErrorValue

proc cursorCell*(field: TextField;
                 theme = defaultWidgetTheme()): Option[int] =
  ## Returns the frame-local zero-based cursor column when a content cell is
  ## visible. The runtime adds its frame origin when addressing the terminal.
  let bounds = field.allocation
  let viewport = field.contentWidth(theme)
  if bounds.isNone or bounds.get.width <= 0 or bounds.get.height <= 0 or
      viewport <= 0:
    return none(int)
  let offset = field.horizontalOffset(theme)
  let local = field.contentStartCells(theme) + field.cursorValueCells - offset
  if local < 0 or local >= bounds.get.width:
    return none(int)
  some(bounds.get.x + local)

proc visibleText*(field: TextField; width: int): string =
  ## Returns a cell-clipped value window suitable for semantic renderers.
  if width <= 0:
    return ""
  field.adjustHorizontalOffset()
  let source = if field.valueText.len == 0: field.placeholderValue else: field.valueText
  padAnsi(sliceAnsi(source, field.horizontalOffsetValue, width), width)

proc setCursorByte*(field: TextField; byteOffset: int) =
  ## Sets a byte cursor only at a supported editing boundary.
  if not field.valueText.isEditingBoundary(byteOffset):
    raise newException(ValueError,
      "text field cursor must be an editing-boundary byte offset")
  if field.cursorByteValue != byteOffset:
    field.cursorByteValue = byteOffset
    field.adjustHorizontalOffset()
    field.touchWidgetState()

proc setCursor*(field: TextField; byteOffset: int) =
  field.setCursorByte(byteOffset)

proc setValue*(field: TextField; value: string) =
  ## Replaces the value atomically after UTF-8, control, and scalar-limit checks.
  validateFieldText(value)
  if scalarCount(value) > field.maxRunesValue:
    raise newException(ValueError,
      "text field value exceeds maxRunes scalar limit")
  let oldValue = field.valueText
  let oldCursor = field.cursorByteValue
  let oldError = field.validationErrorValue
  field.valueText = value
  if oldCursor > value.len:
    field.cursorByteValue = value.len
  elif value.isEditingBoundary(oldCursor):
    field.cursorByteValue = oldCursor
  else:
    field.cursorByteValue = value.nextEditingBoundary(oldCursor)
  discard field.clearValidationError()
  field.adjustHorizontalOffset()
  if oldValue != value or oldCursor != field.cursorByteValue or
      oldError != field.validationErrorValue:
    field.touchWidgetState()

proc setMaxRunes*(field: TextField; value: int) =
  ## Changes the positive Unicode-scalar limit without truncating existing text.
  validateMaxRunes(value)
  if scalarCount(field.valueText) > value:
    raise newException(ValueError,
      "text field value exceeds maxRunes scalar limit")
  let hadError = field.clearValidationError()
  if field.maxRunesValue != value:
    field.maxRunesValue = value
    field.touchWidgetState()
  elif hadError:
    field.touchWidgetState()

proc setPlaceholder*(field: TextField; value: string) =
  validateFieldText(value)
  let hadError = field.clearValidationError()
  if field.placeholderValue != value:
    field.placeholderValue = value
    field.touchWidgetState()
  elif hadError:
    field.touchWidgetState()

proc setReadOnly*(field: TextField; value: bool) =
  let hadError = field.clearValidationError()
  if field.readOnlyValue != value:
    field.readOnlyValue = value
    field.touchWidgetState()
  elif hadError:
    field.touchWidgetState()

proc setValidator*(field: TextField; value: TextValidator) =
  # Closure values cannot be compared meaningfully. Assignment is explicit and
  # always invalidates the retained field metadata.
  field.validatorValue = value
  discard field.clearValidationError()
  field.touchWidgetState()

proc clearValidation*(field: TextField) =
  if field.clearValidationError():
    field.touchWidgetState()

method canFocus*(field: TextField): bool = true

proc unsupportedModifiers(modifiers: set[Modifier]): bool {.inline.} =
  modifierCtrl in modifiers or modifierAlt in modifiers

proc moveCursor(field: TextField; target: int): DispatchResult =
  result.handled = true
  if target != field.cursorByteValue:
    field.cursorByteValue = target
    field.adjustHorizontalOffset()
    field.touchWidgetState()
    result.needsRender = true

proc insertText(field: TextField; inserted: string): DispatchResult =
  result.handled = true
  if field.readOnlyValue or inserted.len == 0:
    return
  if not fieldTextIsSafe(inserted):
    return
  let existingScalars = scalarCount(field.valueText)
  let insertedScalars = scalarCount(inserted)
  if insertedScalars > field.maxRunesValue - existingScalars:
    return
  let before = field.valueText[0 ..< field.cursorByteValue]
  let after =
    if field.cursorByteValue < field.valueText.len:
      field.valueText[field.cursorByteValue .. ^1]
    else:
      ""
  let candidate = before & inserted & after
  # Validate the complete result before changing any retained state. In
  # particular, a ZWJ or combining mark may join text on either side.
  if not fieldTextIsSafe(candidate) or scalarCount(candidate) > field.maxRunesValue:
    return
  let requested = before.len + inserted.len
  field.valueText = candidate
  field.cursorByteValue = candidate.nextEditingBoundary(requested)
  discard field.clearValidationError()
  field.adjustHorizontalOffset()
  field.touchWidgetState()
  result.needsRender = true
  result.events.add WidgetEvent(kind: textChanged, source: field.id,
    text: field.valueText)

proc deleteRange(field: TextField; first, last: int): DispatchResult =
  result.handled = true
  if first >= last:
    return
  let before = field.valueText[0 ..< first]
  let after = if last < field.valueText.len: field.valueText[last .. ^1] else: ""
  field.valueText = before & after
  field.cursorByteValue = first
  discard field.clearValidationError()
  field.adjustHorizontalOffset()
  field.touchWidgetState()
  result.needsRender = true
  result.events.add WidgetEvent(kind: textChanged, source: field.id,
    text: field.valueText)

method handleInput*(field: TextField; input: InputEvent): DispatchResult =
  if input.kind != eventKey:
    return
  let event = input.keyEvent
  if event.key in {keyTab, keyBacktab}:
    return
  if unsupportedModifiers(event.modifiers):
    return

  case event.key
  of keyText:
    return field.insertText(event.text)
  of keySpace:
    return field.insertText(" ")
  of keyArrowLeft:
    return field.moveCursor(field.valueText.previousEditingBoundary(
      field.cursorByteValue - 1))
  of keyArrowRight:
    return field.moveCursor(field.valueText.nextEditingBoundary(
      field.cursorByteValue + 1))
  of keyHome:
    return field.moveCursor(0)
  of keyEnd:
    return field.moveCursor(field.valueText.len)
  of keyBackspace:
    result.handled = true
    if field.readOnlyValue:
      return
    let first = field.valueText.previousEditingBoundary(field.cursorByteValue - 1)
    return field.deleteRange(first, field.cursorByteValue)
  of keyDelete:
    result.handled = true
    if field.readOnlyValue:
      return
    let last = field.valueText.nextEditingBoundary(field.cursorByteValue + 1)
    return field.deleteRange(field.cursorByteValue, last)
  of keyEnter:
    result.handled = true
    if field.validatorValue.isNil:
      if field.clearValidationError():
        field.touchWidgetState()
        result.needsRender = true
      result.events.add WidgetEvent(kind: submitted, source: field.id,
        text: field.valueText)
      return
    let validation = field.validatorValue(field.valueText)
    if validation.isSome:
      let message = sanitizePlainText(validation.get)
      field.validationErrorValue = some(message)
      field.touchWidgetState()
      result.needsRender = true
      result.events.add WidgetEvent(kind: validationFailed, source: field.id,
        validationMessage: message)
      return
    if field.clearValidationError():
      field.touchWidgetState()
      result.needsRender = true
    result.events.add WidgetEvent(kind: submitted, source: field.id,
      text: field.valueText)
  else:
    return

method afterAllocation*(field: TextField) =
  field.adjustHorizontalOffset()
