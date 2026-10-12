# TerminalWidgets 0.2.0 release notes

TerminalWidgets 0.2.0 adds an optional runtime idle callback for application
updates while waiting for input. Existing positional and named calls remain
compatible; dependency requirements are unchanged.

## New idle callback

- `RuntimeTimeoutHandler = proc(): RunAction {.closure.}` is available from
  `terminal_widgets/runtime`. Supply it as the final optional `onTimeout`
  argument to either `runWidgets` overload or `runWidgetsWithBackend`.
- The callback runs synchronously once per actual input timeout. It may update
  widgets, request focus, or return `stopRunning` to exit with `requestedStop`.
- Changes share the existing layout, focus repair, and single-frame redraw path.
  No-op callbacks do not redraw. Timeouts never dispatch to widgets or directly
  call `onEvents`; layout/focus repair events can call `onEvents` with the
  original timeout input.
- Stopping skips further input reads and the final redraw. Exceptions propagate
  after cleanup, preserving the primary failure if terminal restoration fails.
  Owned and borrowed session rules remain unchanged.
- `pollTimeoutMs` controls the input wait, not a periodic timer. Continuous input
  may prevent idle callbacks; there are no catch-up ticks. Keep handlers short.
  If updates must also run during continuous input, call the same application
  update function from `onEvents`.

See [the runtime guide](docs/runtime.md#idle-updates) for the full contract and
[idle_updates.nim](examples/idle_updates.nim) for a complete status example with
Escape and Ctrl+C handling:

```console
nim r --path:src examples/idle_updates.nim
```

## Requirements and verification

- Nim 2.0.0+, TerminalStyle 0.1.1+, and TerminalScreen 0.1.1+.
- `nimble releaseCheck -y` validates package metadata, the facade, all 16 test
  suites, isolated package installation, all examples, the headless form,
  the 100,000-item benchmark, and generated API documentation.
- `nimble testArc -y` and `nimble testOrc -y` run the complete suite under ARC
  and ORC.
- Local Linux amd64 validation passed with Nim 2.2.12: the full release check
  and complete ARC and ORC suites. The 28 runtime tests also passed with
  Nim 2.0.4 under ORC. New timeout tests use scripted input without real sleeps.
- The isolated consumer compiles old and new positional/named runtime calls.
- GitHub Actions checks Nim 2.0.x and stable on Linux, macOS, and Windows,
  plus stable-Linux ARC and ORC jobs. The real terminal restoration smoke runs
  on Linux; other platforms run deterministic injected runtime tests.

## Known limits

- The idle callback does not guarantee periodic updates under continuous input.
- Text editing uses the documented bounded cluster policy, not full UAX #29.
- Rendering presents complete frames; no diff renderer is exposed.
- Disabled-item navigation scans remain linear in the affected item range.
- Cleanup requires stack unwinding. Forced process termination and defects
  compiled with `--panics:on` cannot run language-level restoration.
- Borrowed presentation ownership requires the documented normal-screen,
  visible-cursor, autowrap-enabled baseline.
