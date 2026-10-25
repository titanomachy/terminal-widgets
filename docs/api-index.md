.. title:: TerminalWidgets documentation

TerminalWidgets is a pure-Nim library for retained terminal controls, layout,
keyboard focus, and single-line text editing. Build a widget tree, dispatch
normalized input, and render a frame as ordinary strings, or opt into a guarded
interactive terminal session.

- [Complete model and rendering API](terminal_widgets.html)
- [Interactive runtime API](terminal_widgets/runtime.html)
- [Search all exported symbols](theindex.html)
- [Guides](#guides) and [runnable examples](#examples)
- [Package README](https://github.com/titanomachy/terminal-widgets#readme)

.. image:: images/interactive-form.gif
   :alt: A TerminalWidgets form with retained controls, keyboard focus, and validation

## Install

Use Nim 2.0.0 or newer on Linux, macOS, or Windows and install with Nimble:

```
nimble install https://github.com/titanomachy/terminal-widgets
```

Nimble also installs the TerminalStyle and TerminalScreen dependencies.
Import `terminal_widgets` for the model, layout, dispatch, and pure rendering
API. Importing the facade performs no terminal I/O.

## Quick start

Create a checkbox, give it a layout, dispatch Space, and render its updated state:

```nim
import terminal_widgets

let control = newCheckbox(newWidgetId("updates"), "Install updates")
let tree = newWidgetTree(control)
discard tree.layout(newSize(24, 1))
discard tree.dispatch(keyInput(keySpace))
echo tree.render(newSize(24, 1), plainWidgetTheme()).rows[0]
```

Save this as `checkbox.nim` and run `nim r checkbox.nim`. The frame shows the
checked control. Widgets retain their values between dispatches, and typed
events report user changes to the application. Programmatic setters update state
without synthesizing user events.

For an interactive application, explicitly import
[`terminal_widgets/runtime`](terminal_widgets/runtime.html) and pass the tree
to `runWidgets`. The runtime handles input, layout, full-frame presentation,
resize events, and terminal cleanup. The
[interactive-form example](https://github.com/titanomachy/terminal-widgets/blob/master/examples/interactive_form.nim)
shows validation and submission in a real terminal.

## API reference

Use the [facade reference](terminal_widgets.html) for the model and rendering
API, or browse the focused modules:

| Module | Use it for |
| --- | --- |
| [types](terminal_widgets/types.html) | Validated widget and item IDs, cell geometry, normalized input, and typed output events |
| [widget](terminal_widgets/widget.html) | Shared retained state, labels, visibility, enabled state, and revisions |
| [checkbox](terminal_widgets/checkbox.html) and [switch](terminal_widgets/switch.html) | Boolean controls |
| [radio_group](terminal_widgets/radio_group.html) | Exclusive keyed choices with a scrolling viewport |
| [scroll_list](terminal_widgets/scroll_list.html) and [menu](terminal_widgets/menu.html) | Keyed selection, navigation, and explicit activation |
| [tabs](terminal_widgets/tabs.html) | Keyed pages that retain their child widgets and values |
| [text_field](terminal_widgets/text_field.html) and [editor](terminal_widgets/editor.html) | Unicode-aware single-line editing, validation, and cursor geometry |
| [composition](terminal_widgets/composition.html) | Rows, columns, stacks, fixed/flex layout, and tree mutation |
| [focus](terminal_widgets/focus.html) and [dispatch](terminal_widgets/dispatch.html) | Depth-first keyboard focus and input routing |
| [render](terminal_widgets/render.html) and [theme](terminal_widgets/theme.html) | Pure frames, clipping, semantic styles, and character markers |
| [static_text](terminal_widgets/static_text.html) | Application text and companion-library string output |
| [runtime](terminal_widgets/runtime.html) | Owned or borrowed terminal sessions, event callbacks, idle updates, and cleanup |

Use the [symbol index](theindex.html) to find a particular type or procedure,
including the separately imported runtime API.

## Guides

These guides are maintained alongside the source on GitHub:

- [API guide](https://github.com/titanomachy/terminal-widgets/blob/master/docs/api.md):
  public types, controls, composition, rendering, and runtime entry points.
- [Behavior guide](https://github.com/titanomachy/terminal-widgets/blob/master/docs/behavior.md):
  key bindings, state ownership, Unicode boundaries, themes, and validation.
- [Runtime guide](https://github.com/titanomachy/terminal-widgets/blob/master/docs/runtime.md):
  owned and borrowed sessions, idle callbacks, termination, cleanup, and failures.

## Examples

Clone the repository and install dependencies with
`nimble install --depsOnly -y`. Run the following commands from the repository
root; each source link opens the runnable Nim file on GitHub.

| Example | Run from the repository root |
| --- | --- |
| [Checkbox](https://github.com/titanomachy/terminal-widgets/blob/master/examples/checkbox.nim) | `nim r --path:src examples/checkbox.nim` |
| [Basic controls](https://github.com/titanomachy/terminal-widgets/blob/master/examples/basic_controls.nim) | `nim r --path:src examples/basic_controls.nim` |
| [List and menu navigation](https://github.com/titanomachy/terminal-widgets/blob/master/examples/selection_navigation.nim) | `nim r --path:src examples/selection_navigation.nim` |
| [Retained tab pages](https://github.com/titanomachy/terminal-widgets/blob/master/examples/tabs_retained.nim) | `nim r --path:src examples/tabs_retained.nim` |
| [Text editing and validation](https://github.com/titanomachy/terminal-widgets/blob/master/examples/text_field_editing.nim) | `nim r --path:src examples/text_field_editing.nim` |
| [Layout and focus](https://github.com/titanomachy/terminal-widgets/blob/master/examples/composition_focus.nim) | `nim r --path:src examples/composition_focus.nim` |
| [Pure frame rendering](https://github.com/titanomachy/terminal-widgets/blob/master/examples/render_frame.nim) | `nim r --path:src examples/render_frame.nim` |
| [Interactive form](https://github.com/titanomachy/terminal-widgets/blob/master/examples/interactive_form.nim) | `nim r --path:src examples/interactive_form.nim` |
| [Idle updates](https://github.com/titanomachy/terminal-widgets/blob/master/examples/idle_updates.nim) | `nim r --path:src examples/idle_updates.nim` |

The interactive form and idle updates need a real terminal. The other examples
run without opening a terminal session. See the
[full example directory](https://github.com/titanomachy/terminal-widgets/tree/master/examples)
for more controls, composition, and runtime demonstrations.

## Generate locally

From a source checkout:

```
nimble docs
python3 -m http.server 8000 --directory build/docs
```

Open `http://localhost:8000` in your browser. Serving the documentation over
HTTP lets the generated API search load its index.
