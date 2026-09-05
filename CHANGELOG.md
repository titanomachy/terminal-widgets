# Changelog

All notable changes to TerminalWidgets are documented in this file.

## Unreleased

### Rendering and themes

- Added exact-size pure `Frame` rendering with zero-based optional cursor
  metadata, ancestor clipping, wide-glyph-safe cell windows, opaque stack
  compositing, and deterministic full-frame output.
- Expanded semantic themes with placeholder, error, and accent styles; measured
  ASCII/Unicode control markers; and an escape-free plain mode.
- Added shared malformed-UTF-8/control sanitization plus plain and explicitly
  trusted-SGR static text widgets that strip non-SGR terminal protocols.
- Added a runnable pure frame example and regression coverage for stale layouts,
  marker validation, style closure, unsafe content, and overlapping widgets.
- Added complete plain golden states for every control, one-cell and large resize
  coverage, explicit non-color disabled markers, and a dependency-free static
  companion-output example.

### Text fields

- Added UTF-8-safe single-line editing with byte cursors constrained to the
  documented combining/emoji/ZWJ/regional-indicator cluster policy.
- Added cell-aware cursor movement, cluster deletion, scalar-count `maxRunes`,
  placeholders, read-only fields, and atomic rejection of unsafe/oversized
  insertions.
- Added Enter-time validators with sanitized `validationFailed` feedback,
  explicit `submitted` events, and retained validation-error state.
- Added horizontal viewport offsets, frame-local cursor metadata, semantic text
  windows, Unicode boundary tests, and a runnable headless editing example.
- Added acceptance coverage for tiny resized viewports, validation focus
  retention, exact Unicode state across tab-page round trips, and a facade-only
  validated form example.

### Tabs

- Added enabled keyed-header navigation, one-row page layout, cell-aware header
  offsets, immediate active-page focus integration, and selection events.
- Preserved retained editor values, list selections, and scroll offsets across
  tab changes, with a runnable multi-state example.
- Added atomic detached and tree-managed page replacement with stable-key
  reorder preservation, positional fallback, ownership updates, and focus repair.
- Added clipped semantic tab headers plus coverage for empty, all-disabled,
  narrow, removed, reordered, foreign-owned, and nested tab compositions.

### Lists and menus

- Added shared stable-key selection, disabled-item navigation, page movement,
  viewport offsets, and replacement reconciliation for lists and menus.
- Added list selection events and distinct repeatable menu activation events.
- Added dispatcher-level selection tests and a runnable navigation example.
- Added visible-slice list/menu control rendering and observable render metrics;
  a 100,000-item regression proves a five-row viewport visits only five items.
- Expanded the example with application-owned payload lookup by `ItemId`.

### Basic controls

- Added Space/Enter activation and stable ASCII markers for checkboxes and
  switches, with one Boolean event per user transition.
- Added radio active-item navigation across enabled choices, explicit selection,
  and transition-only selection events.
- Added dispatcher-level tests and a runnable headless basic-controls example.
- Added atomic radio-item replacement with stable-key reconciliation and
  deterministic plain/styled semantic control frames using TerminalStyle.
- Covered disabled and empty controls, boundary navigation, repeat activation,
  replacement fallback, and exact plain/ANSI snapshots.

### Composition and focus

- Added row, column, and stack allocation with saturating padding/gaps and
  deterministic fixed/weighted-flex sizing.
- Added stored cell allocations, depth-first per-tree focus order, focus repair,
  explicit focus requests, and wrapping Tab/Backtab traversal.
- Added focused input routing with single-delivery ancestor bubbling and resize
  layout handling, plus a runnable headless composition example.
- Added validated attach, detach, and atomic move operations with ownership
  release, retained widget state, allocation refresh, and focus repair.
- Added acceptance coverage for hidden/disabled/removed/moved focus, empty and
  zero-space trees, oversized padding, nested resize, and repeated layout state.

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
