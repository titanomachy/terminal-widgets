# Runtime ownership and cleanup

The runtime is opt-in:

```nim
import terminal_widgets
import terminal_widgets/runtime
```

The facade alone is side-effect-free. `runWidgets(tree, options, onEvents)` is the
guarded owned-session entry point demonstrated by [form.nim](../examples/form.nim).
It requires interactive input/output, ANSI, and raw-mode support.

## Owned sessions

The owned overload performs this transaction:

1. Validate options and open TerminalScreen.
2. Verify input/output/raw/ANSI capabilities and determine terminal size.
3. Enter the alternate screen, hide the cursor, and disable autowrap.
4. Layout and present one complete frame.
5. Poll input with a positive bounded timeout, dispatch, deliver events, and
   redraw only for resize or dirty application/model state.
6. Reset styles, enable autowrap, show the cursor, leave the alternate screen,
   and close the session.

Each restoration is registered before its acquisition write. Every applicable
cleanup step is attempted after normal callback stop, Ctrl+C, EOF, read/write or
callback failure, validator failure, and partial initialization. An uncatchable
process termination cannot run language-level cleanup and is outside the
guarantee.

The adapter writes full frames with absolute cursor positioning and no trailing
newline. Autowrap ownership prevents the bottom-right cell from scrolling.

## Borrowed sessions

The borrowed overload accepts an already-open `TerminalSession` and the exact
matching output `File`. TerminalScreen 0.1.1 exposes no output getter, so matching
them is a caller precondition. TerminalWidgets never opens or closes a borrowed
session.

By default the caller also owns screen, cursor, and autowrap state. Set
`ownBorrowedPresentation = true` only when the known starting baseline is the
normal screen, visible cursor, and enabled autowrap; the runtime then restores
that stated baseline. It cannot infer or restore arbitrary pre-existing modes.

## Input and termination

`pollTimeoutMs` defaults to 50 and must be in `1..60000`. `fallbackSize` defaults
to 80×24 and must be positive. Timeout events do no work; resize lays out and
presents; Ctrl+C returns `cancelled`; EOF returns `endOfInput` without retrying.
Escape and other unhandled keys reach `RuntimeEventHandler`, which may return
`stopRunning` to produce `requestedStop`.

The callback receives input only after widget dispatch has produced its ordered
events. If the callback mutates retained state, the runtime lays out and presents
once before the next poll. Focus-repair events caused by that layout are delivered
in a second callback context for the same input.

## Failures and evidence

Unsupported or redirected streams raise `TerminalUnavailableError` before ANSI
presentation. If primary work and cleanup both fail, the original exception is
re-raised with cleanup details appended. If cleanup alone fails after all stages
are attempted, `TerminalStateError` is raised.

The injected backend test covers every acquisition, presentation, read, callback,
validator, and cleanup failure. A Linux PTY smoke observes paired alternate-screen,
cursor, autowrap, and reset sequences from the actual TerminalScreen adapter.
See the runtime smoke record and
verification evidence for exact scope and commands.

When embedding static output from another TerminalDeck library, obtain its string
without letting it own the terminal, place it in `newStaticText` (or explicitly
trusted SGR-only `newTrustedStyledText`), and let this runtime remain the single
terminal owner. [companion_output.nim](../examples/companion_output.nim) shows the
pure composition path.
