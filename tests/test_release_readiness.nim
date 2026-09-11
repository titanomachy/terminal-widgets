import std/[os, strutils, unittest]

const repositoryRoot = currentSourcePath().parentDir().parentDir()
const manifest = staticRead(repositoryRoot / "terminal_widgets.nimble")
const license = staticRead(repositoryRoot / "LICENSE")
const notices = staticRead(repositoryRoot / "THIRD_PARTY_NOTICES.md")
const releaseNotes = staticRead(repositoryRoot / "RELEASE_NOTES.md")
const readme = staticRead(repositoryRoot / "README.md")
const changelog = staticRead(repositoryRoot / "CHANGELOG.md")

suite "release readiness metadata":
  test "license and dependency notices are complete":
    check license.splitLines()[0] == "MIT License"
    check "Copyright (c) 2026 titanomachy" in license
    check "the software is provided \"as is\"" in license.toLowerAscii
    check "TerminalStyle" in notices
    check "TerminalScreen" in notices
    check "https://github.com/titanomachy/terminal-style" in notices
    check "https://github.com/titanomachy/terminal-screen" in notices
    check notices.count("License: MIT") == 2

  test "manifest pins floors and excludes non-package working directories":
    check "version = \"0.1.0\"" in manifest
    check "requires \"nim >= 2.0.0\"" in manifest
    check "requires \"terminal_style >= 0.1.1\"" in manifest
    check "requires \"terminal_screen >= 0.1.1\"" in manifest
    check "srcDir = \"src\"" in manifest
    check "skipDirs = @[\"build\", \"specs\"]" in manifest
    check "bin =" notin manifest
    check "proc runReleaseStep" in manifest
    check "execution.exitCode != 0" in manifest

  test "release notes identify evidence limits and owner handoff":
    check "TerminalWidgets 0.1.0" in releaseNotes
    check "Nim 2.0.4 and 2.2.10" in releaseNotes
    check "complete hosted CI matrix passes" in releaseNotes
    check "macOS, and Windows" in releaseNotes
    check "repository owner" in releaseNotes
    check "publishing" in releaseNotes
    check "RELEASE_NOTES.md" in readme
    check "THIRD_PARTY_NOTICES.md" in readme
    check "docs/images/nim-terminal-ecosystem.svg" in readme
    check "### Release preparation" in changelog
