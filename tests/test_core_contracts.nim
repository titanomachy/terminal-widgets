import std/[os, osproc, strutils, unittest]
import terminal_widgets

const repositoryRoot = currentSourcePath().parentDir().parentDir()

suite "core contract verification":
  test "invalid geometry and converted IDs are rejected without mutation":
    expect ValueError:
      discard newRect(0, high(int), 0, 1)
    expect ValueError:
      discard newSize(-1, 0)
    expect ValueError:
      discard newCheckbox(WidgetId(""), "Invalid")

    let field = newTextField(newWidgetId("field"), value = "safe")
    let revision = field.revision
    expect ValueError:
      field.setValue("unsafe\e")
    check field.value == "safe"
    check field.revision == revision

  test "duplicate attachments and conflicting IDs are rejected":
    let child = newCheckbox(newWidgetId("child"), "Child")
    expect ValueError:
      discard newColumn(newWidgetId("duplicate-ref"),
        [Widget(child), Widget(child)])

    let first = newCheckbox(newWidgetId("same"), "First")
    let second = newSwitch(newWidgetId("same"), "Second")
    expect ValueError:
      discard newRow(newWidgetId("duplicate-id"),
        [Widget(first), Widget(second)])

  test "cycle attempts are rejected atomically":
    let outer = newColumn(newWidgetId("outer"))
    let inner = newRow(newWidgetId("inner"), [Widget(outer)])
    let revision = outer.revision

    expect ValueError:
      outer.setChildren([Widget(inner)])
    check outer.children.len == 0
    check outer.revision == revision

  test "tree ownership is exclusive and independent trees keep state separate":
    let owned = newCheckbox(newWidgetId("owned"), "Owned")
    discard newWidgetTree(owned)
    expect ValueError:
      discard newWidgetTree(owned)

    let leftValue = newCheckbox(newWidgetId("value"), "Value")
    let rightValue = newCheckbox(newWidgetId("value"), "Value")
    discard newWidgetTree(leftValue)
    discard newWidgetTree(rightValue)
    leftValue.setChecked(true)
    check leftValue.checked
    check not rightValue.checked

  test "facade-only consumer has no import or construction terminal output":
    let source = repositoryRoot / "tests" / "support" /
      "core_facade_consumer.nim"
    let output = repositoryRoot / "build" / "bin" / "core_facade_consumer"
    let cache = repositoryRoot / "build" / "nimcache" / "core-facade-consumer"
    createDir(output.parentDir())
    createDir(cache)
    let compilation = execCmdEx(
      "nim c --hints:off --out:" & quoteShell(output) &
      " --nimcache:" & quoteShell(cache) &
      " --path:" & quoteShell(repositoryRoot / "src") &
      " " & quoteShell(source),
      workingDir = repositoryRoot,
      options = {poUsePath, poStdErrToStdOut})
    if compilation.exitCode != 0:
      checkpoint compilation.output
    check compilation.exitCode == 0

    let execution = execCmdEx(quoteShell(output & ExeExt),
      workingDir = repositoryRoot,
      options = {poUsePath, poStdErrToStdOut})
    check execution.exitCode == 0
    check execution.output.strip == "consumer-ok"
