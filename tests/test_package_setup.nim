import std/[os, strutils, unittest]

{.warning[UnusedImport]: off.}
from terminal_widgets import nil
import support/package_layout

const repositoryRoot = currentSourcePath().parentDir().parentDir()
const manifest = staticRead(repositoryRoot / "terminal_widgets.nimble")
const workflow = staticRead(repositoryRoot / ".github" / "workflows" / "ci.yml")

suite "package setup":
  test "public facade imports without initialization":
    check true

  test "manifest declares package metadata and dependency floors":
    check "version = \"0.1.0\"" in manifest
    check "license = \"MIT\"" in manifest
    check "requires \"nim >= 2.0.0\"" in manifest
    check "requires \"terminal_style >= 0.1.1\"" in manifest
    check "requires \"terminal_screen >= 0.1.1\"" in manifest
    check "bin =" notin manifest

  test "source tree matches the specified module map":
    check fileExists(repositoryRoot / "src" / "terminal_widgets.nim")
    for moduleName in expectedModules:
      check fileExists(repositoryRoot / "src" / "terminal_widgets" / moduleName)

  test "test and example entry-point directories exist":
    check dirExists(repositoryRoot / "tests" / "support")
    check dirExists(repositoryRoot / "examples")

  test "compatibility workflow covers compilers platforms and memory managers":
    check "os: [ubuntu-latest, macos-latest, windows-latest]" in workflow
    check "nim: [\"2.0.x\", stable]" in workflow
    check "nim-version: ${{ matrix.nim }}" in workflow
    check "mm: [Arc, Orc]" in workflow
    check "nimble releaseCheck -y" in workflow
    check "task testArc" in manifest
    check "task testOrc" in manifest
    check "task packageTest" in manifest
