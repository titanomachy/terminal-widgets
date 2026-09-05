import std/[options, unittest]
import terminal_widgets
import terminal_widgets/widget

type
  RoutingProbe = ref object of Widget
    calls: int
    consume: bool
    child: Widget

proc newProbe(id: string; consume = false; child: Widget = nil): RoutingProbe =
  new result
  result.initializeWidgetState(newWidgetId(id), id)
  result.consume = consume
  result.child = child

method canFocus(probe: RoutingProbe): bool = probe.child.isNil

method childWidgets(probe: RoutingProbe): seq[Widget] =
  if not probe.child.isNil: @[probe.child] else: @[]

method handleInput(probe: RoutingProbe; input: InputEvent): DispatchResult =
  inc probe.calls
  dispatchResult(handled = probe.consume)

suite "composition layout, focus, and routing":
  test "row allocation applies padding gaps fixed sizes and flex weights":
    let first = newCheckbox(newWidgetId("first"), "First")
    let second = newCheckbox(newWidgetId("second"), "Second")
    let third = newCheckbox(newWidgetId("third"), "Third")
    let row = newRow(newWidgetId("row"),
      [Widget(first), Widget(second), Widget(third)])
    row.setGap(1)
    row.setSizing(first.id, fixed(3))
    row.setSizing(second.id, flex(1))
    row.setSizing(third.id, flex(2))
    let tree = newWidgetTree(row)

    discard tree.layout(newSize(10, 2))
    check first.allocation == some(newRect(0, 0, 3, 2))
    check second.allocation == some(newRect(4, 0, 2, 2))
    check third.allocation == some(newRect(7, 0, 3, 2))

  test "column padding and stack allocations stay within content bounds":
    let back = newCheckbox(newWidgetId("back"), "Back")
    let front = newTextField(newWidgetId("front"))
    let stack = newStack(newWidgetId("stack"), [Widget(back), Widget(front)])
    stack.setPadding(newPadding(1, 2, 1, 2))
    let tree = newWidgetTree(stack)

    discard tree.layout(newSize(8, 4))
    check back.allocation == some(newRect(2, 1, 4, 2))
    check front.allocation == back.allocation

  test "focus order is depth first and tab traversal wraps":
    let first = newCheckbox(newWidgetId("first"), "First")
    let hidden = newCheckbox(newWidgetId("hidden"), "Hidden")
    hidden.setVisible(false)
    let last = newTextField(newWidgetId("last"))
    let root = newColumn(newWidgetId("root"),
      [Widget(first), Widget(hidden), Widget(last)])
    let tree = newWidgetTree(root)
    discard tree.layout(newSize(20, 3))

    check tree.focusOrder == @[first.id, last.id]
    check tree.focused == some(first.id)
    let forward = tree.dispatch(keyInput(keyTab))
    check forward.handled
    check tree.focused == some(last.id)
    check forward.events.len == 1
    discard tree.dispatch(keyInput(keyTab))
    check tree.focused == some(first.id)
    discard tree.dispatch(keyInput(keyBacktab))
    check tree.focused == some(last.id)

  test "unhandled input bubbles once through ancestors":
    let leaf = newProbe("leaf")
    let parent = newProbe("parent", consume = true, child = leaf)
    let tree = newWidgetTree(parent)
    discard tree.layout(newSize(5, 1))

    let outcome = tree.dispatch(keyInput(keyArrowRight))
    check outcome.handled
    check leaf.calls == 1
    check parent.calls == 1
