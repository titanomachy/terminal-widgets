## Semantic widget theme definitions.

import terminal_style

type WidgetTheme* = object
  ## Semantic styles and markers used by deterministic widget presentation.
  useColor*: bool
  normal*: TerminalStyle
  focused*: TerminalStyle
  disabled*: TerminalStyle
  selected*: TerminalStyle
  focusMarker*: string
  radioOffMarker*: string
  radioOnMarker*: string

proc defaultWidgetTheme*(useColor = true): WidgetTheme =
  ## Returns the default theme with ASCII state markers.
  WidgetTheme(
    useColor: useColor,
    normal: initTerminalStyle(),
    focused: initTerminalStyle(foreground = colorCyan,
      attributes = {taBold}),
    disabled: initTerminalStyle(foreground = colorBrightBlack,
      attributes = {taDim}),
    selected: initTerminalStyle(foreground = colorGreen,
      attributes = {taBold}),
    focusMarker: ">",
    radioOffMarker: "( )",
    radioOnMarker: "(*)"
  )

proc plainWidgetTheme*(): WidgetTheme = defaultWidgetTheme(useColor = false)
