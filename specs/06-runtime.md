# 06 — Interactive runtime and terminal ownership

Traceability: Phase 08. Import explicitly with `terminal_widgets/runtime`.

## Runtime API and backend

Entry points: `runWidgets(tree, options, onEvents, onTimeout): RunResult` for an
owned session, and an overload accepting a caller-owned `TerminalSession` plus
the matching borrowed output stream. The supplied output must be the session's
actual output; TerminalScreen exposes no public output getter in the inspected
version. Make this precondition explicit. `RunResult` distinguishes requested
stop, cancellation and EOF. Application event handlers return continue/stop and
may update the tree after dispatch returns. Exceptions remain exceptions.
All entry points, including `runWidgetsWithBackend`, append the optional
`RuntimeTimeoutHandler = proc(): RunAction {.closure.}` as `onTimeout = nil`
after existing arguments, preserving positional and named callsites.

Use an injected backend with operations for capabilities, initial size, reading
one `InputEvent`, presenting a frame, and acquiring/releasing runtime modes.
The default implementation uses TerminalScreen. A scripted backend provides
events, sizes and captured output without a TTY, and can inject failures at every
acquisition/presentation/cleanup step. Keep OS conditionals out of widgets.

Reuse `InputEvent` kinds `eventKey`, `eventResize`, `eventTimeout`, and
`eventEndOfInput`, and TerminalScreen's `readEvent`, `capabilities`, `openSession`,
`close`, geometry and public cursor helpers. Do not assume mouse/paste events or
other APIs exist in TerminalScreen 0.1.1. Text batches are ordinary key events;
bracketed-paste protocol support is deferred.

## Lifecycle

Owned path: validate options/tree; open one TerminalScreen session requiring a
terminal; verify ANSI/raw capabilities; obtain geometry; enter alternate screen;
hide cursor; layout and draw; run loop; restore styling/cursor/main screen; close
the owned session. Request `hideCursor = false` from TerminalScreen because the
Widgets presentation layer manages caret visibility itself. Track each acquired
mode so partial failure releases only what was acquired. Register cleanup before
attempting a mode write, since a write can fail after partially reaching the TTY.

The inspected TerminalScreen 0.1.1 API does not own alternate-screen entry/exit.
Keep the paired ANSI enter/leave sequences in the runtime adapter and explain
their ownership. No global session nesting or private TerminalScreen API access.

Borrowed path: never open or close the supplied session. Require an open session
with the documented interactive capabilities and a caller-established raw mode.
Default to caller-owned screen/cursor presentation: do not enter/leave alternate
screen or change cursor visibility. The caller explicitly opts into runtime mode
ownership only when starting from the normal screen with a visible cursor; then
the runtime restores that stated baseline. Do not pretend arbitrary prior terminal
modes can be queried or reconstructed. Caller-owned presentation can render a
software caret instead of changing hardware cursor state.

All cleanup stages are attempted on normal stop, handled Ctrl+C, EOF and
exceptions. Preserve an original application/I/O exception if cleanup also fails,
and attach/report cleanup failures without replacing it. With no primary error,
raise a cleanup failure after attempting all restoration stages. Cleanup is
idempotent. Restoration after uncatchable process termination is outside the
guarantee; document this alongside the supported normal/exception paths.

## Loop and output

Dispatch one event, then deliver its output events in order, apply application
updates, repair focus/layout as needed, and redraw once if revision/size changed.
Timeout events never dispatch or directly invoke `onEvents`. If supplied,
`onTimeout` runs once per actual timeout on the runtime thread and may mutate
state/focus or stop. Apply the same stamp/focus reconciliation and at most one
redraw; no-op callbacks stay idle. Layout/focus repair events may invoke
`onEvents` with the original timeout input. A stop skips further reads and the
final redraw, while exceptions use the normal cleanup/primary-error contract.
The hook is idle-only: continuous input can suppress it, with no periodic-timer
or catch-up guarantee. Add no sleeps, threads, or independent redraw loop.
Use a positive bounded poll timeout,
default 50 ms; reject invalid intervals. Ctrl+C returns cancelled before control
dispatch; EOF returns end-of-input without retrying. Escape reaches the application
as an unhandled key and does not quit by default. Other unhandled keys are exposed
to the application through the callback context, not silently discarded.

Resize retains widget state, updates viewport, repairs focus, and forces a full
redraw. On unavailable initial geometry use the explicit options fallback, default
80×24, without retry loops. Write rows with absolute cursor positioning, avoid
trailing newline at the bottom edge, and flush once per frame. Prevent bottom-right
autowrap from scrolling the frame, using a tested terminal strategy; if a wrap mode
is changed, include it in the same ownership/restoration contract. Reset styles
and place/show a valid hardware caret only in runtime-owned cursor mode.

The interactive runner rejects redirected/unsupported streams with
`TerminalUnavailableError` before any output or persistent mode change. Close an
owned session if capability validation fails. It does not reinterpret a widget
tree as sequential prompts. Applications can call pure `render` in plain mode to
produce one static snapshot for pipes/files; no session is needed for that path.

## Acceptance

Use backend operation logs to verify exact acquisition/restoration order, one
close for owned sessions, zero close for borrowed sessions, and no screen/cursor
mode changes in caller-owned mode. Inject failures during open, entry, first frame,
read, callback, validator, redraw and each cleanup action. Check original error
preservation. Test EOF, Ctrl+C, unknown keys, resize, fallback geometry, timeout
idle behavior and noninteractive rejection without ANSI output. Script timeout
callbacks to verify counts, batched updates, focus changes and repairs, no-op
frames, stop-before-redraw, and cleanup after exceptions in all ownership modes.

Add real PTY coverage on POSIX and appropriate Windows console coverage for raw
mode and cursor/screen restoration. Record manual terminal checks where automation
cannot observe a mode. Never claim Windows/macOS support from Linux-only tests.
