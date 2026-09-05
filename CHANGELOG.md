# Changelog

All notable changes to TerminalWidgets are documented in this file.

## Unreleased

### Composition and focus

- Added row, column, and stack allocation with saturating padding/gaps and
  deterministic fixed/weighted-flex sizing.
- Added stored cell allocations, depth-first per-tree focus order, focus repair,
  explicit focus requests, and wrapping Tab/Backtab traversal.
- Added focused input routing with single-delivery ancestor bubbling and resize
  layout handling, plus a runnable headless composition example.

### Core public model

- Added distinct validated widget/item IDs, overflow-safe cell geometry,
  normalized TerminalScreen input exports, typed widget events, and ordered
  dispatch results.
- Added the retained `Widget` base with private common state, optional help,
  transition-only revisions, and validated programmatic setters.
- Added public control, choice, tab page, container, and widget-tree
  constructors with snapshot collection getters and retained widget identity.
- Added facade-level public-model tests and a runnable retained preferences-tree
  example.
- Added atomic detached-container validation and exclusive tree ownership,
  rejecting duplicate attachments, conflicting IDs, and cycles before mutation.
- Added a facade-only black-box consumer check covering normalized input and all
  typed event variants without import or construction side effects.
- Named the switch getter `isOn` to avoid an `on` symbol collision with
  `std/unittest` on supported Nim 2.0.x compilers.

### Package setup

- Validated the `0.1.0` package metadata and minimum requirements for Nim 2.0.0,
  TerminalStyle 0.1.1, and TerminalScreen 0.1.1.
- Added the public facade and the source, test, support, and example structure
  defined by the architecture module map.
- Added package-layout coverage and an independently compilable facade example.

### Build containment

- Contained direct root and nested-directory Nim builds, Nimble tasks, generated
  API documentation, compiler caches, test fixtures, and command overrides under
  `build/`.
- Added an artifact-location regression suite covering compilation, execution,
  documentation helpers, source-tree integrity, versioned caches, and isolated
  concurrent-job paths.
- Documented the verified baseline commands and build-directory layout.
