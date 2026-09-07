## Shared defensive UTF-8 decoding and single-line text sanitization.
##
## Widget labels and other renderer inputs may be malformed or contain terminal
## protocols. This module keeps their replacement policy consistent anywhere
## text is measured, rendered, stored as feedback, or emitted in an event.

import std/unicode

proc isControlScalar*(scalar: int): bool {.inline.} =
  scalar <= 0x1f or scalar == 0x7f or scalar in 0x80 .. 0x9f

proc isUnsafeTextScalar*(scalar: int): bool {.inline.} =
  isControlScalar(scalar) or scalar in [0x2028, 0x2029]

proc decodeUtf8(value: string; start: int; scalar, byteWidth: var int): bool =
  if start < 0 or start >= value.len: return false
  let first = ord(value[start])
  template continuation(index: int): int = ord(value[index])
  template validContinuation(index: int): bool =
    index < value.len and continuation(index) in 0x80 .. 0xbf
  if first <= 0x7f:
    scalar = first; byteWidth = 1; return true
  if first in 0xc2 .. 0xdf and validContinuation(start + 1):
    scalar = (first and 0x1f) shl 6 or (continuation(start + 1) and 0x3f)
    byteWidth = 2; return true
  if first in 0xe0 .. 0xef and validContinuation(start + 1) and
      validContinuation(start + 2):
    let second = continuation(start + 1)
    if (first == 0xe0 and second < 0xa0) or
        (first == 0xed and second > 0x9f): return false
    scalar = (first and 0x0f) shl 12 or (second and 0x3f) shl 6 or
      (continuation(start + 2) and 0x3f)
    byteWidth = 3; return true
  if first in 0xf0 .. 0xf4 and validContinuation(start + 1) and
      validContinuation(start + 2) and validContinuation(start + 3):
    let second = continuation(start + 1)
    if (first == 0xf0 and second < 0x90) or
        (first == 0xf4 and second > 0x8f): return false
    scalar = (first and 0x07) shl 18 or (second and 0x3f) shl 12 or
      (continuation(start + 2) and 0x3f) shl 6 or
      (continuation(start + 3) and 0x3f)
    byteWidth = 4; return true
  false

proc sanitizePlainText*(value: string): string =
  ## Replaces malformed UTF-8 and unsafe single-line controls with safe text.
  var index = 0
  var hasBase = false
  while index < value.len:
    var scalar, byteWidth: int
    if not decodeUtf8(value, index, scalar, byteWidth):
      result.add "\xef\xbf\xbd"
      hasBase = true
      inc index
      continue
    if isUnsafeTextScalar(scalar):
      result.add ' '
      hasBase = true
    else:
      let rune = Rune(scalar)
      if unicode.isCombining(rune) and not hasBase:
        result.add "◌"
      result.add value[index ..< index + byteWidth]
      if not unicode.isCombining(rune): hasBase = true
    index += byteWidth
