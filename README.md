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
