import std/[options, strutils, unittest]
import terminal_style
import terminal_widgets

proc plainFrame(root: Widget; width, height: int): Frame =
  let tree = newWidgetTree(root)
  discard tree.layout(newSize(width, height))
  tree.render(newSize(width, height), plainWidgetTheme())

suite "full-frame rendering and themes":
  test "frames have exact dimensions and focused text cursor metadata":
    let field = newTextField(newWidgetId("field"), label = "Name", value = "界x")
    let tree = newWidgetTree(field)
    discard tree.layout(newSize(12, 2))
    discard tree.dispatch(keyInput(keyEnd))
    let frame = tree.render(newSize(12, 2), plainWidgetTheme())
    check frame.width == 12 and frame.height == 2
    check frame.rows.len == 2
    for row in frame.rows: check displayWidth(row) == 12
    check frame.cursor == some(CursorCell(column: 11, row: 0))
    check not frame.rows.join.contains('\e')

    let revision = field.revision
    check tree.render(newSize(12, 2), plainWidgetTheme()) == frame
    check field.revision == revision

  test "zero geometry is explicit and mismatched or stale layouts are rejected":
    let empty = newStaticText(newWidgetId("zero"), "ignored")
    let tree = newWidgetTree(empty)
    discard tree.layout(newSize(0, 0))
    let frame = tree.render(newSize(0, 0), plainWidgetTheme())
    check frame.rows.len == 0 and frame.cursor.isNone
    expect ValueError:
      discard tree.render(newSize(1, 0), plainWidgetTheme())

    let child = newCheckbox(newWidgetId("stale-child"), "Child")
    let root = newColumn(newWidgetId("stale-root"), [Widget(child)])
    let stale = newWidgetTree(root)
    discard stale.layout(newSize(8, 1))
    child.setVisible(false)
    expect ValueError:
      discard stale.render(newSize(8, 1), plainWidgetTheme())
    discard stale.layout(newSize(8, 1))
    check stale.render(newSize(8, 1), plainWidgetTheme()).rows == @["        "]

    root.setVisible(false)
    discard stale.layout(newSize(8, 1))
    check stale.render(newSize(8, 1), plainWidgetTheme()).rows == @["        "]

  test "plain text is sanitized and isolated combining marks get a base":
    let unsafe = newCheckbox(newWidgetId("unsafe"), "A\e]8;;bad\aB\nC\xC3\x28")
    let frame = plainFrame(unsafe, 20, 1)
    check not frame.rows[0].contains('\e')
    check not frame.rows[0].contains('\a')
    check "A ]8;;bad B C�" in frame.rows[0]
    check sanitizePlainText("\u0301mark") == "◌\u0301mark"

  test "trusted static content retains only SGR and stack children are opaque":
    let bottom = newStaticText(newWidgetId("bottom"), "bottom")
    let top = newTrustedStyledText(newWidgetId("top"),
      "\e[31mX\e[0m\e]8;;https://invalid.example\a")
    let stack = newStack(newWidgetId("stack"), [Widget(bottom), Widget(top)])
    let tree = newWidgetTree(stack)
    discard tree.layout(newSize(6, 1))
    let colored = tree.render(newSize(6, 1), defaultWidgetTheme())
    check displayWidth(colored.rows[0]) == 6
    check stripAnsi(colored.rows[0]) == "X     "
    check not colored.rows[0].contains("]8;")
    let plain = tree.render(newSize(6, 1), plainWidgetTheme())
    check plain.rows == @["X     "]

  test "wide glyph clipping leaves boundary cells blank":
    let wide = newStaticText(newWidgetId("wide"), "界x")
    check plainFrame(wide, 1, 1).rows == @[" "]
    check plainFrame(newStaticText(newWidgetId("wide-two"), "界x"), 2, 1).rows == @["界"]

  test "theme markers are measured and unsafe markers are rejected":
    let checkbox = newCheckbox(newWidgetId("marked"), "ok", checked = true)
    var theme = plainWidgetTheme()
    theme.focusMarker = ">>"
    theme.checkboxOnMarker = "YES"
    let tree = newWidgetTree(checkbox)
    discard tree.layout(newSize(9, 1))
    check tree.render(newSize(9, 1), theme).rows == @[
      ">> YES ok"]

    theme.focusMarker = "\e[31m>"
    expect ValueError:
      discard tree.render(newSize(9, 1), theme)

  test "colored rows close semantic styles at row boundaries":
    let control = newCheckbox(newWidgetId("colored"), "Color")
    let tree = newWidgetTree(control)
    discard tree.layout(newSize(12, 1))
    let row = tree.render(newSize(12, 1), defaultWidgetTheme()).rows[0]
    check row.endsWith(ansiReset)
    check displayWidth(row) == 12

  test "checkbox and switch golden frames cover focus normal and disabled":
    let checkbox = newCheckbox(newWidgetId("gold-checkbox"), "Check",
      checked = true)
    let switch = newSwitch(newWidgetId("gold-switch"), "Switch", on = true)
    let root = newColumn(newWidgetId("gold-bools"),
      [Widget(checkbox), Widget(switch)])
    let tree = newWidgetTree(root)
    let size = newSize(16, 2)
    discard tree.layout(size)
    check tree.render(size, plainWidgetTheme()).rows == @[
      "> [x] Check     ",
      "  [on] Switch   "]
    discard tree.requestFocus(switch.id)
    check tree.render(size, plainWidgetTheme()).rows == @[
      "  [x] Check     ",
      "> [on] Switch   "]
    switch.setEnabled(false)
    discard tree.layout(size)
    check tree.render(size, plainWidgetTheme()).rows == @[
      "> [x] Check     ",
      "! [on] Switch   "]
    check plainFrame(newCheckbox(newWidgetId("tiny-check"), "long"), 1, 1).rows == @[
      ">"]

  test "radio golden frames distinguish active selected disabled and empty":
    let group = newRadioGroup(newWidgetId("gold-radio"), [
      newChoiceItem(newItemId("one"), "One"),
      newChoiceItem(newItemId("two"), "Two"),
      newChoiceItem(newItemId("three"), "Three", enabled = false)
    ], selected = some(newItemId("two")))
    let frame = plainFrame(group, 14, 3)
    check frame.rows == @[
      "  ( ) One     ",
      "> (*) Two     ",
      "! ( ) Three   "]
    let empty = newRadioGroup(newWidgetId("empty-radio"), [])
    check plainFrame(empty, 8, 1).rows == @["        "]

  test "list and menu golden frames cover selected disabled and empty rows":
    let choices = [
      newChoiceItem(newItemId("one"), "One"),
      newChoiceItem(newItemId("disabled"), "Disabled", enabled = false),
      newChoiceItem(newItemId("three"), "Three")]
    let list = newScrollList(newWidgetId("gold-list"), choices)
    check plainFrame(list, 14, 3).rows == @[
      "> One         ",
      "! Disabled    ",
      "  Three       "]
    let menu = newMenu(newWidgetId("gold-menu"), choices)
    check plainFrame(menu, 14, 3).rows == @[
      "> One         ",
      "! Disabled    ",
      "  Three       "]
    let empty = newScrollList(newWidgetId("empty-list"), [])
    check plainFrame(empty, 12, 1).rows == @["  (empty)   "]

  test "tabs text fields and static text have complete plain snapshots":
    let page = newCheckbox(newWidgetId("page-control"), "Inside")
    let disabledPage = newCheckbox(newWidgetId("disabled-page-control"), "Off")
    let tabs = newTabs(newWidgetId("gold-tabs"), [
      newTabPage(newItemId("one-page"), "One", page),
      newTabPage(newItemId("two-page"), "Two", disabledPage,
        enabled = false)])
    let tabTree = newWidgetTree(tabs)
    let tabSize = newSize(16, 2)
    discard tabTree.layout(tabSize)
    check tabTree.render(tabSize, plainWidgetTheme()).rows == @[
      "[One]|(Two)     ",
      "  [ ] Inside    "]
    discard tabTree.dispatch(keyInput(keyTab))
    check tabTree.render(tabSize, plainWidgetTheme()).rows == @[
      "[One]|(Two)     ",
      "> [ ] Inside    "]

    let validator: TextValidator = proc(value: string): Option[string] =
      some("required")
    let field = newTextField(newWidgetId("gold-field"), label = "Name",
      placeholder = "type", validator = validator)
    let fieldTree = newWidgetTree(field)
    let fieldSize = newSize(14, 2)
    discard fieldTree.layout(fieldSize)
    check fieldTree.render(fieldSize, plainWidgetTheme()).rows == @[
      "> Name: type  ",
      "              "]
    discard fieldTree.dispatch(keyInput(keyEnter))
    check fieldTree.render(fieldSize, plainWidgetTheme()).rows == @[
      "> Name: type  ",
      "  required    "]
    field.setEnabled(false)
    discard fieldTree.layout(fieldSize)
    check fieldTree.render(fieldSize, plainWidgetTheme()).rows[0] ==
      "! Name: type  "

    let text = newStaticText(newWidgetId("gold-static"), "first\n界🙂")
    check plainFrame(text, 8, 2).rows == @["first   ", "界🙂    "]

  test "large and resized nested frames remain bounded and deterministic":
    let left = newStaticText(newWidgetId("nested-left"), "界界界")
    let right = newStaticText(newWidgetId("nested-right"), "🙂long")
    let row = newRow(newWidgetId("nested-row"), [Widget(left), Widget(right)])
    row.setPadding(newPadding(1))
    let tree = newWidgetTree(row)
    for size in [newSize(1, 1), newSize(9, 3), newSize(120, 40)]:
      discard tree.layout(size)
      let before = row.revision
      let first = tree.render(size, plainWidgetTheme())
      let second = tree.render(size, plainWidgetTheme())
      check first == second
      check first.rows.len == size.height
      for rendered in first.rows: check displayWidth(rendered) == size.width
      if first.cursor.isSome:
        check first.cursor.get.column in 0 ..< size.width
        check first.cursor.get.row in 0 ..< size.height
      check row.revision == before

  test "plain cursor erase and OSC payloads never become frame controls":
    let attacks = newStaticText(newWidgetId("attacks"),
      "plain\e[2J erase\e[4;8H move\e]0;title\a end")
    let frame = plainFrame(attacks, 44, 1)
    check not frame.rows[0].contains('\e')
    check not frame.rows[0].contains('\a')
    check displayWidth(frame.rows[0]) == 44

  test "every control remains a valid golden frame at one cell":
    let radio = newRadioGroup(newWidgetId("tiny-radio"), [
      newChoiceItem(newItemId("tiny-radio-item"), "界")])
    let list = newScrollList(newWidgetId("tiny-list"), [
      newChoiceItem(newItemId("tiny-list-item"), "界")])
    let menu = newMenu(newWidgetId("tiny-menu"), [
      newChoiceItem(newItemId("tiny-menu-item"), "界")])
    let tabs = newTabs(newWidgetId("tiny-tabs"), [
      newTabPage(newItemId("tiny-tab"), "界",
        newCheckbox(newWidgetId("tiny-tab-child"), "child"))])
    let widgets: seq[tuple[widget: Widget, expected: string]] = @[
      (Widget(newCheckbox(newWidgetId("tiny-cb"), "界")), ">"),
      (Widget(newSwitch(newWidgetId("tiny-sw"), "界")), ">"),
      (Widget(radio), ">"),
      (Widget(list), ">"),
      (Widget(menu), ">"),
      (Widget(tabs), "["),
      (Widget(newTextField(newWidgetId("tiny-field"), value = "界")), ">"),
      (Widget(newStaticText(newWidgetId("tiny-static"), "界")), " ")]
    for entry in widgets:
      check plainFrame(entry.widget, 1, 1).rows == @[entry.expected]

  test "unfocused text field keeps semantic normal presentation":
    let field = newTextField(newWidgetId("normal-field"), label = "Name",
      value = "Ada")
    let peer = newCheckbox(newWidgetId("normal-peer"), "Peer")
    let root = newColumn(newWidgetId("normal-root"),
      [Widget(field), Widget(peer)])
    let tree = newWidgetTree(root)
    let size = newSize(14, 2)
    discard tree.layout(size)
    discard tree.requestFocus(peer.id)
    let frame = tree.render(size, plainWidgetTheme())
    check frame.rows == @["  Name: Ada   ", "> [ ] Peer    "]
    check frame.cursor.isNone
