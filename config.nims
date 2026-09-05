## Keep repository compiler products under build/, including direct nim invocations.
import std/os

let buildRoot = thisDir() / "build"
switch("outDir", buildRoot / "bin")
switch("nimcache", buildRoot / "nimcache" / ("nim-" & NimVersion) / projectName())

# begin Nimble config (version 2)
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# end Nimble config
