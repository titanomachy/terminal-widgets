# API guide

Import `terminal_widgets` for the retained model, composition, dispatch, and pure
rendering API. Import `terminal_widgets/runtime` separately when the application
intends to own or borrow a terminal session. Importing the facade and constructing
widgets perform no terminal I/O.

## Core values

| API | Purpose |
| --- | --- |
| `newWidgetId`, `newItemId` | Construct validated, nonempty distinct IDs |
| `newSize`, `newRect` | Construct nonnegative cell geometry |
| `WidgetEvent`, `WidgetEventKind` | Typed user-originated application events |
| `DispatchResult` | `handled`, `needsRender`, and ordered output events |

Invalid IDs, geometry, item/page selections, tree graphs, and setter inputs raise
`ValueError` before mutation. Programmatic setters update retained state and
revision counters but do not synthesize user events.

## Controls

| Component | Constructor | Retained value | User behavior |
| --- | --- | --- | --- |
| Checkbox | `newCheckbox` | `checked` / `setChecked` | Space or Enter toggles |
| Switch | `newSwitch` | `isOn` / `setOn` | Space or Enter toggles |
| Radio group | `newRadioGroup` | `active`, `selected` / `setSelected` | Navigate enabled choices; Space/Enter selects |
| Scroll list | `newScrollList` | `selected` / `setSelected`, `topIndex` | Navigation changes selection |
| Menu | `newMenu` | `active` / `setActive`, `topIndex` | Navigation changes active item; Enter activates |
| Tabs | `newTabs` | `active` / `setActive`, `headerOffset` | Horizontal navigation activates a page |
| Text field | `newTextField` | `value` / `setValue`, cursor and viewport | Single-line editing, validation, submission |
| Static text | `newStaticText` | `content` / `setContent` | Non-focusable sanitized content |

Choices and pages use stable `ItemId` keys. Their sequence getters return copied
storage; page child widgets intentionally retain object identity. Keep business
payloads in application maps keyed by `ItemId`.

Runnable, independently compilable examples are available for
[checkbox](../examples/checkbox.nim), [switch](../examples/switch.nim),
[radio group](../examples/radio_group.nim),
[scroll list](../examples/scroll_list.nim), [menu](../examples/menu.nim),
[tabs](../examples/tabs.nim), and [text field](../examples/text_field.nim).

## Composition and focus

`newRow`, `newColumn`, and `newStack` retain child references. Configure padding,
gap, and fixed/weighted-flex direct-child sizing before or after tree creation.
`newWidgetTree` validates the complete graph and takes exclusive ownership.

Call `layout(tree, size)` before `render`. A tree keeps one depth-first eligible
focus ID or none. `requestFocus` rejects an ineligible ID. `attach`, `detach`,
`move`, and `replacePages` validate atomically, update ownership, retain surviving
widget values, and repair focus using the last layout size.

`dispatch(tree, input)` handles Tab/Backtab traversal, sends other input to the
focused widget, and bubbles unhandled input through ancestors once. Applications
consume its typed event sequence in order.

## Rendering

`render(tree, size, theme)` returns a pure, exact-size `Frame` with rows and an
optional zero-based `CursorCell`. It performs no I/O and rejects mismatched or
detectably stale layouts. Use `plainWidgetTheme()` for escape-free output,
`defaultWidgetTheme()` for styled ASCII markers, or `unicodeWidgetTheme()` for
opt-in Unicode markers.

Ordinary labels and `newStaticText` content are untrusted plain text. The renderer
replaces malformed UTF-8 and controls, clips by display cells, does not split wide
glyphs, and closes generated row styles. `newTrustedStyledText` is the explicit
escape hatch for SGR-bearing content; OSC, cursor, erase, and other protocols are
still removed.

## Runtime

`runWidgets` returns a `RunResult` whose termination is `requestedStop`,
`cancelled`, or `endOfInput`, plus the number of frames presented. Its callback
receives each non-timeout input and ordered `DispatchResult`; return `stopRunning`
to exit normally. See [runtime.md](runtime.md) for terminal ownership and failure
contracts and [behavior.md](behavior.md) for fixed keys, Unicode scope, and errors.

Compiler-generated symbol documentation is produced only under `build/docs/`:

```console
nimble docs
```
