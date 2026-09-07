# TerminalWidgets 0.1.0 release notes

TerminalWidgets 0.1.0 is the first release candidate of the pure-Nim retained
terminal interaction library in TerminalDeck.

## Highlights

- Retained checkbox, switch, radio, list, menu, tabs, text-field, static-text,
  row, column, and stack models with stable IDs and typed events.
- Depth-first focus, fixed/flex layout, structural mutation, retained tab state,
  and cell-aware full-frame rendering with semantic ASCII/Unicode themes.
- Bounded Unicode editing clusters, horizontal text scrolling, scalar limits,
  validation, and explicit submit events.
- Opt-in owned and borrowed TerminalScreen runtimes with transactional mode
  acquisition, full cleanup attempts, and original-error preservation.
- Deterministic examples/tests, seeded robustness sequences, operation-counted
  100,000-item rendering, an isolated installed-package consumer, and generated
  API documentation.

## Compatibility evidence

- Requires Nim 2.0.0+, TerminalStyle 0.1.1+, and TerminalScreen 0.1.1+.
- Local release checks pass on Linux amd64 with Nim 2.0.4 and 2.2.10.
- Stable Linux ARC and ORC suites pass locally.
- CI is configured for Nim 2.0.x and stable on Linux, macOS, and Windows. Hosted
  macOS/Windows results are not claimed by the local evidence.
- The real terminal restoration smoke is Linux-only; non-Linux environments run
  the deterministic injected runtime suite.

## Known limits

- Text editing uses the documented bounded cluster policy, not full UAX #29.
- Rendering presents complete frames; no diff renderer is exposed.
- Disabled-item navigation scans are O(distance scanned).
- Language-level cleanup cannot run after uncatchable process termination.
- Borrowed presentation ownership requires the documented normal-screen,
  visible-cursor, autowrap-enabled baseline.

## Verification

Run `nimble releaseCheck -y`. Exact commands and local evidence are recorded in
release records and
verification records.

The repository owner remains responsible for reviewing hosted CI, selecting the
final version, creating any tag, and publishing the package. This work does not
perform those external release actions.
