# 00 — Package and build contracts

Traceability: Phase 00, 09.A.02, 10.B.01.

## Layout

```text
terminal_widgets.nimble       # package metadata and developer tasks
config.nims                  # repository compiler output policy
src/terminal_widgets.nim     # public facade, created during implementation
src/terminal_widgets/        # modules listed in 01-core
tests/test_*.nim             # executable suites
tests/support/               # shared fixtures and runtime doubles
examples/*.nim               # independently compilable entry points
docs/                        # authored documentation only
                       # plan, progress, eventual review
specs/                       # implementation contracts
build/bin/                   # compiled executable output
build/nimcache/              # generated C, objects and compiler metadata
build/docs/                  # generated API documentation
build/reports/               # coverage and benchmark output
build/tmp/                   # generated test inputs and terminal transcripts
```

The handoff creates only the manifest, root config, ignore rule, plans, and specs.
Create library sources in Phase 00. Preserve existing README and SVG content
until the documented README expansion in Phase 10.

## Build rules

Use Nim >= 2.0.0, TerminalStyle >= 0.1.1, and TerminalScreen >= 0.1.1. Keep the
manifest and source imports aligned. Library packages have no `bin` executable
declaration; `compilePackage` verifies the facade by compiling it explicitly.
`nimble build` is not the documented library verification command.

Root `config.nims` sets `outDir` to `build/bin` and `nimcache` to
`build/nimcache/nim-<version>/<project>`. Avoid duplicate test/example basenames.
Sequential builds may reuse a cache; concurrent jobs must use separate checkouts
or explicit cache directories beneath `build/` for target, backend and memory
manager. Direct nested-source compilation must load the root configuration.

All task-specific paths must remain under `build/`. Tests that spawn compiler
processes must pass an explicit cache and output path there. CLI output overrides
take precedence over config, so project tasks must not override them outside
`build/`. Do not redirect compiler-owned documentation helpers into a path where
the documentation generator cannot find them; use the documented `docs` task's
parent-config isolation and test actual HTML generation on the minimum compiler.

The manifest excludes build/planning directories from installation. Inspect the
installed package to verify no executables, caches, transcripts, or reports ship.
Dependency downloads normally belong to Nimble's own store; when isolating it,
pass `--nimbleDir:build/nimble`. Do not commit local dependency paths or credentials.

## Task contracts and commands

After sources exist and dependencies are available:

```sh
nimble install --depsOnly
nimble check
nimble compilePackage
nimble test
nimble examples
nimble docs
nimble releaseCheck
```

`test` runs each top-level `test_*.nim` suite and fails when none exist; support
modules are not standalone tests. `examples` compiles, without running an input
loop. Missing source directories/facade cause a clear nonzero failure. Add
`testArc`, `testOrc`, and `benchmark` in Phase 09, then include required memory
manager checks in CI. Do not let an empty suite report release readiness.

Direct command acceptance cases:

```sh
nim c --path:src examples/checkbox.nim
nim c -r --path:src tests/test_core.nim
nim r --path:src examples/headless_form.nim
```

With a clean source tree, compare files before/after these commands and all Nimble
tasks, including docs. Newly generated artifacts must be exclusively beneath
`build/`. Repeat one compile from `examples/` to verify working-directory
independence. Add an automated regression check for this policy. A downstream
consumer must compile with its own output config, unaffected by this repository's
development output policy.

References: Nim's [compiler options and configuration](https://nim-lang.org/docs/nimc.html)
define `outdir` and `nimcache`; [Nimble tasks](https://github.com/nim-lang/nimble#nimble-tasks)
define the task mechanism. These settings govern compiler outputs, not all
possible files written by an application at runtime.

## Planning-handoff validation — 2026-09-05

Verified on Linux using temporary probe source under `build/tmp/`:

- Nimble 0.24.0 `dump` and `tasks` parse the manifest and list all five tasks.
- Nim 2.2.10 `c -r` and `r` compile/run successfully; binaries and generated C/object
  caches appear beneath `build/`. Compilation from a nested directory also loads
  the root config and uses the same checkout-relative output paths.
- Nim 2.0.4 `c -r` passes with its own versioned cache beneath `build/`.
- The documentation command used by the task generates probe HTML beneath
  `build/docs/` with both compilers, including parent-config isolation.
- All plan/spec relative links, heading anchors, Markdown fences and 70 unique
  TODO IDs were checked; all 12 numbered phases are present.

Full Nimble task execution is not verified: `compilePackage` with an isolated
`build/nimble` store attempted dependency resolution before executing its body and
failed SSL certificate verification for `packages.nim-lang.org`. No SSL checks
were disabled. Widget sources, tests, examples and dependency integration remain
implementation work. These probe results do not establish Nim 2.0.0 compatibility,
Windows/macOS support, package installability, or completed library behavior.
