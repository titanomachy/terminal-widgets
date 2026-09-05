import std/[options, strutils, unittest]
import terminal_style
import terminal_widgets

proc fieldTree(field: TextField; width = 40; height = 1): WidgetTree =
  result = newWidgetTree(field)
  discard result.layout(newSize(width, height))

suite "single-line text fields":
  test "cursor navigation and edits operate on supported clusters":
    let field = newTextField(newWidgetId("edit"), value = "abc")
    let tree = fieldTree(field)
    check field.cursorByte == 0

    let right = tree.dispatch(keyInput(keyArrowRight))
    check right.handled and right.needsRender
    check right.events.len == 0
    check field.cursorByte == 1
    let inserted = tree.dispatch(keyInput(keyText, "X"))
    check inserted.handled and inserted.needsRender
    check inserted.events.len == 1
    check inserted.events[0].kind == textChanged
    check field.value == "aXbc"
    check field.cursorByte == 2

    discard tree.dispatch(keyInput(keyBackspace))
    check field.value == "abc"
    check field.cursorByte == 1
    check tree.dispatch(keyInput(keyHome)).needsRender
    check field.cursorByte == 0
    check tree.dispatch(keyInput(keyEnd)).needsRender
    check field.cursorByte == field.value.len
    let noMove = tree.dispatch(keyInput(keyArrowRight))
    check noMove.handled and not noMove.needsRender
    check noMove.events.len == 0

  test "boundaries keep combining marks, modifiers, joins, and flags whole":
    let combining = "e\u0301x"
    check editingBoundaries(combining) == @[0, 3, 4]
    check not isEditingBoundary(combining, 1)
    check previousEditingBoundary(combining, 2) == 0
    check nextEditingBoundary(combining, 1) == 3

    let loneMark = "\u0301a"
    check editingBoundaries(loneMark) == @[0, 2, 3]

    let modified = "👍🏽x"
    check editingBoundaries(modified) == @[0, 8, 9]
    let family = "👨\u200d👩\u200d👧\u200d👦x"
    check editingBoundaries(family) == @[0, family.len - 1, family.len]
    let flag = "🇳🇱x"
    check editingBoundaries(flag) == @[0, 8, 9]

    let field = newTextField(newWidgetId("unicode"), value = "e\u0301x")
    let tree = fieldTree(field)
    discard tree.dispatch(keyInput(keyEnd))
    discard tree.dispatch(keyInput(keyBackspace))
    check field.value == "e\u0301"
    check field.cursorByte == 3
    discard tree.dispatch(keyInput(keyBackspace))
    check field.value == ""

  test "unsafe values and malformed insertions fail atomically":
    expect ValueError:
      discard newTextField(newWidgetId("bad-utf8"), value = "\xC3\x28")
    expect ValueError:
      discard newTextField(newWidgetId("bad-control"), value = "a\n")
    expect ValueError:
      discard newTextField(newWidgetId("bad-c1"), value = "a\u0080")
    expect ValueError:
      discard newTextField(newWidgetId("bad-del"), value = "a\x7f")

    let field = newTextField(newWidgetId("atomic"), value = "safe")
    let tree = fieldTree(field)
    let revision = field.revision
    let malformed = tree.dispatch(keyInput(keyText, "\xC3\x28"))
    check malformed.handled and not malformed.needsRender
    check field.value == "safe"
    check field.cursorByte == 0
    check field.revision == revision
    expect ValueError:
      field.setValue("line\rfeed")
    check field.value == "safe"

  test "scalar limits reject whole insertions and setters":
    let field = newTextField(newWidgetId("limited"), maxRunes = 3)
    let tree = fieldTree(field)
    discard tree.dispatch(keyInput(keyText, "ab"))
    check field.value == "ab"
    let revision = field.revision
    let rejected = tree.dispatch(keyInput(keyText, "界x"))
    check rejected.handled and not rejected.needsRender
    check rejected.events.len == 0
    check field.value == "ab"
    check field.revision == revision
    expect ValueError:
      field.setValue("abcd")
    expect ValueError:
      field.setMaxRunes(1)
    check field.maxRunes == 3
    check field.value == "ab"

    expect ValueError:
      discard newTextField(newWidgetId("zero-limit"), maxRunes = 0)

  test "placeholder, read-only editing, and submission semantics":
    let field = newTextField(newWidgetId("readonly"), placeholder = "Type here",
      readOnly = true)
    let tree = fieldTree(field, width = 20)
    check field.placeholder == "Type here"
    check field.readOnly
    check field.visibleText(field.contentWidth).startsWith("Type here")
    let ignored = tree.dispatch(keyInput(keyText, "x"))
    check ignored.handled and not ignored.needsRender
    check field.value == ""
    check tree.dispatch(keyInput(keyArrowRight)).handled
    let submission = tree.dispatch(keyInput(keyEnter))
    check submission.handled and submission.events.len == 1
    check submission.events[0].kind == submitted
    check submission.events[0].text == ""

    field.setReadOnly(false)
    check not field.readOnly
    check tree.dispatch(keyInput(keySpace)).events.len == 1
    check field.value == " "

  test "validators run only on Enter and sanitize feedback":
    var calls = 0
    let validator: TextValidator = proc(value: string): Option[string] =
      inc calls
      if value.len == 0: some("required\n\x1b") else: none(string)
    let field = newTextField(newWidgetId("validated"), validator = validator)
    let tree = fieldTree(field)
    discard tree.dispatch(keyInput(keyText, "x"))
    check calls == 0
    let ok = tree.dispatch(keyInput(keyEnter))
    check calls == 1
    check ok.events.len == 1 and ok.events[0].kind == submitted
    discard tree.dispatch(keyInput(keyHome))
    discard tree.dispatch(keyInput(keyDelete))
    check field.value == ""
    let failed = tree.dispatch(keyInput(keyEnter))
    check calls == 2
    check failed.events.len == 1 and failed.events[0].kind == validationFailed
    check failed.events[0].validationMessage == "required  "
    check field.validationError == some("required  ")
    discard tree.dispatch(keyInput(keyText, "y"))
    check field.validationError.isNone

    let boom: TextValidator = proc(value: string): Option[string] =
      raise newException(ValueError, "validator failed")
    field.setValidator(boom)
    expect ValueError:
      discard tree.dispatch(keyInput(keyEnter))
    check field.value == "y"

  test "text setters preserve a valid cursor and clear feedback":
    let field = newTextField(newWidgetId("setter"), value = "abc")
    let tree = fieldTree(field)
    field.setCursorByte(1)
    field.setValidator(proc(value: string): Option[string] = some("bad"))
    discard tree.dispatch(keyInput(keyEnter))
    check field.validationError.isSome
    field.setValue("界x")
    check field.value == "界x"
    check field.cursorByte == 3
    check field.validationError.isNone
    expect ValueError:
      field.setCursorByte(1)
    field.setCursorByte(3)
    check field.cursorByte == 3

  test "cell viewport reserves marker and labels and exposes safe cursor cells":
    let field = newTextField(newWidgetId("viewport"), label = "Name",
      value = "abcdef")
    let tree = fieldTree(field, width = 12)
    discard tree.dispatch(keyInput(keyEnd))
    check field.contentStartCells == 8
    check field.contentWidth == 4
    check field.horizontalOffset == 3
    check field.visibleText(field.contentWidth) == "def "
    check field.cursorCell == some(11)

    discard tree.dispatch(resizeInput(terminalSize(8, 1)))
    check field.contentWidth == 0
    check field.cursorCell.isNone
    discard tree.dispatch(resizeInput(terminalSize(9, 1)))
    check field.contentWidth == 1
    check field.cursorCell.isSome

    let wide = newTextField(newWidgetId("wide"), value = "界a")
    let wideTree = fieldTree(wide, width = 3)
    discard wideTree.dispatch(keyInput(keyHome))
    check wide.visibleText(wide.contentWidth) == " "
    discard wideTree.dispatch(keyInput(keyEnd))
    check displayWidth(wide.visibleText(wide.contentWidth)) <= wide.contentWidth

  test "tab leaves the field to focus management and retains text":
    let field = newTextField(newWidgetId("field"))
    let other = newCheckbox(newWidgetId("other"), "Other")
    let root = newColumn(newWidgetId("root"), [Widget(field), Widget(other)])
    let tree = newWidgetTree(root)
    discard tree.layout(newSize(20, 2))
    discard tree.dispatch(keyInput(keyText, "kept"))
    let moved = tree.dispatch(keyInput(keyTab))
    check moved.handled
    check tree.focused == some(other.id)
    discard tree.dispatch(keyInput(keyBacktab))
    check tree.focused == some(field.id)
    check field.value == "kept"
