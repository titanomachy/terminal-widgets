# Runtime ownership and cleanup

The runtime is opt-in:

```nim
import terminal_widgets
import terminal_widgets/runtime
```

The facade alone is side-effect-free.
`runWidgets(tree, options, onEvents, onTimeout)` is the guarded owned-session
entry point demonstrated by [form.nim](../examples/form.nim).
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
callback failure, validator failure, and partial initialization. This includes
assertion and indexing defects that unwind the stack. Cleanup runs in `finally`,
and a failure in one restoration does not prevent the remaining steps. Process
termination that prevents stack unwinding, including defects compiled with
`--panics:on`, is outside the cleanup guarantee.

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
to 80×24 and must be positive. Without `onTimeout`, timeout events do no work.
Resize lays out and presents; Ctrl+C returns `cancelled`; EOF returns
`endOfInput` without retrying.
Escape and other unhandled keys reach `RuntimeEventHandler`, which may return
`stopRunning` to produce `requestedStop`.

The callback receives input only after widget dispatch has produced its ordered
events. If the callback mutates retained state, the runtime lays out and presents
once before the next poll. This also applies to resize callbacks: applications
can hide controls or switch tab pages to fit the new viewport, and their updated
layout is used for presentation. Focus-repair events caused by that layout are
delivered in a second callback context for the same input.

Calling `requestFocus` in a callback also redraws the focus marker and cursor
before the next input is read, even when no widget value changes. For example,
a submission handler can focus the next field without leaving the displayed
cursor on the previous one. Requesting the current focus does not trigger an
extra frame.

## Idle updates

All three entry points accept `onTimeout: RuntimeTimeoutHandler = nil` as their
last optional argument. `RuntimeTimeoutHandler` is a closure with signature
`proc(): RunAction`. Existing positional and named calls retain their meaning,
including `ownedSession` and `ownPresentation` in `runWidgetsWithBackend`.
The owned and borrowed `runWidgets` overloads forward it to that same loop.

When `readInput(options.pollTimeoutMs)` returns `eventTimeout`, the runtime calls
`onTimeout` exactly once, synchronously on the runtime thread. The timeout never
enters widget dispatch and does not by itself call `onEvents`. The callback may
change widgets, change focus, or return `stopRunning`.

The runtime checks widget stamps and focus using the same reconciliation as
`onEvents`: changed state triggers layout and focus repair, then at most one
frame before the next input. Multiple widget changes are batched into that
frame. A no-op callback or a request for the current focus does not redraw.
Programmatic setters do not generate user value-change events. If layout
produces focus-repair events, `onEvents` receives those events with
`context.input.kind == eventTimeout`; this is a repair notification rather than
primary delivery of idle input. The repair handler may also request a stop.

Returning `stopRunning` yields `requestedStop` immediately, without reading
another input or presenting a final frame, even if the callback changed state.
Callback exceptions propagate after all applicable cleanup steps; the primary
exception is preserved if cleanup also fails. Owned and borrowed session and
presentation rules remain the same.

`pollTimeoutMs` is the input wait, not a guaranteed update interval. Continuous
input may prevent timeouts entirely. There are no catch-up ticks, additional
sleeps, worker threads, or separate redraw loops. Keep callbacks short: perform
long work outside the event loop and safely collect completed results here.
For time-based decisions, use a monotonic clock in an application update function.
If updates must also run while input keeps arriving, call that function from
`onEvents` as well. A general timer/scheduler is outside this API.

```nim
import terminal_widgets
import terminal_widgets/runtime

let status = newStaticText(newWidgetId("status"), "Updates: 0")
let tree = newWidgetTree(status)
var updates = 0
var options = defaultRuntimeOptions()
options.pollTimeoutMs = 250

discard runWidgets(tree, options = options,
  onTimeout = proc(): RunAction =
    if updates == 4:
      return stopRunning
    inc updates
    status.setContent("Updates: " & $updates)
    continueRunning)
```

The fourth update is rendered; the next timeout stops without a final redraw.
[idle_updates.nim](../examples/idle_updates.nim) adds Escape handling and can be
compiled with `nim c --path:src examples/idle_updates.nim`.

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
