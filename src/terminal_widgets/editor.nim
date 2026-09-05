## Pure single-line text editing boundaries.
##
## The helper deliberately implements the bounded cluster policy promised by
## the text-field contract instead of claiming complete UAX #29 segmentation.
## It uses ``std/unicode`` for scalar decoding and keeps byte offsets in the
## original UTF-8 string so callers never split a code point accidentally.

import std/unicode

proc isVariationSelector(rune: Rune): bool {.inline.} =
  let scalar = int(rune)
  scalar in 0xfe00 .. 0xfe0f or scalar in 0xe0100 .. 0xe01ef

proc isEmojiModifier(rune: Rune): bool {.inline.} =
  let scalar = int(rune)
  scalar in 0x1f3fb .. 0x1f3ff

proc isRegionalIndicator(rune: Rune): bool {.inline.} =
  int(rune) in 0x1f1e6 .. 0x1f1ff

proc isExtend(rune: Rune): bool {.inline.} =
  ## Combining marks plus the selectors/modifiers omitted by std/unicode.
  unicode.isCombining(rune) or isVariationSelector(rune) or
    isEmojiModifier(rune)

proc clusterAfter(runes: openArray[Rune]; start: int): int =
  ## Returns the scalar index immediately after one supported editing cluster.
  let count = runes.len
  if start < 0 or start >= count:
    return start

  var index = start + 1
  if isRegionalIndicator(runes[start]) and index < count and
      isRegionalIndicator(runes[index]):
    return index + 1

  # A leading combining mark is intentionally allowed as its own cluster.
  # Consecutive marks/selectors still remain together so deletion cannot leave
  # a dangling selector or split a lone-mark run.
  while index < count and isExtend(runes[index]):
    inc index

  # Join a ZWJ and the following scalar, then fold its trailing marks. Repeating
  # the loop supports family/occupation sequences with multiple joiners.
  while index < count and int(runes[index]) == 0x200d:
    inc index
    if index >= count:
      break
    inc index
    while index < count and isExtend(runes[index]):
      inc index
  index

proc runeStarts(value: string; runes: seq[Rune]): seq[int] =
  result = newSeq[int](runes.len + 1)
  var byteOffset = 0
  for index in 0 ..< runes.len:
    result[index] = byteOffset
    byteOffset += runeLenAt(value, byteOffset)
  result[runes.len] = value.len

proc editingBoundaries*(value: string): seq[int] =
  ## Returns UTF-8 byte offsets at which a ``TextField`` cursor may rest.
  ##
  ## ``value`` must already be valid UTF-8. The public field constructor and
  ## setter enforce that precondition; callers using this low-level helper
  ## should do the same.
  let runes = toRunes(value)
  let starts = runeStarts(value, runes)
  result.add 0
  var index = 0
  while index < runes.len:
    index = clusterAfter(runes, index)
    result.add starts[index]

proc isEditingBoundary*(value: string; byteOffset: int): bool =
  ## Reports whether ``byteOffset`` is one of the supported cluster boundaries.
  if byteOffset < 0 or byteOffset > value.len:
    return false
  for boundary in editingBoundaries(value):
    if boundary == byteOffset:
      return true
  false

proc previousEditingBoundary*(value: string; byteOffset: int): int =
  ## Clamps to the boundary at or before ``byteOffset``.
  let boundaries = editingBoundaries(value)
  result = boundaries[0]
  for boundary in boundaries:
    if boundary > byteOffset:
      break
    result = boundary

proc nextEditingBoundary*(value: string; byteOffset: int): int =
  ## Clamps to the boundary at or after ``byteOffset``.
  let boundaries = editingBoundaries(value)
  result = boundaries[^1]
  for boundary in boundaries:
    if boundary >= byteOffset:
      return boundary

proc scalarCount*(value: string): int =
  ## Counts Unicode scalars, not UTF-8 bytes, graphemes, or terminal cells.
  toRunes(value).len
