## Deterministic semantic control frames.
##
## The clipped tree compositor is completed in Phase 07; these control lines are
## its stable state/theme inputs and support early control snapshot coverage.

import std/options
import terminal_style
import terminal_widgets/[checkbox, menu, radio_group, scroll_list, selection,
  switch, tabs, theme, types, widget]

type RenderMetrics* = object
  ## Observable work counters used by rendering performance verification.
  visitedItems*: int

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

proc renderSelection(items: openArray[ChoiceItem]; active: Option[ItemId];
                     theme: WidgetTheme; focused, enabled: bool;
                     metrics: var RenderMetrics): seq[string] =
  if items.len == 0:
    return @[present("  (empty)", theme.disabled, theme)]
  for item in items:
    inc metrics.visitedItems
    let isActive = active == some(item.id)
    let line = prefix(focused and isActive, theme) & item.label
    let style =
      if not enabled or not item.enabled: theme.disabled
      elif focused and isActive: theme.focused
      elif isActive: theme.selected
      else: theme.normal
    result.add present(line, style, theme)

proc renderControl*(list: ScrollList; theme: WidgetTheme;
                    metrics: var RenderMetrics; focused = false;
                    enabled = true): seq[string] =
  ## Renders only list rows intersecting its allocated viewport.
  if list.allocation.isNone or list.allocation.get.height == 0: return @[]
  if list.itemCount == 0:
    return @[present("  (empty)", theme.disabled, theme)]
  renderSelection(list.visibleItems, list.selected, theme, focused, enabled,
    metrics)

proc renderControl*(list: ScrollList; theme: WidgetTheme;
                    focused = false; enabled = true): seq[string] =
  var metrics: RenderMetrics
  renderControl(list, theme, metrics, focused, enabled)

proc renderControl*(menu: Menu; theme: WidgetTheme;
                    metrics: var RenderMetrics; focused = false;
                    enabled = true): seq[string] =
  ## Renders only menu rows intersecting its allocated viewport.
  if menu.allocation.isNone or menu.allocation.get.height == 0: return @[]
  if menu.itemCount == 0:
    return @[present("  (empty)", theme.disabled, theme)]
  renderSelection(menu.visibleItems, menu.active, theme, focused, enabled,
    metrics)

proc renderControl*(menu: Menu; theme: WidgetTheme;
                    focused = false; enabled = true): seq[string] =
  var metrics: RenderMetrics
  renderControl(menu, theme, metrics, focused, enabled)

proc renderControl*(tabs: Tabs; theme: WidgetTheme;
                    focused = false; enabled = true): seq[string] =
  ## Renders the allocated, cell-clipped tab header. Brackets identify the
  ## active page in plain mode; parentheses identify disabled pages.
  let bounds = tabs.allocation
  if bounds.isNone or bounds.get.width == 0 or bounds.get.height == 0:
    return @[]
  var header = ""
  for index, page in tabs.pages:
    if index > 0:
      header.add present("|", theme.normal, theme)
    let active = tabs.active == some(page.id)
    let text =
      if active: "[" & page.label & "]"
      elif not page.enabled: "(" & page.label & ")"
      else: " " & page.label & " "
    let style =
      if not enabled or not page.enabled: theme.disabled
      elif focused and active: theme.focused
      elif active: theme.selected
      else: theme.normal
    header.add present(text, style, theme)
  @[padAnsi(sliceAnsi(header, tabs.headerOffset, bounds.get.width),
    bounds.get.width)]
