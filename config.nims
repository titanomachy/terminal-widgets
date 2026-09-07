## Keep repository compiler products under build/, including direct nim invocations.
import std/os

let buildRoot = thisDir() / "build"
let bundledDocHack = thisDir() / ".nim_runtime" / "tools" / "dochack" /
  "dochack.nim"

# Nim 2.0's documentation generator compiles this helper beside its source and
# asserts that exact path exists. It does not propagate skip-config switches to
# the nested compiler invocation.
if cmpPaths(projectPath(), bundledDocHack) != 0:
  switch("outDir", buildRoot / "bin")
  switch("nimcache", buildRoot / "nimcache" / ("nim-" & NimVersion) / projectName())

# begin Nimble config (version 2)
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# end Nimble config
