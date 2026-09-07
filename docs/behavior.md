# Behavior contracts

## Fixed key bindings

| Component | Keys | Result |
| --- | --- | --- |
| Tree | Tab / Backtab | Move forward/backward through eligible focus IDs with wrapping |
| Checkbox, switch | Space / Enter | Toggle once and emit `boolChanged` on transition |
| Radio group | Up/Down, Home/End | Move active item across enabled choices |
| Radio group | Space / Enter | Select active item and emit `selectionChanged` on transition |
| Scroll list | Up/Down, Home/End, PageUp/PageDown | Move selection and keep it visible |
| Menu | Up/Down, Home/End, PageUp/PageDown | Move active item and keep it visible |
| Menu | Enter | Emit `activated`, including on repeated presses |
| Tabs | Left/Right, Home/End | Activate enabled pages |
| Text field | Left/Right, Home/End | Move the editing cursor |
| Text field | Backspace/Delete | Remove one supported editing cluster |
| Text field | Unmodified `keyText` / Space | Insert atomically at the cursor |
| Text field | Enter | Run validator and emit `submitted` or `validationFailed` |

Disabled or effectively hidden controls do not enter focus order. Lists leave
Space/Enter unhandled; tabs leave Space/Enter unhandled; ordinary controls leave
Escape unhandled. Ctrl+C and EOF are runtime termination inputs, not widget keys.
Unhandled input remains available to the runtime callback.

## State and ownership

Applications own references and business payloads; `WidgetTree` owns structural
membership and focus. Values survive repeated layout/render, focus movement, tab
changes, resize, reordering, and movement of retained widgets. Collection keys,
not labels or indices, preserve identity. Same-value setters do not increment
`revision`; setters do not emit user events.

Radio groups, lists, and menus clamp `topIndex` after navigation, selection,
replacement, and resize so their active row stays in the allocated viewport.
Their rendering cost is proportional to visible rows; replacement and scans
through disabled runs remain linear in the affected item range.

A widget can belong to only one tree. Duplicate references, duplicate widget or
item IDs, cycles, foreign-owned attachments, invalid selections, and invalid
geometry raise `ValueError` atomically. Detached widgets release tree ownership
and retain their application-visible state.

## Text and Unicode scope

Text-field values and insertions must be valid UTF-8 and contain no C0/C1 control
characters or DEL. Rejection is atomic. `maxRunes` counts Unicode scalars—not
bytes, graphemes, or display cells.

The first release deliberately implements a bounded editing-cluster policy: a
base scalar stays with following combining marks, variation selectors, and emoji
modifiers; ZWJ-linked segments stay together; regional indicators pair from the
start of the run. This is not full Unicode UAX #29 grapheme segmentation. Display
clipping is cell-aware and never emits half a wide glyph.

Rendering accepts broader untrusted strings and sanitizes rather than rejects:
malformed bytes become U+FFFD, controls become spaces, and an isolated combining
mark receives a dotted-circle base. Validator messages are sanitized before being
stored or emitted.

## Themes and plain output

Themes carry semantic normal, focused, disabled, selected, placeholder, error,
and accent styles plus state markers. Markers must be printable, single-line,
positive-width text. `plainWidgetTheme()` guarantees no ANSI escapes. The default
uses styled ASCII markers; the Unicode theme changes markers only. Full-frame
rendering is the correctness baseline; no diff renderer is currently exposed.

## Errors and validation

- `ValueError` reports invalid application input or an invalid runtime option.
- `TerminalUnavailableError` reports redirected/unsupported interactive streams
  before presentation output or persistent mode changes.
- `TerminalIOError` reports terminal reads/writes and presentation failures.
- `TerminalStateError` reports invalid session/backend state and cleanup-only
  failures.
- Validator and application callback exceptions propagate after runtime cleanup.

When a runtime operation fails, its original exception type and message remain
primary. Cleanup failures are appended as details rather than replacing it.
See [runtime.md](runtime.md) for the ordered cleanup contract.
