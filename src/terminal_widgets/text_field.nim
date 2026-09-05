## Persistent, single-line UTF-8 text field.
##
## Text editing is independent from terminal I/O. The field stores a byte
## cursor at a bounded editing boundary, a cell-based horizontal viewport, and
## typed submission/validation outcomes returned by ``WidgetTree.dispatch``.

import std/[options, unicode]
import terminal_style
import terminal_widgets/[editor, types, widget]

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
  scalar <= 0x1f or scalar == 0x7f or scalar in 0x80 .. 0x9f

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

proc markerCells(field: TextField): int {.inline.} =
  ## The semantic field renderer reserves one marker and one separator cell.
  2

proc labelCells(field: TextField): int {.inline.} =
  if field.label.len == 0: 0 else: displayWidth(field.label) + 2

proc contentStartCells*(field: TextField): int =
  ## Number of frame cells reserved before field content.
  field.markerCells + field.labelCells

proc contentWidth*(field: TextField): int =
  ## Width left for value/placeholder after marker and label cells.
  if field.allocation.isNone:
    return 0
  max(0, field.allocation.get.width - field.contentStartCells)

proc cursorValueCells(field: TextField): int {.inline.} =
  if field.cursorByteValue == 0:
    return 0
  displayWidth(field.valueText[0 ..< field.cursorByteValue])

proc totalValueCells(field: TextField): int {.inline.} =
  displayWidth(field.valueText)

proc adjustHorizontalOffset(field: TextField) =
  let viewport = field.contentWidth
  if viewport <= 0:
    field.horizontalOffsetValue = 0
    return
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
  field.horizontalOffsetValue = offset

proc decodeUtf8(value: string; start: int; scalar, width: var int): bool =
  ## Small defensive decoder used only while sanitizing validator messages.
  ## Field values themselves have already passed ``validateUtf8``.
  if start < 0 or start >= value.len:
    return false
  let first = ord(value[start])
  template continuation(index: int): int = ord(value[index])
  template validContinuation(index: int): bool =
    index < value.len and continuation(index) in 0x80 .. 0xbf
  if first <= 0x7f:
    scalar = first
    width = 1
    return true
  if first in 0xc2 .. 0xdf and validContinuation(start + 1):
    scalar = (first and 0x1f) shl 6 or (continuation(start + 1) and 0x3f)
    width = 2
    return true
  if first in 0xe0 .. 0xef and validContinuation(start + 1) and
      validContinuation(start + 2):
    let second = continuation(start + 1)
    if (first == 0xe0 and second < 0xa0) or
        (first == 0xed and second > 0x9f):
      return false
    scalar = (first and 0x0f) shl 12 or
      (second and 0x3f) shl 6 or (continuation(start + 2) and 0x3f)
    width = 3
    return true
  if first in 0xf0 .. 0xf4 and validContinuation(start + 1) and
      validContinuation(start + 2) and validContinuation(start + 3):
    let second = continuation(start + 1)
    if (first == 0xf0 and second < 0x90) or
        (first == 0xf4 and second > 0x8f):
      return false
    scalar = (first and 0x07) shl 18 or
      (second and 0x3f) shl 12 or
      (continuation(start + 2) and 0x3f) shl 6 or
      (continuation(start + 3) and 0x3f)
    width = 4
    return true
  false

proc sanitizeValidationMessage(value: string): string =
  ## Keeps validator feedback printable and single-line, replacing malformed
  ## bytes and terminal/line control characters with safe text.
  var index = 0
  while index < value.len:
    var scalar, width: int
    if not decodeUtf8(value, index, scalar, width):
      result.add "\xef\xbf\xbd"
      inc index
      continue
    if hasUnsafeScalar(scalar) or scalar == 0x2028 or scalar == 0x2029:
      result.add ' '
    else:
      result.add value[index ..< index + width]
    index += width

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
proc viewportOffset*(field: TextField): int = field.horizontalOffsetValue
proc maxRunes*(field: TextField): int = field.maxRunesValue
proc placeholder*(field: TextField): string = field.placeholderValue
proc readOnly*(field: TextField): bool = field.readOnlyValue
proc validator*(field: TextField): TextValidator = field.validatorValue
proc validationError*(field: TextField): Option[string] =
  field.validationErrorValue

proc cursorCell*(field: TextField): Option[int] =
  ## Returns the frame-local zero-based cursor column when a content cell is
  ## visible. The runtime adds its frame origin when addressing the terminal.
  let bounds = field.allocation
  let viewport = field.contentWidth
  if bounds.isNone or bounds.get.width <= 0 or bounds.get.height <= 0 or
      viewport <= 0:
    return none(int)
  field.adjustHorizontalOffset()
  let local = field.contentStartCells + field.cursorValueCells -
    field.horizontalOffsetValue
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
      let message = sanitizeValidationMessage(validation.get)
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
