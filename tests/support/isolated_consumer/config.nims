## Keep the disposable consumer's generated files within its own build tree.
import std/os

let consumerBuildRoot = thisDir() / "build"
switch("outDir", consumerBuildRoot / "bin")
switch("nimcache", consumerBuildRoot / "nimcache")
