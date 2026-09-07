## Semantic widget theme definitions.

import terminal_style
import terminal_widgets/text_policy

type WidgetTheme* = object
  ## Semantic styles and markers used by deterministic widget presentation.
  useColor*: bool
  normal*: TerminalStyle
  focused*: TerminalStyle
  disabled*: TerminalStyle
  selected*: TerminalStyle
  placeholder*: TerminalStyle
  error*: TerminalStyle
  accent*: TerminalStyle
  focusMarker*: string
  disabledMarker*: string
  checkboxOffMarker*: string
  checkboxOnMarker*: string
  switchOffMarker*: string
  switchOnMarker*: string
  radioOffMarker*: string
  radioOnMarker*: string
  scrollUpMarker*: string
  scrollDownMarker*: string

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
    placeholder: initTerminalStyle(foreground = colorBrightBlack,
      attributes = {taItalic}),
    error: initTerminalStyle(foreground = colorRed,
      attributes = {taBold}),
    accent: initTerminalStyle(foreground = colorYellow),
    focusMarker: ">",
    disabledMarker: "!",
    checkboxOffMarker: "[ ]",
    checkboxOnMarker: "[x]",
    switchOffMarker: "[off]",
    switchOnMarker: "[on]",
    radioOffMarker: "( )",
    radioOnMarker: "(*)",
    scrollUpMarker: "^",
    scrollDownMarker: "v"
  )

proc plainWidgetTheme*(): WidgetTheme = defaultWidgetTheme(useColor = false)

proc unicodeWidgetTheme*(useColor = true): WidgetTheme =
  ## Returns the semantic default styles with optional Unicode markers.
  result = defaultWidgetTheme(useColor)
  result.focusMarker = "›"
  result.disabledMarker = "×"
  result.checkboxOffMarker = "☐"
  result.checkboxOnMarker = "☑"
  result.switchOffMarker = "○"
  result.switchOnMarker = "●"
  result.radioOffMarker = "○"
  result.radioOnMarker = "◉"
  result.scrollUpMarker = "▲"
  result.scrollDownMarker = "▼"

proc isValidMarker(value: string): bool =
  value.len > 0 and sanitizePlainText(value) == value and
    displayWidth(value) > 0

proc validateTheme*(theme: WidgetTheme) =
  ## Rejects unsafe or zero-cell markers before geometry or rendering uses them.
  for marker in [theme.focusMarker, theme.disabledMarker,
      theme.checkboxOffMarker,
      theme.checkboxOnMarker, theme.switchOffMarker, theme.switchOnMarker,
      theme.radioOffMarker, theme.radioOnMarker, theme.scrollUpMarker,
      theme.scrollDownMarker]:
    if not marker.isValidMarker:
      raise newException(ValueError,
        "theme markers must be printable single-line positive-width text")
