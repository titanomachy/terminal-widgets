## Deterministic finite animations used by the README API overview.
## Compile with: nim c --path:src examples/api_overview_demo.nim
## Run one demo with: build/bin/api_overview_demo <name>

import std/[options, os]
import terminal_widgets

const
  clearScreen = "\e[?25l\e[2J\e[H"
  resetStyle = "\e[0m"
  showCursor = "\e[?25h"

proc present(tree: WidgetTree; size: Size; caption: string;
             theme = defaultWidgetTheme()) =
  stdout.write clearScreen
  let frame = tree.render(size, theme)
  for row in frame.rows:
    stdout.write row, resetStyle, "\n"
  stdout.write "\e[33m", caption, resetStyle
  stdout.flushFile()
  sleep(650)

proc controlsDemo() =
  let updates = newCheckbox(newWidgetId("updates"), "Install updates")
  let compact = newSwitch(newWidgetId("compact"), "Compact mode")
  let density = newRadioGroup(newWidgetId("density"), [
    newChoiceItem(newItemId("comfortable"), "Comfortable"),
    newChoiceItem(newItemId("balanced"), "Balanced"),
    newChoiceItem(newItemId("compact"), "Compact")])
  let root = newColumn(newWidgetId("controls"),
    [Widget(updates), Widget(compact), Widget(density)])
  root.setSizing(updates.id, fixed(1))
  root.setSizing(compact.id, fixed(1))
  let tree = newWidgetTree(root)
  let size = newSize(38, 5)
  discard tree.layout(size)

  tree.present(size, "Retained controls")
  discard tree.dispatch(keyInput(keySpace))
  tree.present(size, "Space toggles the checkbox")
  discard tree.dispatch(keyInput(keyTab))
  discard tree.dispatch(keyInput(keyEnter))
  tree.present(size, "Tab focuses; Enter activates")
  discard tree.dispatch(keyInput(keyTab))
  discard tree.dispatch(keyInput(keyArrowDown))
  discard tree.dispatch(keyInput(keySpace))
  tree.present(size, "Choices keep stable selected IDs")

proc tabsDemo() =
  let profile = newTextField(newWidgetId("profile"), value = "Ada")
  let activity = newScrollList(newWidgetId("activity"), [
    newChoiceItem(newItemId("first"), "First login"),
    newChoiceItem(newItemId("second"), "Saved settings")])
  let settings = newCheckbox(newWidgetId("settings"), "Compact layout")
  let tabs = newTabs(newWidgetId("tabs"), [
    newTabPage(newItemId("profile-page"), "Profile", profile),
    newTabPage(newItemId("activity-page"), "Activity", activity),
    newTabPage(newItemId("settings-page"), "Settings", settings)])
  let tree = newWidgetTree(tabs)
  let size = newSize(42, 4)
  discard tree.layout(size)

  tree.present(size, "Only the active keyed page is rendered")
  profile.setValue("Grace")
  discard tree.requestFocus(tabs.id)
  discard tree.dispatch(keyInput(keyArrowRight))
  tree.present(size, "Right switches pages")
  discard tree.dispatch(keyInput(keyArrowRight))
  discard tree.dispatch(keyInput(keyTab))
  discard tree.dispatch(keyInput(keySpace))
  tree.present(size, "Page widgets keep their own state")
  discard tree.requestFocus(tabs.id)
  discard tree.dispatch(keyInput(keyHome))
  tree.present(size, "Profile value retained: " & profile.value)

proc textDemo() =
  let required: TextValidator = proc(value: string): Option[string] =
    if value.len == 0: some("Type a name") else: none(string)
  let name = newTextField(newWidgetId("name"), label = "Name",
    placeholder = "Ada Lovelace", validator = required)
  let tree = newWidgetTree(name)
  let size = newSize(48, 2)
  discard tree.layout(size)

  tree.present(size, "Placeholder text is not the value")
  discard tree.dispatch(keyInput(keyEnter))
  tree.present(size, "Validation errors are retained state")
  for character in ["A", "d", "a"]:
    discard tree.dispatch(keyInput(keyText, character))
    tree.present(size, "UTF-8-safe editing: " & name.value)
  discard tree.dispatch(keyInput(keyArrowLeft))
  discard tree.dispatch(keyInput(keyBackspace))
  tree.present(size, "Navigation and deletion use cluster boundaries")

proc eventsDemo() =
  let updates = newCheckbox(newWidgetId("updates"), "Product updates")
  let tree = newWidgetTree(updates)
  let size = newSize(44, 1)
  discard tree.layout(size)

  tree.present(size, "Input: none | Events: []")
  let enabled = tree.dispatch(keyInput(keySpace))
  tree.present(size, "Input: Space | boolChanged(value: " &
    $enabled.events[0].boolValue & ")")
  let ignored = tree.dispatch(keyInput(keyArrowDown))
  tree.present(size, "Input: Down | handled: " & $ignored.handled &
    " | Events: []")
  let disabled = tree.dispatch(keyInput(keyEnter))
  tree.present(size, "Input: Enter | boolChanged(value: " &
    $disabled.events[0].boolValue & ")")

proc layoutDemo() =
  let menu = newMenu(newWidgetId("navigation"), [
    newChoiceItem(newItemId("home"), "Home"),
    newChoiceItem(newItemId("settings"), "Settings")])
  let search = newTextField(newWidgetId("search"), "Search")
  let root = newRow(newWidgetId("workspace"),
    [Widget(menu), Widget(search)])
  root.setPadding(newPadding(1))
  root.setGap(1)
  root.setSizing(menu.id, fixed(16))
  root.setSizing(search.id, flex(1))
  let tree = newWidgetTree(root)
  let size = newSize(52, 5)
  discard tree.layout(size)

  tree.present(size, "Row: padding 1, gap 1, menu fixed 16")
  discard tree.dispatch(keyInput(keyArrowDown))
  tree.present(size, "Input routes to the focused menu")
  discard tree.dispatch(keyInput(keyTab))
  tree.present(size, "Tab follows depth-first focus order")
  discard tree.dispatch(keyInput(keyText, "filter"))
  tree.present(size, "The flexible field receives the remaining width")

proc framesDemo() =
  let name = newTextField(newWidgetId("name"), label = "Name", value = "Ada")
  let enabled = newCheckbox(newWidgetId("enabled"), "Enabled", checked = true)
  let root = newColumn(newWidgetId("form"), [Widget(name), Widget(enabled)])
  let tree = newWidgetTree(root)
  let size = newSize(46, 2)
  discard tree.layout(size)

  tree.present(size, "defaultWidgetTheme()", defaultWidgetTheme())
  tree.present(size, "plainWidgetTheme()", plainWidgetTheme())
  tree.present(size, "unicodeWidgetTheme()", unicodeWidgetTheme())
  discard tree.dispatch(keyInput(keyTab))
  tree.present(size, "Frames also carry optional cursor metadata",
    unicodeWidgetTheme())

proc main() =
  defer:
    stdout.write showCursor
    stdout.flushFile()

  if paramCount() != 1:
    quit "usage: api_overview_demo <controls|tabs|text|events|layout|frames>"

  case paramStr(1)
  of "controls": controlsDemo()
  of "tabs": tabsDemo()
  of "text": textDemo()
  of "events": eventsDemo()
  of "layout": layoutDemo()
  of "frames": framesDemo()
  else: quit "unknown API overview demo: " & paramStr(1)

main()
