import std/[algorithm, os, strutils]

version = "0.1.0"
author = "titanomachy"
description = "Pure-Nim persistent, composable terminal controls and focus handling"
license = "MIT"
srcDir = "src"
binDir = "build/bin"
skipDirs = @["build", "specs"]

requires "nim >= 2.0.0"
requires "terminal_style >= 0.1.1"
requires "terminal_screen >= 0.1.1"

proc requireSource(path: string) =
  if not fileExists(path):
    raise newException(ValueError,
      "Implementation pending: " & path & ". See implementation guide.")

proc sources(directory: string): seq[string] =
  if dirExists(directory):
    for path in listFiles(directory):
      if path.endsWith(".nim"):
        result.add path
  result.sort()
  if result.len == 0:
    raise newException(ValueError,
      "No Nim sources in " & directory & ". See implementation guide.")

proc runTests(memoryManager = "") =
  var count = 0
  for path in sources("tests"):
    if extractFilename(path).startsWith("test_"):
      inc count
      var command = "nim c -r --path:src"
      if memoryManager.len > 0:
        command.add " --mm:" & memoryManager
      exec command & " " & quoteShell(path)
  if count == 0:
    raise newException(ValueError, "No test_*.nim suites exist yet")

task compilePackage, "Compile the library once its implementation exists":
  requireSource("src/terminal_widgets.nim")
  exec "nim c --path:src src/terminal_widgets.nim"

task test, "Compile and run test_*.nim suites":
  runTests()

task testArc, "Run the complete test suite with ARC":
  runTests("arc")

task testOrc, "Run the complete test suite with ORC":
  runTests("orc")

task packageTest, "Install and compile an isolated package consumer":
  exec "nim c -r --path:src tests/package_verification.nim"

task examples, "Compile examples without starting interactive sessions":
  for path in sources("examples"):
    exec "nim c --path:src " & quoteShell(path)

task headlessExample, "Run the deterministic mixed-form example":
  exec "nim c -r --path:src examples/headless_form.nim"

task docs, "Generate API documentation inside build/docs":
  requireSource("src/terminal_widgets.nim")
  # Isolate documentation helper compilation from repository parent configs.
  exec "nim doc --skipParentCfg:on --project --index:on --outdir:build/docs --nimcache:build/nimcache/docs --path:src src/terminal_widgets.nim"
  exec "nim doc --skipParentCfg:on --project --index:on --outdir:build/docs --nimcache:build/nimcache/docs-runtime --path:src src/terminal_widgets/runtime.nim"

task releaseCheck, "Validate the implemented package, tests, examples, and docs":
  exec "nimble check"
  exec "nimble compilePackage"
  exec "nimble test"
  exec "nimble packageTest"
  exec "nimble examples"
  exec "nimble headlessExample"
  exec "nimble docs"
