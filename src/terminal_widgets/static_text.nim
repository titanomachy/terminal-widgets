## Retained static text for composing application and companion-library output.

import terminal_widgets/[types, widget]

type StaticText* = ref object of Widget
  contentValue: string
  trustedStyledValue: bool

proc newStaticText*(id: WidgetId; content: string): StaticText =
  ## Creates plain, untrusted static content sanitized by the renderer.
  new result
  result.initializeWidgetState(id, "")
  result.contentValue = content

proc newTrustedStyledText*(id: WidgetId; content: string): StaticText =
  ## Creates content whose SGR styling may be retained by the renderer.
  ## Other terminal protocols and unsafe text controls are always removed.
  new result
  result.initializeWidgetState(id, "")
  result.contentValue = content
  result.trustedStyledValue = true

proc content*(text: StaticText): string = text.contentValue
proc isTrustedStyled*(text: StaticText): bool = text.trustedStyledValue

proc setContent*(text: StaticText; value: string) =
  if text.contentValue != value:
    text.contentValue = value
    text.touchWidgetState()
