# TerminalWidgets

Pure-Nim retained models for composable terminal controls: radio groups,
switches, tabs, checkboxes, menus, text fields, scrollable lists, and keyboard
focus handling. Applications own widget references and receive typed events;
importing `terminal_widgets` performs no terminal I/O.

The public data model is available now. Layout, keyboard dispatch, rendering,
and the opt-in interactive runtime are being added in the later phases recorded
in [`implementation guide`](implementation guide).

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

Text field values must be valid UTF-8 single-line text without terminal control
characters. Full cursor editing, validation callbacks, and limits belong to the
text-editing phase.

### Keyed controls and composition

`ChoiceItem` and `TabPage` keep labels separate from stable `ItemId` keys.
Duplicate item/page IDs and selections targeting missing or disabled choices are
rejected. Collection getters return independent sequence storage, while widget
references intentionally preserve identity.

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

## Examples

The repository includes these runnable examples:

- [`examples/core_model.nim`](examples/core_model.nim) constructs and updates a
  retained preferences tree using only the facade.
- [`examples/composition_focus.nim`](examples/composition_focus.nim) demonstrates
  fixed/flex layout, stored allocations, and focus traversal without terminal I/O.
- [`examples/package_import.nim`](examples/package_import.nim) verifies that a
  facade import does not initialize a terminal session.

Examples currently exercise a side-effect-free model and do not render a visual
terminal UI, so no terminal screenshot or animated recording is applicable yet.

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
