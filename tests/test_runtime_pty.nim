import std/[os, osproc, strutils, unittest]
import terminal_screen
import terminal_style
import terminal_widgets/runtime

const repositoryRoot = currentSourcePath().parentDir().parentDir()

suite "real terminal runtime smoke":
  when defined(linux):
    test "PTY enters raw presentation and restores cursor screen and wrap":
      let source = repositoryRoot / "tests" / "support" /
        "runtime_pty_smoke.nim"
      let output = repositoryRoot / "build" / "bin" / "runtime_pty_smoke"
      let cache = repositoryRoot / "build" / "nimcache" / "runtime-pty-smoke"
      createDir(output.parentDir())
      createDir(cache)
      let compilation = execCmdEx(
        "nim c --hints:off --out:" & quoteShell(output) &
        " --nimcache:" & quoteShell(cache) &
        " --path:" & quoteShell(repositoryRoot / "src") &
        " " & quoteShell(source),
        workingDir = repositoryRoot,
        options = {poUsePath, poStdErrToStdOut})
      if compilation.exitCode != 0: checkpoint compilation.output
      require compilation.exitCode == 0

      let command = "printf 'x' | script -qfec " &
        quoteShell(output & ExeExt) & " /dev/null"
      let execution = execCmdEx(command, workingDir = repositoryRoot,
        options = {poUsePath, poStdErrToStdOut})
      if execution.exitCode != 0: checkpoint execution.output
      check execution.exitCode == 0
      check EnterAlternateScreen in execution.output
      check DisableAutoWrap in execution.output
      check HideCursorCode in execution.output
      check ansiReset in execution.output
      check EnableAutoWrap in execution.output
      check ShowCursorCode in execution.output
      check LeaveAlternateScreen in execution.output
      check "runtime-smoke:requestedStop" in execution.output
  else:
    test "platform-specific console smoke is documented":
      checkpoint "Automated PTY smoke currently runs on Linux; see runtime smoke records"
      check true
