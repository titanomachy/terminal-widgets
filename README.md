# terminal-widgets
Pure-nim Terminal Widgets: persistent, composable controls—radio groups, switches, tabs, checkboxes, menus, text fields, scrollable lists, and focus handling.

Part of TerminalDeck:

```text
TerminalDeck
├── Foundations
│   ├── TerminalStyle
│   └── TerminalScreen
├── Output components
│   ├── TerminalStatus
│   ├── TerminalLayout
│   ├── TerminalTable
│   └── TerminalGraph
└── Interaction
    ├── TerminalPrompt
    └── TerminalWidgets <- this package
```

## Requirements

- Nim 2.0.0 or newer
- TerminalStyle 0.1.1 or newer
- TerminalScreen 0.1.1 or newer

## Package foundation example

The current package-foundation example verifies that a consumer can import the
public facade without initializing a terminal session:

```console
nim r --path:src examples/package_import.nim
```

Widget APIs will be added in the implementation phases that follow the package
foundation.

## Development and documentation

Repository builds are contained in `build/`: executables go to `build/bin`,
compiler caches use a Nim-version and project-specific directory below
`build/nimcache`, generated API documentation goes to `build/docs`, and test
fixtures belong in `build/tmp`. This applies to direct commands run from the
repository root or a nested source directory.

Run the build-containment regression suite directly with:

```console
nim c -r --path:src tests/test_build_containment.nim
```

The standard package checks are:

```console
nimble check
nimble compilePackage
nimble test
nimble examples
nimble docs
nimble releaseCheck
```

Command-line `--out` and `--nimcache` overrides take precedence over
`config.nims`; project automation must keep any such paths below `build/`.
