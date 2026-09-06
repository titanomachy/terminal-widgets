import std/[os, strutils, unittest]

const repositoryRoot = currentSourcePath().parentDir().parentDir()
const requiredExamples = ["checkbox.nim", "switch.nim", "radio_group.nim",
  "scroll_list.nim", "menu.nim", "tabs.nim", "text_field.nim",
  "headless_form.nim", "form.nim"]
const requiredGuides = ["api.md", "behavior.md", "runtime.md"]

suite "user documentation and standalone examples":
  test "required examples are independent documented entry points":
    for filename in requiredExamples:
      let path = repositoryRoot / "examples" / filename
      check fileExists(path)
      let source = readFile(path)
      check "Compile" in source
      check "nim c" in source
      check "import terminal_widgets" in source
    let interactive = readFile(repositoryRoot / "examples" / "form.nim")
    check "runWidgets" in interactive
    check "Enter submits and exits" in interactive
    check "Escape also" in interactive
    check "Ctrl+C cancels" in interactive

  test "guides cover public behavior ownership errors and cleanup":
    for filename in requiredGuides:
      check fileExists(repositoryRoot / "docs" / filename)
    let api = readFile(repositoryRoot / "docs" / "api.md")
    let behavior = readFile(repositoryRoot / "docs" / "behavior.md")
    let runtime = readFile(repositoryRoot / "docs" / "runtime.md")
    check "## Controls" in api
    check "## Composition and focus" in api
    check "## Fixed key bindings" in behavior
    check "## Text and Unicode scope" in behavior
    check "## Errors and validation" in behavior
    check "## Owned sessions" in runtime
    check "## Borrowed sessions" in runtime
    check "## Failures and evidence" in runtime

  test "README links the guides and compile-checked quick start":
    let readme = readFile(repositoryRoot / "README.md")
    for filename in requiredGuides:
      check ("docs/" & filename) in readme
    check "examples/checkbox.nim" in readme
    check "examples/headless_form.nim" in readme
    check "examples/form.nim" in readme
    check "nimble docs" in readme
