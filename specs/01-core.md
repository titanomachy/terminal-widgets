# 01 — Core architecture and API contracts

Traceability: Phase 01; shared foundation for all controls.

## Module responsibilities

| Proposed module under `src/terminal_widgets/` | Responsibility |
| --- | --- |
| `types.nim` | IDs, geometry, event payloads, dispatch/render result types |
| `widget.nim` | Base widget, ownership, validation, shared properties |
| `composition.nim` | Containers, measurement/allocation, tree operations |
| `focus.nim` | Traversal order, focus changes and repair |
| `dispatch.nim` | Route one input; collect ordered output events |
| `selection.nim` | Shared keyed options, active item and viewport logic |
| `checkbox.nim`, `switch.nim`, `radio_group.nim` | Boolean and exclusive choices |
| `scroll_list.nim`, `menu.nim`, `tabs.nim` | Collection and page controls |
| `editor.nim`, `text_field.nim` | Pure text editing and field behavior |
| `theme.nim`, `render.nim` | Semantic styles, sanitization and frame composition |
| `runtime.nim` | Explicit application loop and terminal ownership |
| `terminal_screen_adapter.nim` | TerminalScreen I/O implementation |

The facade exports core types, constructors, composition, dispatch and rendering.
It does not import `runtime`. Use `terminal_screen/types` for normalized input;
only the adapter imports sessions/platform functionality. Break cycles by keeping
base types and result records below concrete controls. No global widget registry,
global focus state, background thread, or terminal access during import.

## Data model

- `WidgetId` and `ItemId` are distinct string types. Constructors reject empty IDs.
  Widget IDs are unique within a tree; item IDs are unique within a control.
- `Widget` is a retained `ref object of RootObj`. Concrete controls derive from it.
  Mutable fields are private; getters return values/snapshots, not mutable aliases.
  Application references identify the same widget; this is intentional shared
  identity, not implicit deep copying.
- Parent ownership is tracked by IDs in the tree controller, avoiding reference
  cycles under ARC. One widget belongs to at most one parent and one tree.
  Reject duplicate attachment, cycles and conflicting IDs before mutation.
- `Rect(x, y, width, height)` uses zero-based integer cells. Dimensions must be
  nonnegative; local allocation positions are nonnegative. Zero space is valid.
  Check arithmetic overflow when summing/extending rectangles.
- Common properties: ID, visible (default true), enabled (true), label (empty),
  optional help text. Hidden/disabled ancestors suppress descendant interaction.
  Constructors/setters validate before changing state and raise `ValueError`
  for invalid caller input. Ordinary cancellation is not an exception.

## API shape to finalize in Phase 01

```nim
# Proposed signatures, not runnable until implementation exists.
proc newCheckbox(id: WidgetId; label: string; checked = false): Checkbox
proc newSwitch(id: WidgetId; label: string; on = false): Switch
proc newRadioGroup(id: WidgetId; items: seq[ChoiceItem];
                   selected: Option[ItemId] = none(ItemId)): RadioGroup
proc newScrollList(id: WidgetId; items: seq[ChoiceItem]): ScrollList
proc newMenu(id: WidgetId; items: seq[ChoiceItem]): Menu
proc newTabs(id: WidgetId; pages: seq[TabPage]): Tabs
proc newTextField(id: WidgetId; label = ""; value = ""): TextField
proc newWidgetTree(root: Widget): WidgetTree
proc layout(tree: WidgetTree; size: Size): DispatchResult
proc dispatch(tree: WidgetTree; input: InputEvent): DispatchResult
proc render(tree: WidgetTree; size: Size; theme: WidgetTheme): Frame
```

`ChoiceItem` contains `id`, plain `label`, and `enabled`; business payloads stay
in application maps keyed by `ItemId`. `TabPage` contains a keyed labeled header,
enabled flag and retained child root. Provide constructors for row/column/stack,
choice items and pages, plus checked/on/selected/value getters and setters.
Use `Option[ItemId]` for absent selection, never an invalid sentinel index.

`DispatchResult` contains `handled`, `needsRender`, and `events: seq[WidgetEvent]`.
`WidgetEvent` is a tagged variant with source ID and one of:

| Kind | Payload |
| --- | --- |
| `boolChanged` | New boolean value |
| `selectionChanged` | Optional selected item ID |
| `textChanged` | New text value |
| `activated` | Item ID |
| `submitted` | Field text |
| `validationFailed` | Plain validation message |
| `focusChanged` | Previous and new optional widget IDs |

Widget state is authoritative. Emit one change event only when a user operation
actually changes its value. Programmatic setters invalidate rendering and repair
invariants but do not synthesize user change/action events. Focus repair outputs
are returned by tree mutation operations in the same result shape. Initial focus
selection is silent. No inline callback can mutate the tree halfway through a
dispatch; application event handlers run afterward in sequence.

Use a rendering revision/dirty flag that setters update. Render remains a read-only
operation; the runtime tracks the last presented revision rather than clearing
dirty state during rendering. Tree mutation/layout recalculation occurs outside
rendering, with an explicit layout operation when viewport size changes.
`Size` holds nonnegative width/height in cells. Call `layout` after structural or
visibility changes and before rendering a new viewport; it returns any focus
repair events. `render` rejects a size that differs from the latest allocation or
a tree with stale layout, rather than silently mutating allocations. Value-only
changes such as toggling a checkbox need redraw but do not invalidate layout.

## Acceptance

Compile all public constructor signatures and typed event handling through the
facade. Test invalid IDs, duplicate children, cycle attempts and failed setters
leave state unchanged. Repeated render calls must produce identical frames and
preserve state/revision. Two independent trees must not share focus or values.
