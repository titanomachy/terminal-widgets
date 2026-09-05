## Injectable runtime backend and the TerminalScreen-backed implementation.
##
## TerminalScreen 0.1.1 does not own alternate-screen or autowrap modes, so
## this adapter pairs those ANSI acquisitions and restorations explicitly.

import std/options
import terminal_screen
import terminal_style
import terminal_widgets/render

const
  EnterAlternateScreen* = "\e[?1049h"
  LeaveAlternateScreen* = "\e[?1049l"
  DisableAutoWrap* = "\e[?7l"
  EnableAutoWrap* = "\e[?7h"

type RuntimeBackend* = ref object of RootObj
  ## Operation boundary used by the runtime and deterministic scripted tests.

method openOwned*(backend: RuntimeBackend) {.base.} = discard
method capabilities*(backend: RuntimeBackend): TerminalCapabilities {.base.} =
  raise newException(TerminalStateError, "runtime backend has no capabilities")
method initialSize*(backend: RuntimeBackend): Option[TerminalSize] {.base.} =
  none(TerminalSize)
method enterAlternateScreen*(backend: RuntimeBackend) {.base.} = discard
method hideCursor*(backend: RuntimeBackend) {.base.} = discard
method disableAutoWrap*(backend: RuntimeBackend) {.base.} = discard
method present*(backend: RuntimeBackend; frame: Frame;
                ownsCursor: bool) {.base.} = discard
method readInput*(backend: RuntimeBackend; timeoutMs: int): InputEvent {.base.} =
  timeoutInput()
method resetStyles*(backend: RuntimeBackend) {.base.} = discard
method enableAutoWrap*(backend: RuntimeBackend) {.base.} = discard
method showCursor*(backend: RuntimeBackend) {.base.} = discard
method leaveAlternateScreen*(backend: RuntimeBackend) {.base.} = discard
method closeOwned*(backend: RuntimeBackend) {.base.} = discard

type TerminalScreenBackend* = ref object of RuntimeBackend
  session: TerminalSession
  output: File
  owned: bool

proc newOwnedTerminalBackend*(output: File = stdout): TerminalScreenBackend =
  ## Creates an unopened backend. ``openOwned`` acquires its session.
  TerminalScreenBackend(output: output, owned: true)

proc newBorrowedTerminalBackend*(session: TerminalSession;
                                 output: File): TerminalScreenBackend =
  ## Adapts an open caller-owned session and its exact matching output stream.
  ## TerminalScreen exposes no output getter, so callers must uphold that match.
  if session.isNil or not session.isOpen:
    raise newException(TerminalStateError,
      "borrowed TerminalScreen session must be open")
  TerminalScreenBackend(session: session, output: output, owned: false)

proc writeControl(backend: TerminalScreenBackend; value: string) =
  try:
    backend.output.write(value)
    backend.output.flushFile()
  except CatchableError as error:
    raise newException(TerminalIOError, error.msg)

method openOwned*(backend: TerminalScreenBackend) =
  if not backend.owned:
    raise newException(TerminalStateError,
      "cannot open a borrowed TerminalScreen backend")
  var options = defaultSessionOptions()
  options.hideCursor = false
  options.requireTerminal = true
  backend.session = openSession(output = backend.output, options = options)

method capabilities*(backend: TerminalScreenBackend): TerminalCapabilities =
  if backend.session.isNil or not backend.session.isOpen:
    raise newException(TerminalStateError, "TerminalScreen session is not open")
  backend.session.capabilities

method initialSize*(backend: TerminalScreenBackend): Option[TerminalSize] =
  backend.output.tryTerminalSize()

method enterAlternateScreen*(backend: TerminalScreenBackend) =
  backend.writeControl(EnterAlternateScreen)

method hideCursor*(backend: TerminalScreenBackend) =
  backend.writeControl(HideCursorCode)

method disableAutoWrap*(backend: TerminalScreenBackend) =
  backend.writeControl(DisableAutoWrap)

method present*(backend: TerminalScreenBackend; frame: Frame;
                ownsCursor: bool) =
  ## Writes a complete frame with absolute positioning and one final flush.
  ## With autowrap ownership the bottom-right cell cannot scroll. In borrowed
  ## caller-owned mode it is written last; a later absolute move clears the
  ## terminal's pending-wrap state without a trailing newline.
  try:
    for row, value in frame.rows:
      backend.output.write(cursorPositionCode(1, row + 1))
      backend.output.write(value)
    if ownsCursor:
      if frame.cursor.isSome:
        let cursor = frame.cursor.get
        backend.output.write(cursorPositionCode(cursor.column + 1,
          cursor.row + 1))
        backend.output.write(ShowCursorCode)
      else:
        backend.output.write(HideCursorCode)
    backend.output.flushFile()
  except CatchableError as error:
    raise newException(TerminalIOError, error.msg)

method readInput*(backend: TerminalScreenBackend; timeoutMs: int): InputEvent =
  backend.session.readEvent(timeoutMs)

method resetStyles*(backend: TerminalScreenBackend) =
  backend.writeControl(ansiReset)

method enableAutoWrap*(backend: TerminalScreenBackend) =
  backend.writeControl(EnableAutoWrap)

method showCursor*(backend: TerminalScreenBackend) =
  backend.writeControl(ShowCursorCode)

method leaveAlternateScreen*(backend: TerminalScreenBackend) =
  backend.writeControl(LeaveAlternateScreen)

method closeOwned*(backend: TerminalScreenBackend) =
  if backend.owned and not backend.session.isNil:
    backend.session.close()
