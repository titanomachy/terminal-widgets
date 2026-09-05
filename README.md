# TerminalWidgets

Pure-Nim retained models for composable terminal controls: radio groups,
switches, tabs, checkboxes, menus, text fields, scrollable lists, and keyboard
focus handling. Applications own widget references and receive typed events;
importing `terminal_widgets` performs no terminal I/O.

The public model, layout, keyboard dispatch, single-line text editing, and pure
full-frame rendering are available now. The opt-in interactive runtime remains
a later phase recorded in [`implementation guide`](implementation guide).

## Platform support

The package and its side-effect-free model tests have been verified on Linux
with Nim 2.0.x and current stable Nim. Windows and macOS verification is planned
before release. Terminal-specific support will be documented with the runtime.

## Requirements

- Nim 2.0.0 or newer
- [`terminal_style`](https://github.com/titanomachy/terminal-style) 0.1.1 or newer
- [`terminal_screen`](https://github.com/titanomachy/terminal-screen) 0.1.1 or newer

## TerminalDeck

TerminalWidgets is the retained interaction library in TerminalDeck:

```text
TerminalDeck
├── Foundations
│   ├── TerminalStyle
│   └── TerminalScreen
├── Output components
│   ├── TerminalStatus
│   ├── TerminalLayout
│   ├── TerminalTable
│   └── TerminalGraph
└── Interaction
    ├── TerminalPrompt
    └── TerminalWidgets <- this package
```

## Contents

- [Installation](#installation)
- [Quick start](#quick-start)
- [API overview](#api-overview)
  - [IDs and geometry](#ids-and-geometry)
  - [Retained widget state](#retained-widget-state)
  - [Keyed controls and composition](#keyed-controls-and-composition)
  - [Layout and focus routing](#layout-and-focus-routing)
  - [Frames, themes, and static text](#frames-themes-and-static-text)
  - [Input and output events](#input-and-output-events)
- [Examples](#examples)
- [Development and documentation](#development-and-documentation)
- [Attribution and license](#attribution-and-license)

## Installation

During development, install directly from GitHub with Nimble:

```sh
nimble install https://github.com/titanomachy/terminal-widgets
```

Then import the public facade:

```nim
import terminal_widgets
```

The facade re-exports normalized input types from TerminalScreen's types-only
module. It does not import session or platform code.

## Quick start

Create retained controls, update them through validated setters, and compose
their stable references into a tree:

```nim
import std/options
import terminal_widgets

let notifications = newCheckbox(
  newWidgetId("notifications"),
  "Send notifications"
)
notifications.setChecked(true)

let density = newRadioGroup(
  newWidgetId("density"),
  [
    newChoiceItem(newItemId("comfortable"), "Comfortable"),
    newChoiceItem(newItemId("compact"), "Compact")
  ],
  selected = some(newItemId("comfortable"))
)

let root = newColumn(newWidgetId("preferences"),
  [Widget(notifications), Widget(density)])
let tree = newWidgetTree(root)

echo tree.root.id
echo notifications.checked
```

Run the complete example with:

```sh
nim r --path:src examples/core_model.nim
```

## API overview

| Area | Main API | Contract |
| --- | --- | --- |
| [IDs and geometry](#ids-and-geometry) | `WidgetId`, `ItemId`, `Rect`, `Size` | Validated stable IDs and nonnegative cell geometry |
| [Retained widget state](#retained-widget-state) | `Widget`, common getters/setters, `revision` | Private mutable state; same-value setters do not revise |
| [Keyed controls and composition](#keyed-controls-and-composition) | control constructors, `ChoiceItem`, `TabPage`, row/column/stack, `WidgetTree` | Stable application keys, snapshot collections, retained widget identity |
| [Text editing](#text-editing) | `TextField`, `TextValidator`, `editingBoundaries` | UTF-8 cluster-safe editing, scalar limits, validation, cell viewport |
| [Frames and themes](#frames-themes-and-static-text) | `Frame`, `CursorCell`, `WidgetTheme`, `StaticText`, `render` | Pure exact-size compositing, safe clipping, semantic styles, optional cursor |
| [Input and output events](#input-and-output-events) | `InputEvent`, `WidgetEvent`, `DispatchResult` | Normalized input and ordered typed application output |

### IDs and geometry

Use `newWidgetId` and `newItemId` for nonempty IDs. The two distinct types stop
widget and item identities from being mixed accidentally. Every public control
constructor validates its ID again, including values created with an explicit
distinct-type conversion.

`newRect(x, y, width, height)` accepts zero-based positions and nonnegative
dimensions, including zero space, and rejects overflowing extents. `newSize`
likewise accepts nonnegative viewport dimensions.

### Retained widget state

All controls derive from `Widget`. Common getters expose `id`, `visible`,
`enabled`, `label`, optional `helpText`, and `revision`. Setters validate before
mutation and increment the revision only when a value changes. Programmatic
setters do not synthesize user events.

Control-specific state currently includes:

- `checked` / `setChecked` for `Checkbox`
- `isOn` / `setOn` for `Switch`
- `selected` / `setSelected` for `RadioGroup`
- `selected` for `ScrollList` and `active` for `Menu` and `Tabs`
- `value` / `setValue` for `TextField`

Checkboxes and switches toggle on Space or Enter and expose stable plain markers
(`[ ]`/`[x]` and `[off]`/`[on]`). Radio groups keep an `active` navigation item
separate from the optional `selected` value: Up/Down and Home/End move across
enabled choices, while Space or Enter selects the active choice. User value
transitions return exactly one typed event; programmatic setters return none.
`renderControl` produces deterministic semantic lines for these controls with
either `plainWidgetTheme()` or styled `defaultWidgetTheme()` output. `render`
composes those controls into a clipped full-tree frame.

Scrollable lists and menus share stable `ChoiceItem` navigation and a `topIndex`
viewport offset. Up/Down, Home/End, and PageUp/PageDown skip disabled items and
keep the active row visible. List movement changes `selected`; menu movement
changes `active`, while only Enter emits an `activated` menu event. `setItems`
preserves enabled IDs across reorder/rename and otherwise chooses the specified
forward-then-backward fallback. Application payloads remain in maps keyed by
`ItemId`.
`visibleItems` and `renderControl` inspect only the allocated slice. For
performance verification, the `RenderMetrics.visitedItems` overload reports the
number of rows visited; rendering five rows from a 100,000-item fixture visits
exactly five items. Replacement remains O(n), while steady rendering is
O(visible rows).

Tabs retain keyed page roots and reserve one allocated row for their header.
Left/Right and Home/End move among enabled headers; the active page alone enters
layout and depth-first focus traversal. Header scrolling is measured in display
cells and keeps the active header start visible when a single label is wider
than the viewport. `renderControl` returns the clipped one-row semantic header;
plain output uses brackets for the active page and parentheses for disabled
pages. Inactive page widgets keep editor values, selections, and scroll offsets
across tab changes.

### Text editing

`newTextField` accepts a valid UTF-8 value and optional `placeholder`, positive
`maxRunes` (default `4096` Unicode scalars), `readOnly` flag, and
`TextValidator`. Values and inserted text reject malformed UTF-8, C0/C1
controls, and DEL atomically. The byte-offset `cursorByte` always rests on a
bounded editing cluster boundary; Left/Right, Backspace, and Delete keep
combining marks, variation selectors, emoji modifiers, ZWJ sequences, and
regional-indicator pairs together. `Home` and `End` clamp to the value edges.

`keyText` and `keySpace` insert when Ctrl/Alt are absent. Successful edits emit
one `textChanged` event; navigation only requests rendering. Read-only fields
remain focusable and can navigate or submit, while editing keys are ignored.
Tab and Backtab are left for the tree focus manager. `maxRunes` counts scalars,
not UTF-8 bytes, graphemes, or terminal cells, and an insertion that would
exceed it is rejected without truncation.

Enter invokes the optional validator exactly once. Return `none(string)` to
emit `submitted`; return `some(message)` to emit `validationFailed` and expose a
sanitized `validationError` without changing focus or text. Validator exceptions
propagate to the caller's runtime cleanup path. Validators must not mutate the
widget tree while dispatch is in progress. A later successful edit or setter
clears the old error. The placeholder is shown only while the value is empty and
is never submitted.

After layout, `contentWidth` reserves marker/label cells. `horizontalOffset`
scrolls in terminal cells just enough to keep the cursor visible, leaving one
blank caret cell at End when possible. `cursorCell` is an optional frame-local
zero-based column and is absent when the field has no visible content cell.
`visibleText(width)` uses TerminalStyle's cell-aware clipping and never splits a
wide glyph. The public `editingBoundaries` helper documents the deliberately
bounded segmentation policy used by the field.

### Keyed controls and composition

`ChoiceItem` and `TabPage` keep labels separate from stable `ItemId` keys.
Duplicate item/page IDs and selections targeting missing or disabled choices are
rejected. Collection getters return independent sequence storage, while widget
references intentionally preserve identity.

Use `setPages` to replace or reorder pages while tabs are detached. Once tabs
belong to a tree, call `replacePages(tree, tabs.id, pages)`: it preserves an
enabled active ID when possible, otherwise searches from the old position
forward and then backward. Removed page roots release ownership, newly added
roots are validated atomically, and focus is repaired if its page disappears.

`newRow`, `newColumn`, and `newStack` create retained containers. Detached
containers may replace their children atomically with `setChildren`; duplicate
references, duplicate widget IDs, cycles, and already-owned widgets are rejected
without changing the container. `newWidgetTree` validates the complete graph and
takes exclusive ownership. Tree-managed structural mutation, allocation, and
focus handling are part of the next implementation categories.

### Input and output events

TerminalScreen's `InputEvent`, `KeyEvent`, `Key`, and modifier types are
available from the facade. `WidgetEvent` is a tagged object with a source
`WidgetId` and exactly one payload selected by its kind:

| Kind | Payload |
| --- | --- |
| `boolChanged` | New Boolean value |
| `selectionChanged` | Optional selected `ItemId` |
| `textChanged` | New text |
| `activated` | Activated `ItemId` |
| `submitted` | Submitted field text |
| `validationFailed` | Plain validation message |
| `focusChanged` | Previous and new optional `WidgetId` values |

`DispatchResult` carries `handled`, `needsRender`, and an ordered event sequence.
Actual routing and event emission are introduced with focus and control behavior.

### Layout and focus routing

Rows and columns allocate visible children along their main axis; stacks give
each visible child the same content rectangle. Configure nonnegative padding and
gaps with `setPadding` and `setGap`, and set direct children to `fixed(cells)` or
positive `flex(weight)` sizing with `setSizing`. Calling `layout(tree, size)`
stores clipped cell allocations without querying the terminal.

Each tree owns an independent depth-first focus order. Eligible controls must be
effectively visible, enabled, and allocated nonzero space. `requestFocus` rejects
ineligible IDs atomically. `dispatch` handles Tab and Backtab with wrapping,
routes other normalized input to the focused widget, and bubbles unhandled input
through its ancestors. Concrete control key behavior is introduced in the
control-specific phases.

Use `detach(tree, id)` to remove a non-root subtree and release its tree
ownership, `attach(tree, parentId, widget)` to add a validated detached subtree,
and `move(tree, id, newParentId)` to reparent an owned subtree atomically. These
operations retain widget objects and values and repair focus against the latest
layout size.

### Frames, themes, and static text

Call `layout(tree, size)` and then `render(tree, size, theme)` to produce a pure
`Frame` with exactly `height` rows of display width `width`. A focused visible
text field may set the optional zero-based `CursorCell`; frame rows never contain
cursor movement or erase commands. Rendering rejects a mismatched or detectably
stale layout, performs no terminal I/O, and does not mutate widget revisions.

`plainWidgetTheme()` emits no ANSI escapes. `defaultWidgetTheme()` uses semantic
normal, focused, disabled, selected, placeholder, error, and accent styles with
ASCII markers; `unicodeWidgetTheme()` opts into Unicode markers. Custom markers
are measured by terminal cells and must be printable, single-line, positive-width
text. Labels, items, placeholders, and errors are treated as untrusted plain text:
malformed UTF-8 becomes U+FFFD and terminal controls become spaces.

`newStaticText` safely composes ordinary application or companion-library string
output without adding that library as a dependency. Use the explicitly named
`newTrustedStyledText` only for content that may retain SGR styling; the renderer
still strips OSC, cursor, erase, and other terminal protocols. Wide glyphs are
never cut in half, later stack children overwrite their complete rectangles, and
all output rows close generated styles. Full-frame presentation is the baseline;
diff rendering is intentionally deferred until measurement justifies it.

```nim
let size = newSize(24, 2)
discard tree.layout(size)
let frame = tree.render(size, plainWidgetTheme())
for row in frame.rows:
  echo row
```

Run the complete example with:

```sh
nim r --path:src examples/render_frame.nim
```

## Examples

The repository includes these runnable examples:

- [`examples/core_model.nim`](examples/core_model.nim) constructs and updates a
  retained preferences tree using only the facade.
- [`examples/composition_focus.nim`](examples/composition_focus.nim) demonstrates
  fixed/flex layout, stored allocations, and focus traversal without terminal I/O.
- [`examples/basic_controls.nim`](examples/basic_controls.nim) drives checkbox,
  switch, and radio state through the public dispatcher and prints final values.
- [`examples/selection_navigation.nim`](examples/selection_navigation.nim)
  demonstrates shared list/menu navigation and explicit menu activation.
- [`examples/tabs_retained.nim`](examples/tabs_retained.nim) switches between
  three retained pages, prints a semantic header, and demonstrates preserved
  state plus tree-managed page removal and reordering.
- [`examples/text_field_editing.nim`](examples/text_field_editing.nim) exercises
  Unicode-safe insertion/deletion, a scalar limit, placeholder text, and
  validator/submission events without opening a terminal.
- [`examples/validated_form.nim`](examples/validated_form.nim) composes two
  validated fields, reports failed and successful submissions, and moves focus
  through the form using only the public facade.
- [`examples/render_frame.nim`](examples/render_frame.nim) lays out a small form,
  renders an exact-size plain frame, and reports its optional cursor metadata.
- [`examples/companion_output.nim`](examples/companion_output.nim) places static
  graph-like string output in a frame without adding a companion dependency.
- [`examples/package_import.nim`](examples/package_import.nim) verifies that a
  facade import does not initialize a terminal session.

Examples currently exercise a side-effect-free model and pure frame data; they
do not run a visual terminal session, so no terminal screenshot or animated
recording is applicable yet.

## Development and documentation

Repository builds are contained in `build/`: executables go to `build/bin`,
compiler caches use a Nim-version and project-specific directory below
`build/nimcache`, generated API documentation goes to `build/docs`, and test
fixtures belong in `build/tmp`.

Run the focused public-model suite with:

```sh
nim c -r --path:src tests/test_core_model.nim
```

Run all package checks with:

```sh
nimble check
nimble compilePackage
nimble test
nimble examples
nimble docs
nimble releaseCheck
```

Command-line `--out` and `--nimcache` overrides take precedence over
`config.nims`; project automation must keep any such paths below `build/`.

## Attribution and license

Copyright (c) 2026 titanomachy. TerminalWidgets is released under the
[MIT License](LICENSE).
