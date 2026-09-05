import std/[options, unittest]
import terminal_widgets

suite "checkbox switch and radio controls":
  test "checkbox and switch activation toggle once and expose ASCII markers":
    let checkbox = newCheckbox(newWidgetId("checkbox"), "Checkbox")
    let switch = newSwitch(newWidgetId("switch"), "Switch")
    let root = newStack(newWidgetId("root"), [Widget(checkbox), Widget(switch)])
    let tree = newWidgetTree(root)
    discard tree.layout(newSize(20, 1))

    check checkbox.marker == "[ ]"
    let checked = tree.dispatch(keyInput(keySpace))
    check checked.handled and checked.needsRender
    check checkbox.checked and checkbox.marker == "[x]"
    check checked.events.len == 1
    check checked.events[0].kind == boolChanged
    check checked.events[0].boolValue

    discard tree.requestFocus(switch.id)
    let switched = tree.dispatch(keyInput(keyEnter))
    check switched.handled and switched.events.len == 1
    check switch.isOn and switch.marker == "[on]"
    check switched.events[0].kind == boolChanged

  test "radio navigation skips disabled choices and selection emits once":
    let group = newRadioGroup(newWidgetId("mode"), [
      newChoiceItem(newItemId("one"), "One"),
      newChoiceItem(newItemId("disabled"), "Disabled", enabled = false),
      newChoiceItem(newItemId("three"), "Three")
    ])
    let tree = newWidgetTree(group)
    discard tree.layout(newSize(20, 3))

    check group.active == some(newItemId("one"))
    check group.selected.isNone
    let moved = tree.dispatch(keyInput(keyArrowDown))
    check moved.handled and moved.needsRender
    check moved.events.len == 0
    check group.active == some(newItemId("three"))

    let selected = tree.dispatch(keyInput(keyEnter))
    check selected.handled and selected.needsRender
    check selected.events.len == 1
    check selected.events[0].kind == selectionChanged
    check selected.events[0].selection == some(newItemId("three"))
    let repeated = tree.dispatch(keyInput(keySpace))
    check repeated.handled
    check not repeated.needsRender
    check repeated.events.len == 0

    let boundary = tree.dispatch(keyInput(keyArrowDown))
    check boundary.handled
    check not boundary.needsRender
