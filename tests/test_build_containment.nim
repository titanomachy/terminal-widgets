import std/[os, osproc, strutils, tables, unittest]

const repositoryRoot = currentSourcePath().parentDir().parentDir()

type TreeSnapshot = Table[string, string]

proc recordTree(directory: string; snapshot: var TreeSnapshot) =
  for kind, path in walkDir(directory):
    let relative = relativePath(path, repositoryRoot).replace('\\', '/')
    if relative == ".git" or relative == "build" or relative == ".nim_runtime":
      continue
    case kind
    of pcDir:
      snapshot[relative & "/"] = "directory"
      recordTree(path, snapshot)
    of pcFile:
      snapshot[relative] = readFile(path)
    of pcLinkToFile, pcLinkToDir:
      snapshot[relative] = "link:" & expandSymlink(path)

proc repositorySnapshot(): TreeSnapshot =
  ## Record authored paths and file contents so compiler runs cannot silently
  ## add or modify artifacts outside the repository's build directory.
  recordTree(repositoryRoot, result)

proc run(command: string; workingDirectory = repositoryRoot) =
  let execution = execCmdEx(command, workingDir = workingDirectory,
    options = {poUsePath, poStdErrToStdOut})
  if execution.exitCode != 0:
    checkpoint command & "\n" & execution.output
  check execution.exitCode == 0

proc compilerOutputExists(path: string): bool =
  ## ExeExt omits its leading dot ("exe" on Windows). Nim versions differ in
  ## whether configured and explicit output names receive that separator.
  fileExists(path) or
    fileExists(addFileExt(path, ExeExt)) or
    (ExeExt.len > 0 and fileExists(path & ExeExt))

suite "build containment":
  test "root configuration declares checkout-local output and versioned caches":
    const configuration = staticRead(repositoryRoot / "config.nims")
    check "thisDir() / \"build\"" in configuration
    check "switch(\"outDir\", buildRoot / \"bin\")" in configuration
    check "nim-\" & NimVersion" in configuration
    check "projectName()" in configuration
    check "projectPath()" in configuration
    check "dochack.nim" in configuration

  test "direct compilation, nested compilation, execution, and docs stay contained":
    let before = repositorySnapshot()
    let example = repositoryRoot / "examples" / "package_import.nim"
    let packageTest = repositoryRoot / "tests" / "test_package_setup.nim"

    run("nim c --path:src " & quoteShell(example))
    run("nim c -r --path:src " & quoteShell(packageTest))
    run("nim r --path:src " & quoteShell(example))
    run("nim c --path:../src package_import.nim", repositoryRoot / "examples")
    run("nim doc --skipParentCfg:on --skipProjCfg:on --project --index:on" &
      " --outdir:build/docs --nimcache:build/nimcache/docs" &
      " --path:src src/terminal_widgets.nim")

    check compilerOutputExists(repositoryRoot / "build" / "bin" / "package_import")
    check compilerOutputExists(repositoryRoot / "build" / "bin" / "test_package_setup")
    check dirExists(repositoryRoot / "build" / "nimcache" /
      ("nim-" & NimVersion) / "package_import")
    check fileExists(repositoryRoot / "build" / "docs" / "terminal_widgets.html")
    check repositorySnapshot() == before

  test "explicit concurrent-job paths remain below build":
    let before = repositorySnapshot()
    let fixtureDirectory = repositoryRoot / "build" / "tmp"
    let fixture = fixtureDirectory / "cache_isolation_probe.nim"
    let output = repositoryRoot / "build" / "bin" / "verification" /
      "c-default" / "cache_isolation_probe"
    let cache = repositoryRoot / "build" / "nimcache" / "verification" /
      ("nim-" & NimVersion) / "c-default"
    createDir(fixtureDirectory)
    createDir(output.parentDir())
    createDir(cache)
    writeFile(fixture, "echo \"cache isolation probe\"\n")

    run("nim c --out:" & quoteShell(output) & " --nimcache:" & quoteShell(cache) &
      " " & quoteShell(fixture))

    check compilerOutputExists(output)
    check dirExists(cache)
    check repositorySnapshot() == before
