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
