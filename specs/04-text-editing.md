# 04 — Single-line text editing

Traceability: Phase 06. The editor is independent of terminal I/O and of
TerminalPrompt's private editor implementation.

## State and encoding

Store valid UTF-8 text, a byte-offset cursor constrained to an editing boundary,
and a horizontal cell offset. Expose text through getters/setters; cursor position
and viewport are controlled by validated editor operations. Initial/setter values
with invalid UTF-8, C0/C1 controls (including ESC, CR, LF, and Tab), or DEL are
rejected with `ValueError`. User insertion containing any such content is rejected
as a whole without changing state. This keeps fields single-line and prevents
terminal control injection. `keySpace` inserts an ordinary space.

First-release editing boundaries cover a Unicode scalar plus following combining
marks/variation selectors/emoji modifiers, ZWJ-linked sequences, and pairs of
regional indicators. Never split UTF-8 or one of these supported clusters on
Left/Right, Backspace or Delete. This is an explicitly bounded cluster policy,
not a claim of full UAX #29 conformance. Use Nim Unicode primitives and a small
tested local boundary helper; do not copy TerminalStyle's private tokenizer.
If full segmentation is later required, propose a shared public foundation API
before adding a dependency or changing this contract.

## Behavior

| Input | Action |
| --- | --- |
| `keyText`, `keySpace` without Ctrl/Alt | Insert text at cursor |
| Left / Right | Move by one supported editing cluster |
| Home / End | Move to start / end |
| Backspace / Delete | Delete preceding / following cluster |
| Enter | Validate and submit current value |
| Tab / Backtab | Leave to focus manager; never insert a tab |
| Escape, unknown or unsupported modified keys | Return unhandled |

Navigation clamps at either end. Cursor movement requests rendering but does not
emit `textChanged`. Successful insertion/deletion emits exactly one text change
event. A read-only field stays focusable, permits navigation and submission, and
ignores editing keys. Disabled fields are excluded from focus.

`maxRunes` is a positive scalar-count limit, default 4096, applied to initial
values, setters and insertion results. Reject an insertion atomically if it
exceeds the limit; do not truncate halfway through a cluster. The name and docs
must make clear that the limit counts scalars, not bytes or screen cells.
Placeholder is displayed only for an empty value and is never inserted/submitted.

A validator has the proposed signature `proc(value: string): Option[string]`.
`none` means valid; `some(message)` means invalid. Invoke on Enter, not on every
keystroke. Invalid submission emits `validationFailed`, retains focus/value and
stores a sanitized error message for rendering. A later edit or setter clears
the old error. Valid submission emits `submitted`, leaving text/focus intact.
Validator exceptions propagate to the application/runtime cleanup path. Document
that validators must not mutate the tree during dispatch.

## Viewport and acceptance

Measure with TerminalStyle's public cell-width helpers. Reserve marker/label cells
first; scroll minimally so the cursor fits in the remaining field width. At End,
allow one blank cell for the caret; if there is no visible content cell, return no
cursor metadata. Never crop half a wide glyph. Report the cursor in frame-local
zero-based cells; the runtime converts coordinates at its boundary.

Test empty/ASCII/CJK text, `e` plus combining accent, emoji modifier, ZWJ family,
regional-indicator pair, invalid UTF-8, lone combining marks, limit boundaries,
whole rejected multi-character insertion, and control-byte rejection. Test failed
validation, validator exceptions, read-only mode, one-cell fields, cursor movement
after resize, and exact text restoration after tab/page/focus round trips.
