## Automated external-consumer and installed-package verification.

import std/[algorithm, os, osproc, strutils, tables]

const repositoryRoot = currentSourcePath().parentDir().parentDir()
const fixtureRoot = repositoryRoot / "tests" / "support" / "isolated_consumer"

type TreeSnapshot = Table[string, string]

proc recordTree(directory: string; snapshot: var TreeSnapshot) =
  for kind, path in walkDir(directory):
    let relative = relativePath(path, repositoryRoot).replace('\\', '/')
    if relative == ".git" or relative == "build":
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
  recordTree(repositoryRoot, result)

proc run(command: string; workingDirectory = repositoryRoot): string =
  let execution = execCmdEx(command, workingDir = workingDirectory,
    options = {poUsePath, poStdErrToStdOut})
  if execution.exitCode != 0:
    stderr.writeLine(command & "\n" & execution.output)
    quit(QuitFailure)
  execution.output

proc copyFixture(source, destination: string) =
  createDir(destination)
  for kind, path in walkDir(source):
    let target = destination / extractFilename(path)
    case kind
    of pcDir:
      copyFixture(path, target)
    of pcFile:
      copyFile(path, target)
    of pcLinkToFile, pcLinkToDir:
      raise newException(IOError, "consumer fixture must not contain links")

proc installedPackage(store: string): string =
  let packages = store / "pkgs2"
  for kind, path in walkDir(packages):
    if kind == pcDir and extractFilename(path).startsWith("terminal_widgets-"):
      result = path
      break
  if result.len == 0:
    raise newException(IOError, "installed TerminalWidgets package not found")

proc packageFiles(directory: string): seq[string] =
  for path in walkDirRec(directory):
    if fileExists(path):
      result.add relativePath(path, directory).replace('\\', '/')
  result.sort()

proc verifyInstalledContents(directory: string) =
  let files = packageFiles(directory)
  doAssert "terminal_widgets.nimble" in files
  doAssert "terminal_widgets.nim" in files
  doAssert "terminal_widgets/runtime.nim" in files
  for relative in files:
    let allowed = relative == "terminal_widgets.nimble" or
      relative == "nimblemeta.json" or relative == "terminal_widgets.nim" or
      (relative.startsWith("terminal_widgets/") and relative.endsWith(".nim"))
    doAssert allowed, "unexpected installed path: " & relative
    if relative.endsWith(".nim") or relative.endsWith(".nimble") or
        relative.endsWith(".json"):
      let content = readFile(directory / relative)
      doAssert repositoryRoot notin content
      doAssert "../terminal-" notin content

when isMainModule:
  let before = repositorySnapshot()
  let verificationRoot = repositoryRoot / "build" / "verification" / "package"
  let store = verificationRoot / "nimble"
  let consumer = verificationRoot / "consumer"
  if dirExists(verificationRoot):
    removeDir(verificationRoot)
  createDir(verificationRoot)

  discard run("nimble install -y --nimbleDir:" & quoteShell(store))
  verifyInstalledContents(installedPackage(store))

  copyFixture(fixtureRoot, consumer)
  discard run("nimble install -y --nimbleDir:" & quoteShell(store), consumer)
  let consumerBinary = consumer / "build" / "bin" / ("main" & ExeExt)
  let consumerCache = consumer / "build" / "nimcache"
  createDir(consumerBinary.parentDir())
  createDir(consumerCache)
  discard run("nimble c --skipParentCfg:on --nimbleDir:" & quoteShell(store) &
    " --out:" & quoteShell(consumerBinary) & " --nimcache:" &
    quoteShell(consumerCache) & " src/main.nim", consumer)
  let output = run(quoteShell(consumerBinary), consumer)
  doAssert output.strip == "isolated-consumer:ok", "unexpected output: " & output
  doAssert repositorySnapshot() == before
  echo "package-verification:ok"
