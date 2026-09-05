# 02 — Composition, layout and focus

Traceability: Phase 02, 05.A.01.

## Layout

Implement row, column, and stack containers, explicit padding/gaps, and child
fixed-size or positive flex-weight constraints. Layout receives a viewport; it
never queries the terminal. Store allocations before rendering. Hidden children
receive no allocation. Stack children share the content rectangle and render in
insertion order; later children cover earlier ones. Stack is a visual primitive,
not an implicit modal focus trap.

Subtract padding and gaps with saturating nonnegative arithmetic. Allocate fixed
requests in insertion order, clipping each to remaining space. Divide remaining
space among flex children by integer weights; distribute leftover cells in
insertion order. Default children have flex weight 1. Cross-axis allocation fills
available space. Gaps exist only between visible children and are clipped to
remaining space. No child may render outside the ancestor intersection.
The first version needs no intrinsic/min-content sizing solver.

## Focus

Focus order is depth-first insertion order among effectively visible, enabled,
focusable controls with nonzero allocated area. Containers are not focusable.
Checkbox/switch/field are one stop each; radio/menu/list are one stop if they have
an enabled item; the tabs header is one stop if an enabled tab exists, followed
by focusable descendants of the active page. Inactive pages retain state but
do not receive keys or occupy focus order.

Initial focus is the first eligible node. Tab/Shift+Tab move forward/backward with
wrapping; with zero candidates focus is `none`, and with one candidate it stays
put without a duplicate focus event. Resize, removal, hiding, disabling and active
page changes repair focus: retain the focused ID if eligible; otherwise choose
the next eligible entry after its old traversal position, wrapping to the start.
If no previous position exists, choose the first eligible entry. Programmatic
focus requests reject ineligible IDs without partial mutation.

## Input routing and state

The tree handles Tab/Backtab before the control, then sends other keys to the
focused control. Unhandled keys bubble through ancestor handlers, then return
unhandled to the application. Do not deliver a consumed key twice. Ctrl+C and EOF
belong to the runtime; resize triggers layout/focus repair; timeouts never alter
controls by default. Escape is unhandled by ordinary controls for application
policy. Custom bindings are deferred; document the fixed first-release bindings.

Tree operations validate atomically. Reparenting is explicit detach then attach,
retaining the widget object and its state; state survives redraw, focus loss,
page switches and resize. Removing a widget releases tree ownership and does not
destroy an application's independent reference. Application callbacks may enqueue
tree changes after the current dispatch result has been returned.

## Acceptance

Cover nested rows/columns, all-zero viewport, padding larger than viewport, fixed
overflow, weighted rounding, overlapping stack order, and clipped wide glyphs.
Assert each effective widget ID appears at most once in focus traversal. Test
every focus repair trigger, tab wrapping, disabled ancestors, and inactive pages.
Use a scripted checkbox → field → menu sequence to verify that only the focused
control changes and business events preserve dispatch order.
