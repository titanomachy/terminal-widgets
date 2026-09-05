import std/[options, unittest]
import terminal_widgets

suite "core public model":
  test "IDs and geometry validate caller input":
    check $newWidgetId("settings") == "settings"
    check $newItemId("compact") == "compact"
    expect ValueError:
      discard newWidgetId("")
    expect ValueError:
      discard newItemId("")

    let bounds = newRect(2, 3, 10, 4)
    check (bounds.x, bounds.y, bounds.width, bounds.height) == (2, 3, 10, 4)
    check newSize(0, 0).width == 0
    expect ValueError:
      discard newRect(-1, 0, 1, 1)
    expect ValueError:
      discard newRect(high(int), 0, 1, 0)
    expect ValueError:
      discard newSize(1, -1)

  test "common widget properties are private state with stable revisions":
    let checkbox = newCheckbox(newWidgetId("updates"), "Install updates")
    check checkbox.visible
    check checkbox.enabled
    check checkbox.label == "Install updates"
    check checkbox.helpText.isNone
    check checkbox.revision == 0

    checkbox.setChecked(true)
    checkbox.setVisible(false)
    checkbox.setEnabled(false)
    checkbox.setLabel("Updates")
    checkbox.setHelpText("Applied on restart")
    check checkbox.checked
    check not checkbox.visible
    check not checkbox.enabled
    check checkbox.label == "Updates"
    check checkbox.helpText == some("Applied on restart")
    check checkbox.revision == 5

    checkbox.setChecked(true)
    checkbox.setVisible(false)
    checkbox.setHelpText("Applied on restart")
    check checkbox.revision == 5
    checkbox.clearHelpText()
    check checkbox.helpText.isNone

  test "control constructors retain values and validate selections":
    let networkSwitch = newSwitch(newWidgetId("network"), "Network")
    check not networkSwitch.isOn
    networkSwitch.setOn(true)
    check networkSwitch.isOn

    let choices = @[
      newChoiceItem(newItemId("normal"), "Normal"),
      newChoiceItem(newItemId("safe"), "Safe mode", enabled = false)
    ]
    let group = newRadioGroup(newWidgetId("mode"), choices,
      some(newItemId("normal")))
    check group.selected == some(newItemId("normal"))
    let revisionBeforeFailure = group.revision
    expect ValueError:
      group.setSelected(some(newItemId("safe")))
    check group.selected == some(newItemId("normal"))
    check group.revision == revisionBeforeFailure
    group.setSelected(none(ItemId))
    check group.selected.isNone

    let list = newScrollList(newWidgetId("list"), choices)
    let menu = newMenu(newWidgetId("menu"), choices)
    check list.selected == some(newItemId("normal"))
    check menu.active == some(newItemId("normal"))

  test "collection getters return snapshots while widgets retain identity":
    let choices = @[newChoiceItem(newItemId("one"), "One")]
    let group = newRadioGroup(newWidgetId("group"), choices)
    var snapshot = group.items
    snapshot[0].setLabel("Changed outside")
    snapshot.add newChoiceItem(newItemId("two"), "Two")
    check group.items.len == 1
    check group.items[0].label == "One"

    let child = newTextField(newWidgetId("name"), "Name", "Ada")
    let page = newTabPage(newItemId("profile"), "Profile", child)
    let tabs = newTabs(newWidgetId("tabs"), [page])
    let row = newRow(newWidgetId("row"), [Widget(tabs)])
    let tree = newWidgetTree(row)
    check tabs.active == some(newItemId("profile"))
    check tabs.pages[0].child == Widget(child)
    check Container(tree.root).children[0] == Widget(tabs)
    check child.value == "Ada"

  test "duplicate item and page IDs are rejected":
    let duplicateChoices = @[
      newChoiceItem(newItemId("same"), "First"),
      newChoiceItem(newItemId("same"), "Second")
    ]
    expect ValueError:
      discard newScrollList(newWidgetId("list"), duplicateChoices)

    let child = newCheckbox(newWidgetId("child"), "Child")
    let duplicatePages = @[
      newTabPage(newItemId("same"), "First", child),
      newTabPage(newItemId("same"), "Second", child)
    ]
    expect ValueError:
      discard newTabs(newWidgetId("tabs"), duplicatePages)

  test "text field setter rejects unsafe values atomically":
    let field = newTextField(newWidgetId("query"), value = "café")
    let revisionBeforeFailure = field.revision
    expect ValueError:
      field.setValue("line\nfeed")
    check field.value == "café"
    check field.revision == revisionBeforeFailure
    field.setValue("naïve")
    check field.value == "naïve"

  test "normalized input and tagged output events compile through facade":
    let input: InputEvent = keyInput(keySpace)
    check input.kind == eventKey
    check input.keyEvent.key == keySpace

    let event = WidgetEvent(kind: selectionChanged,
      source: newWidgetId("mode"), selection: some(newItemId("normal")))
    let outcome = dispatchResult(handled = true, needsRender = true,
      events = @[event])
    check outcome.handled
    check outcome.needsRender
    check outcome.events.len == 1
    case outcome.events[0].kind
    of selectionChanged:
      check outcome.events[0].selection == some(newItemId("normal"))
    else:
      check false
