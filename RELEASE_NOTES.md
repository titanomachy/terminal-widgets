# TerminalWidgets 0.1.1 release notes

TerminalWidgets 0.1.1 fixes runtime cleanup, resize handling, and application
focus changes. The public API and dependency requirements are unchanged.

## Fixes

- Restore acquired terminal modes and close owned sessions after assertion or
  indexing defects that unwind the stack. Preserve the original exception when
  a cleanup operation also fails, and attempt every remaining restoration.
- Reconcile changes made in resize callbacks before rendering. Applications can
  hide controls or switch retained tab pages without terminating the runtime
  because of stale allocations; resulting focus-repair events are delivered.
- Redraw application-requested focus changes before reading the next input,
  even when widget values stay unchanged. Focus markers and text-field cursor
  positions now match the field that receives subsequent typing.
- Add regression coverage for these paths and fix an ARM64 crash in the
  validator cleanup test. Update the runtime guide, README, and changelog.

## Requirements and verification

- Nim 2.0.0+, TerminalStyle 0.1.1+, and TerminalScreen 0.1.1+.
- `nimble releaseCheck -y` validates package metadata, the facade, all 16 test
  suites, isolated package installation, examples, the headless form, the
  100,000-item benchmark, and generated API documentation.
- `nimble testArc -y` and `nimble testOrc -y` run the complete suite under ARC
  and ORC.
- Local Linux amd64 validation passed with Nim 2.2.12: the full release check
  and complete ARC and ORC suites.
- GitHub Actions checks Nim 2.0.x and stable on Linux, macOS, and Windows,
  plus stable-Linux ARC and ORC jobs.
- The real terminal restoration smoke runs on Linux. Other platforms run the
  deterministic injected runtime tests. The runtime suite also passes locally
  under ARM64 emulation with ARC and ORC.

## Known limits

- Text editing uses the documented bounded cluster policy, not full UAX #29.
- Rendering presents complete frames; no diff renderer is exposed.
- Disabled-item navigation scans remain linear in the affected item range.
- Cleanup requires stack unwinding. Forced process termination and defects
  compiled with `--panics:on` cannot run language-level restoration.
- Borrowed presentation ownership requires the documented normal-screen,
  visible-cursor, autowrap-enabled baseline.
