# 03 — Control behavior

Traceability: Phases 03–05. All controls follow core validation, private state,
event, focus and clipping contracts. State changes require effective enablement.
All labels are plain text and pass through the common renderer sanitization.

## Checkbox and switch

Checkbox stores `checked: bool`; switch stores `on: bool`. Space or Enter toggles
the value once and returns `boolChanged`. Repeating a programmatic setter with
the same value does not invalidate the frame. Disabled controls never toggle.
Plain/default ASCII markers are `[ ]`/`[x]` and `[off]`/`[on]`; themes may replace
them with measured glyphs. Focus has a visible marker even with color disabled.
No tri-state checkbox in the first release.

Acceptance: both activation keys, unhandled arrows, repeated toggles, disabled and
hidden ancestors, clipped labels, and value retention after focus round trips.

## Shared keyed selection rules

Radio, list, and menu share an ordered `ChoiceItem` sequence with unique IDs.
Default active item is the first enabled item; it is absent if none are enabled.
Navigation skips disabled items and clamps at boundaries (no wrapping). Home/End
choose first/last enabled. Replacing items preserves selected/active IDs when
still enabled; otherwise search from the old index forward, then backward, for
an enabled replacement. No enabled replacement produces `none`. Reordering keeps
identity; labels are never keys. Explicitly selecting a missing/disabled ID raises
`ValueError`; clearing a selection with `none` is valid where selection is optional.

## Radio group

Display a vertical exclusive-choice group. Track active navigation separately
from selected value, allowing initial `none`. Up/Down and Home/End move active
choice without changing selection. Space or Enter selects the active choice and
emits `selectionChanged` only if the selected ID differs. Re-activation is a no-op.
Programmatic selected-ID updates align active ID with the new selection; clearing
selection preserves an eligible active choice. Mark active and selected states
separately. Long groups use the shared viewport model.

Acceptance: no selection, single option, all disabled, navigation over disabled
gaps, option replacement, retained choice, and exactly one selected marker.

## Scrollable list and menu

A scrollable list is single-select: the active ID is also its selected ID.
Up/Down, Home/End and PageUp/PageDown move selection and emit `selectionChanged`.
Enter/Space are unhandled by the list. A menu uses the same navigation and change
events, and Enter emits `activated` with the active item ID, even when selection
did not just change. Space is unhandled by menus. Keep navigation and activation
distinct so merely moving through a menu cannot execute application actions.

Each item occupies one row; multiline labels are sanitized to one line. Store
`topIndex` as an index into all items, including disabled rows. Viewport height is
the allocated content height. Keep the active row visible by minimal scrolling,
clamp `topIndex` after resize/replacement, and render only intersecting rows.
Page movement targets active index ± max(1, viewport height), then finds an enabled
item in the movement direction; clamp to the first/last enabled item at the edge.
Zero-height controls render no rows and are not focusable. Show an inert empty
state when no items exist and space is available. Scroll markers, if shown, reserve
their cell before label clipping and never consume another item row.

Rendering must visit O(visible rows), not all 100,000 items. O(n) replacement and
scanning through disabled runs are acceptable and must be documented honestly.

Acceptance: page movement, disabled runs, end-of-list viewport, shrinking height,
reorder with stable IDs, deletion of active item, empty input, zero-height viewport,
and two Enter presses producing two menu activations without duplicate changes.

## Tabs

Tabs own ordered `TabPage` values with unique item IDs and retained child trees.
The first enabled page is initially active. While the header is focused,
Left/Right and Home/End choose enabled tabs with clamped navigation and emit
`selectionChanged`; selection activates the page immediately. Enter/Space are
no-ops. Tab moves from the header into the active page's first eligible child.
While a child is focused, arrows belong to that child and do not switch tabs.

Render a one-row header above the active page. Scroll headers horizontally to keep
the active header visible, clipping a header wider than the viewport by cells.
Inactive pages are omitted from layout/focus/render but retain model state.
Changing/removing an active page repairs descendant focus by the composition
rules. With no enabled tab, no page is active and the header is not focusable.
Replacing/reordering pages preserves the selected page ID when possible using
the shared replacement fallback. Page children must satisfy normal tree uniqueness.

Acceptance: switch away/back with modified field/list state, disabled headers,
reordering, active page removal, tiny widths, no pages, and nested tabs. Verify
hidden page controls never receive dispatch and do not render stale content.
