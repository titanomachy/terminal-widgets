# 05 — Frames, themes and clipping

Traceability: Phase 07 and all control snapshot tests.

## Frame contract

`Frame` contains exactly `height` rows, each of display width `width`, plus an
optional zero-based cursor cell. Zero width means empty row strings; zero height
means no rows and no cursor. Dimensions are explicit and nonnegative. Rendering
uses current allocations, state, and an explicit theme; it performs no I/O,
terminal query, focus repair, state mutation, or time/random sampling.

Use internal styled spans/cells or bounded row builders to compose frames. Do not
slice UTF-8 byte ranges as cell offsets or concatenate child strings without
ancestor clipping. Never draw half a wide glyph at a boundary: leave the clipped
cells blank. A combining mark must not attach to content from another widget;
render isolated marks with a safe base or replace them under a documented policy.
Treat later stack children as opaque within their allocated rectangle, including
blank cells. All rows are padded after clipping.

Use TerminalStyle's public `displayWidth`, `sliceAnsi`, `truncateAnsi` and `padAnsi`
as appropriate; `padAnsi` alone does not truncate. Close styles on each row and
prevent attributes from leaking to siblings or subsequent terminal output.
`Frame` rows contain presentation styling only, never cursor movement/erase codes.
Only the focused visible text field may contribute a cursor; a clipped cursor is
absent. A runtime full-frame write is the baseline; diff rendering is deferred
until correctness and a measured need justify it.

## Text and theme policy

All control labels, help, item text, placeholders and validation messages are
plain text, not trusted ANSI. Replace malformed UTF-8 with U+FFFD; replace controls
and line separators with spaces, and never emit raw ESC/C0/C1/DEL. Keep style
sequences exclusively in renderer-generated semantic spans. Text-field values
use the stricter input rejection policy in 04-text-editing.

Themes define normal, focused, disabled, selected, placeholder, error and accent
styles, plus control/focus/scroll markers. Include a default theme with ASCII
markers and optional Unicode markers; `useColor = false` produces no escape
sequences. No essential state is represented by color alone. Validate markers as
single-line printable strings with positive measured width. Recalculate clipping
using their actual width rather than assuming one byte or one cell.

Provide a static text widget for optional companion-library composition. Its
default input is plain text. An explicitly named trusted-styled-content constructor
may accept SGR styling only, strip other control protocols (including OSC), and
enforce normal clipping. Do not add TerminalLayout/Table/Graph/Status dependencies
merely to accept their string output; host applications own those imports.

## Acceptance

Golden frames for every control: normal, focused, selected, disabled, empty, error,
ASCII and color-disabled cases. Test 0×0, 1×1, large and resized viewports; CJK,
combining text, emoji and long labels; nested/overlapping clipping; malicious
cursor/OSC sequences in plain content; and styles ending at row boundaries.
Assert row count/cell width, safe cursor bounds, unchanged model revision, and
equal frames from repeated calls. Separate width-policy limitations inherited
from TerminalStyle from actual state/encoding defects.
