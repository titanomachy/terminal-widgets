## Deterministic semantic control frames.
##
## The clipped tree compositor is completed in Phase 07; these control lines are
## its stable state/theme inputs and support early control snapshot coverage.

import std/options
import terminal_style
import terminal_widgets/[checkbox, radio_group, selection, switch, theme, widget]

proc present(value: string; style: TerminalStyle; theme: WidgetTheme): string =
  applyStyle(value, style, enabled = theme.useColor)

proc prefix(focused: bool; theme: WidgetTheme): string =
  (if focused: theme.focusMarker else: " ") & " "

proc renderControl*(checkbox: Checkbox; theme: WidgetTheme;
                    focused = false; enabled = true): seq[string] =
  ## Renders one deterministic checkbox control line.
  let line = prefix(focused, theme) & checkbox.marker & " " & checkbox.label
  let style = if enabled: (if focused: theme.focused else: theme.normal)
              else: theme.disabled
  @[present(line, style, theme)]

proc renderControl*(switch: Switch; theme: WidgetTheme;
                    focused = false; enabled = true): seq[string] =
  ## Renders one deterministic switch control line.
  let line = prefix(focused, theme) & switch.marker & " " & switch.label
  let style = if enabled: (if focused: theme.focused else: theme.normal)
              else: theme.disabled
  @[present(line, style, theme)]

proc renderControl*(group: RadioGroup; theme: WidgetTheme;
                    focused = false; enabled = true): seq[string] =
  ## Renders deterministic radio lines with separate active/selected markers.
  for item in group.items:
    let selected = group.selected == some(item.id)
    let active = focused and group.active == some(item.id)
    let marker = if selected: theme.radioOnMarker else: theme.radioOffMarker
    let line = prefix(active, theme) & marker & " " & item.label
    let style =
      if not enabled or not item.enabled: theme.disabled
      elif active: theme.focused
      elif selected: theme.selected
      else: theme.normal
    result.add present(line, style, theme)
