import std/[options, unittest]
import terminal_style
import terminal_widgets

proc item(id, label: string; enabled = true): ChoiceItem =
  newChoiceItem(newItemId(id), label, enabled)

proc assertFrame(tree: WidgetTree; width, height: int) =
  let frame = tree.render(newSize(width, height), plainWidgetTheme())
  check frame.width == width
  check frame.height == height
  check frame.rows.len == height
  for row in frame.rows:
    check displayWidth(row) == width

suite "mixed-widget scripted sessions":
  test "values survive tab focus input and resize transitions":
    let enabled = newCheckbox(newWidgetId("enabled"), "Enabled")
    let compact = newSwitch(newWidgetId("compact"), "Compact")
    let name = newTextField(newWidgetId("name"), label = "Name")
    let records = newScrollList(newWidgetId("records"), [
      item("first", "First"),
      item("disabled", "Disabled", enabled = false),
      item("last", "Last")])
    let primary = newColumn(newWidgetId("primary"),
      [Widget(enabled), Widget(compact), Widget(name), Widget(records)])
    primary.setSizing(enabled.id, fixed(1))
    primary.setSizing(compact.id, fixed(1))
    primary.setSizing(name.id, fixed(1))

    let actions = newMenu(newWidgetId("actions"), [
      item("view", "View"), item("skip", "Skip", enabled = false),
      item("save", "Save")])
    let density = newRadioGroup(newWidgetId("density"), [
      item("roomy", "Roomy"), item("dense", "Dense")])
    let secondary = newColumn(newWidgetId("secondary"),
      [Widget(actions), Widget(density)])
    secondary.setSizing(actions.id, fixed(3))

    let tabs = newTabs(newWidgetId("tabs"), [
      newTabPage(newItemId("primary-page"), "Primary", primary),
      newTabPage(newItemId("secondary-page"), "Secondary", secondary)])
    let tree = newWidgetTree(tabs)
    discard tree.layout(newSize(30, 8))
    assertFrame(tree, 30, 8)

    discard tree.requestFocus(enabled.id)
    let checked = tree.dispatch(keyInput(keySpace))
    check checked.events.len == 1
    check checked.events[0].kind == boolChanged
    check enabled.checked

    discard tree.dispatch(keyInput(keyTab))
    check tree.focused == some(compact.id)
    discard tree.dispatch(keyInput(keyEnter))
    check compact.isOn

    discard tree.dispatch(keyInput(keyTab))
    check tree.focused == some(name.id)
    for character in ["A", "d", "a"]:
      let edited = tree.dispatch(keyInput(keyText, text = character))
      check edited.events.len == 1
      check edited.events[0].kind == textChanged
    check name.value == "Ada"

    discard tree.dispatch(keyInput(keyTab))
    check tree.focused == some(records.id)
    discard tree.dispatch(keyInput(keyEnd))
    check records.selected == some(newItemId("last"))

    discard tree.requestFocus(tabs.id)
    discard tree.dispatch(keyInput(keyArrowRight))
    check tabs.active == some(newItemId("secondary-page"))
    check tree.focusOrder == @[tabs.id, actions.id, density.id]
    discard tree.dispatch(keyInput(keyTab))
    discard tree.dispatch(keyInput(keyArrowDown))
    let activation = tree.dispatch(keyInput(keyEnter))
    check activation.events.len == 1
    check activation.events[0].kind == activated
    check activation.events[0].item == newItemId("save")

    discard tree.dispatch(keyInput(keyTab))
    discard tree.dispatch(keyInput(keyEnd))
    discard tree.dispatch(keyInput(keySpace))
    check density.selected == some(newItemId("dense"))

    discard tree.layout(newSize(12, 4))
    assertFrame(tree, 12, 4)
    discard tree.requestFocus(tabs.id)
    discard tree.dispatch(keyInput(keyArrowLeft))
    check enabled.checked
    check compact.isOn
    check name.value == "Ada"
    check records.selected == some(newItemId("last"))
    assertFrame(tree, 12, 4)

  test "an all-disabled page repairs focus without losing retained values":
    let value = newTextField(newWidgetId("value"), value = "retained")
    let unavailable = newCheckbox(newWidgetId("unavailable"), "Unavailable")
    unavailable.setEnabled(false)
    let tabs = newTabs(newWidgetId("tabs"), [
      newTabPage(newItemId("value-page"), "Value", value),
      newTabPage(newItemId("disabled-page"), "Disabled", unavailable)])
    let tree = newWidgetTree(tabs)
    discard tree.layout(newSize(16, 3))
    discard tree.requestFocus(value.id)
    tabs.setActive(some(newItemId("disabled-page")))
    discard tree.layout(newSize(8, 2))
    check tree.focused == some(tabs.id)
    check tree.focusOrder == @[tabs.id]
    check value.value == "retained"
    assertFrame(tree, 8, 2)
