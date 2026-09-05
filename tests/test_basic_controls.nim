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
    let unchecked = tree.dispatch(keyInput(keyEnter))
    check unchecked.events.len == 1
    check not checkbox.checked

    discard tree.requestFocus(switch.id)
    let switched = tree.dispatch(keyInput(keyEnter))
    check switched.handled and switched.events.len == 1
    check switch.isOn and switch.marker == "[on]"
    check switched.events[0].kind == boolChanged
    let switchedOff = tree.dispatch(keyInput(keySpace))
    check switchedOff.events.len == 1
    check not switch.isOn

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

    discard tree.dispatch(keyInput(keyHome))
    check group.active == some(newItemId("one"))
    discard tree.dispatch(keyInput(keyEnd))
    check group.active == some(newItemId("three"))
    discard tree.dispatch(keyInput(keyArrowUp))
    check group.active == some(newItemId("one"))
    discard tree.dispatch(keyInput(keyArrowDown))
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

  test "disabled controls empty groups and unrelated keys are inert":
    let checkbox = newCheckbox(newWidgetId("checkbox"), "Checkbox")
    checkbox.setEnabled(false)
    let tree = newWidgetTree(checkbox)
    discard tree.layout(newSize(20, 1))
    check tree.focused.isNone
    let activation = tree.dispatch(keyInput(keySpace))
    check not activation.handled
    check not checkbox.checked

    let empty = newRadioGroup(newWidgetId("empty"), [])
    let emptyTree = newWidgetTree(empty)
    discard emptyTree.layout(newSize(20, 1))
    check emptyTree.focused.isNone

    let enabledCheckbox = newCheckbox(newWidgetId("arrows"), "Arrows")
    let arrowTree = newWidgetTree(enabledCheckbox)
    discard arrowTree.layout(newSize(20, 1))
    check not arrowTree.dispatch(keyInput(keyArrowDown)).handled

  test "radio replacement preserves keys or selects a directional fallback":
    let group = newRadioGroup(newWidgetId("mode"), [
      newChoiceItem(newItemId("one"), "One"),
      newChoiceItem(newItemId("two"), "Two"),
      newChoiceItem(newItemId("three"), "Three")
    ], selected = some(newItemId("two")))
    group.setItems([
      newChoiceItem(newItemId("three"), "Three"),
      newChoiceItem(newItemId("two"), "Renamed Two")
    ])
    check group.selected == some(newItemId("two"))
    check group.active == some(newItemId("two"))
    group.setItems([
      newChoiceItem(newItemId("three"), "Three"),
      newChoiceItem(newItemId("disabled"), "Disabled", enabled = false)
    ])
    check group.selected == some(newItemId("three"))
    check group.active == some(newItemId("three"))
    let revision = group.revision
    expect ValueError:
      group.setItems([
        newChoiceItem(newItemId("same"), "First"),
        newChoiceItem(newItemId("same"), "Second")])
    check group.selected == some(newItemId("three"))
    check group.revision == revision

  test "plain and styled control frames are deterministic":
    let checkbox = newCheckbox(newWidgetId("accept"), "Accept", checked = true)
    let plain = renderControl(checkbox, plainWidgetTheme(), focused = true)
    check plain == @["> [x] Accept"]
    check renderControl(checkbox, plainWidgetTheme(), focused = true) == plain

    let styled = renderControl(checkbox, defaultWidgetTheme(), focused = true)
    check styled == @["\e[1;36m> [x] Accept\e[0m"]
    let disabled = renderControl(checkbox, defaultWidgetTheme(), enabled = false)
    check disabled == @["\e[2;90m! [x] Accept\e[0m"]

    let group = newRadioGroup(newWidgetId("radio"), [
      newChoiceItem(newItemId("one"), "One"),
      newChoiceItem(newItemId("two"), "Two")
    ], selected = some(newItemId("two")))
    check renderControl(group, plainWidgetTheme(), focused = true) == @[
      "  ( ) One", "> (*) Two"]
