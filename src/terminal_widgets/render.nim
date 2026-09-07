## Pure full-frame rendering, clipping, sanitization, and composition.
##
## Rendering consumes an explicit layout and theme, performs no terminal I/O,
## and never mutates retained widget state. Full-frame presentation is the
## correctness baseline; incremental/diff presentation is intentionally absent.

import std/[options, strutils]
import terminal_style
import terminal_widgets/[checkbox, composition, menu, radio_group, scroll_list,
  selection, static_text, switch, tabs, text_field, text_policy, theme, types,
  widget]

type
  CursorCell* = object
    ## Zero-based cursor coordinates within a rendered frame.
    column*: int
    row*: int

  Frame* = object
    ## A complete rectangular terminal presentation without cursor commands.
    width*: int
    height*: int
    rows*: seq[string]
    cursor*: Option[CursorCell]

  RenderMetrics* = object
    ## Observable work counters used by rendering performance verification.
    visitedItems*: int

proc sanitizePlainText*(value: string): string =
  text_policy.sanitizePlainText(value)

proc trustedSgr(value: string; useColor: bool): string =
  for token in tokenizeAnsi(value):
    case token.kind
    of atkText:
      result.add sanitizePlainText(token.value)
    of atkCsi:
      if useColor and token.value.len > 0 and token.value[^1] == 'm':
        result.add token.value
    of atkOsc, atkEscape:
      discard
  if useColor and result.contains(ansiEscape): result.add ansiReset

proc present(value: string; style: TerminalStyle; theme: WidgetTheme): string =
  applyStyle(value, style, enabled = theme.useColor)

proc prefix(focused, enabled: bool; theme: WidgetTheme): string =
  let marker = if not enabled: theme.disabledMarker
               elif focused: theme.focusMarker
               else: spaces(displayWidth(theme.focusMarker))
  marker & " "

proc safeWindow(value: string; startCell, width: int): string =
  ## Produces an exact-width cell window, blanking a glyph cut at either edge.
  if width <= 0: return ""
  let before = displayWidth(sliceAnsi(value, 0, startCell))
  let leading = max(0, startCell - before)
  let body = sliceAnsi(value, startCell, max(0, width - leading))
  padAnsi(spaces(leading) & body, width)

proc renderControl*(checkbox: Checkbox; theme: WidgetTheme;
                    focused = false; enabled = true): seq[string] =
  theme.validateTheme()
  let marker = if checkbox.checked: theme.checkboxOnMarker
               else: theme.checkboxOffMarker
  let line = prefix(focused, enabled, theme) & marker & " " &
    sanitizePlainText(checkbox.label)
  let style = if enabled: (if focused: theme.focused else: theme.normal)
              else: theme.disabled
  @[present(line, style, theme)]

proc renderControl*(switch: Switch; theme: WidgetTheme;
                    focused = false; enabled = true): seq[string] =
  theme.validateTheme()
  let marker = if switch.isOn: theme.switchOnMarker else: theme.switchOffMarker
  let line = prefix(focused, enabled, theme) & marker & " " &
    sanitizePlainText(switch.label)
  let style = if enabled: (if focused: theme.focused else: theme.normal)
              else: theme.disabled
  @[present(line, style, theme)]

proc renderControl*(group: RadioGroup; theme: WidgetTheme;
                    metrics: var RenderMetrics; focused = false;
                    enabled = true): seq[string] =
  theme.validateTheme()
  let bounds = group.allocation
  if bounds.isSome and bounds.get.height == 0: return @[]
  let items = if bounds.isSome: group.visibleItems else: group.items
  for item in items:
    inc metrics.visitedItems
    let selected = group.selected == some(item.id)
    let active = focused and group.active == some(item.id)
    let marker = if selected: theme.radioOnMarker else: theme.radioOffMarker
    let line = prefix(active, enabled and item.enabled, theme) & marker & " " &
      sanitizePlainText(item.label)
    let style =
      if not enabled or not item.enabled: theme.disabled
      elif active: theme.focused
      elif selected: theme.selected
      else: theme.normal
    result.add present(line, style, theme)

proc renderControl*(group: RadioGroup; theme: WidgetTheme;
                    focused = false; enabled = true): seq[string] =
  var metrics: RenderMetrics
  renderControl(group, theme, metrics, focused, enabled)

proc renderSelection(items: openArray[ChoiceItem]; active: Option[ItemId];
                     theme: WidgetTheme; focused, enabled: bool;
                     metrics: var RenderMetrics): seq[string] =
  if items.len == 0:
    return @[present("  (empty)", theme.disabled, theme)]
  for item in items:
    inc metrics.visitedItems
    let isActive = active == some(item.id)
    let line = prefix(focused and isActive, enabled and item.enabled, theme) &
      sanitizePlainText(item.label)
    let style =
      if not enabled or not item.enabled: theme.disabled
      elif focused and isActive: theme.focused
      elif isActive: theme.selected
      else: theme.normal
    result.add present(line, style, theme)

proc renderControl*(list: ScrollList; theme: WidgetTheme;
                    metrics: var RenderMetrics; focused = false;
                    enabled = true): seq[string] =
  theme.validateTheme()
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
  theme.validateTheme()
  if menu.allocation.isNone or menu.allocation.get.height == 0: return @[]
  if menu.itemCount == 0:
    return @[present("  (empty)", theme.disabled, theme)]
  renderSelection(menu.visibleItems, menu.active, theme, focused, enabled,
    metrics)

proc renderControl*(menu: Menu; theme: WidgetTheme;
                    focused = false; enabled = true): seq[string] =
  var metrics: RenderMetrics
  renderControl(menu, theme, metrics, focused, enabled)

proc tabHeader(tabs: Tabs; theme: WidgetTheme; focused, enabled: bool): string =
  for index, page in tabs.pages:
    if index > 0: result.add present("|", theme.accent, theme)
    let active = tabs.active == some(page.id)
    let label = sanitizePlainText(page.label)
    let text = if active: "[" & label & "]"
               elif not page.enabled: "(" & label & ")"
               else: " " & label & " "
    let style =
      if not enabled or not page.enabled: theme.disabled
      elif focused and active: theme.focused
      elif active: theme.selected
      else: theme.normal
    result.add present(text, style, theme)

proc renderControl*(tabs: Tabs; theme: WidgetTheme;
                    focused = false; enabled = true): seq[string] =
  theme.validateTheme()
  let bounds = tabs.allocation
  if bounds.isNone or bounds.get.width == 0 or bounds.get.height == 0:
    return @[]
  @[safeWindow(tabHeader(tabs, theme, focused, enabled), tabs.headerOffset,
    bounds.get.width)]

proc intersect(left, right: Rect): Option[Rect] =
  let x = max(left.x, right.x)
  let y = max(left.y, right.y)
  let rightEdge = min(left.x + left.width, right.x + right.width)
  let bottom = min(left.y + left.height, right.y + right.height)
  if rightEdge <= x or bottom <= y: return none(Rect)
  some(newRect(x, y, rightEdge - x, bottom - y))

proc place(rows: var seq[string]; bounds, clip: Rect;
           content: openArray[string]; frameWidth: int) =
  let visible = intersect(bounds, clip)
  if visible.isNone: return
  let area = visible.get
  for y in area.y ..< area.y + area.height:
    let localY = y - bounds.y
    let source = if localY < content.len: content[localY] else: ""
    let localX = area.x - bounds.x
    let replacement = safeWindow(source, localX, area.width)
    let before = safeWindow(rows[y], 0, area.x)
    let after = safeWindow(rows[y], area.x + area.width,
      frameWidth - area.x - area.width)
    rows[y] = before & replacement & after

proc blank(rows: var seq[string]; bounds, clip: Rect; frameWidth: int) =
  var empty: seq[string]
  empty.setLen(bounds.height)
  rows.place(bounds, clip, empty, frameWidth)

proc matchesLayout(widget: Widget; effectiveVisible = true): bool =
  let visible = effectiveVisible and widget.visible
  if not visible: return widget.allocation.isNone
  if widget.allocation.isNone: return false
  let interactive = widget.interactionChildren()
  for child in widget.childWidgets():
    var active = false
    for candidate in interactive:
      if candidate == child: active = true
    if active:
      if not matchesLayout(child, visible): return false
    elif child.allocation.isSome:
      return false
  true

proc render*(tree: WidgetTree; size: Size; theme: WidgetTheme): Frame =
  ## Renders the latest explicit layout or rejects stale/mismatched geometry.
  theme.validateTheme()
  var frame = Frame(width: size.width, height: size.height,
    rows: newSeq[string](size.height), cursor: none(CursorCell))
  for row in 0 ..< size.height: frame.rows[row] = spaces(size.width)
  if tree.isNil or tree.root.isNil:
    raise newException(ValueError, "widget tree must not be nil")
  if tree.layoutSize != some(size) or not matchesLayout(tree.root):
    raise newException(ValueError,
      "render size must match a current explicit widget-tree layout")
  if size.width == 0 or size.height == 0: return frame
  let frameBounds = newRect(0, 0, size.width, size.height)

  proc draw(current: Widget; clip: Rect; ancestorEnabled: bool) =
    if not current.visible or current.allocation.isNone: return
    let bounds = current.allocation.get
    let clipped = intersect(bounds, clip)
    if clipped.isNone: return
    let enabled = ancestorEnabled and current.enabled
    let focused = enabled and tree.focused == some(current.id)

    if current of Container:
      let container = Container(current)
      for child in container.interactionChildren():
        if container.kind == stackContainer and child.allocation.isSome:
          frame.rows.blank(child.allocation.get, clipped.get, size.width)
        draw(child, clipped.get, enabled)
      return

    if current of Tabs:
      let control = Tabs(current)
      frame.rows.place(bounds, clipped.get,
        renderControl(control, theme, focused, enabled), size.width)
      for child in control.interactionChildren(): draw(child, clipped.get, enabled)
      return

    var lines: seq[string]
    if current of Checkbox:
      lines = renderControl(Checkbox(current), theme, focused, enabled)
    elif current of Switch:
      lines = renderControl(Switch(current), theme, focused, enabled)
    elif current of RadioGroup:
      lines = renderControl(RadioGroup(current), theme, focused, enabled)
    elif current of ScrollList:
      lines = renderControl(ScrollList(current), theme, focused, enabled)
    elif current of Menu:
      lines = renderControl(Menu(current), theme, focused, enabled)
    elif current of TextField:
      let field = TextField(current)
      let lead = prefix(focused, enabled, theme) &
        (if field.label.len > 0: sanitizePlainText(field.label) & ": " else: "")
      let available = field.contentWidth(theme)
      let offset = field.horizontalOffset(theme)
      let source = if field.value.len == 0: sanitizePlainText(field.placeholder)
                   else: field.value
      let contentStyle =
        if not enabled: theme.disabled
        elif field.validationError.isSome: theme.error
        elif field.value.len == 0: theme.placeholder
        elif focused: theme.focused
        else: theme.normal
      lines.add present(lead, if enabled: theme.normal else: theme.disabled,
        theme) & present(safeWindow(source, offset, available), contentStyle,
        theme)
      if field.validationError.isSome and bounds.height > 1:
        lines.add present(prefix(false, true, theme) &
          sanitizePlainText(field.validationError.get), theme.error, theme)
      if focused and available > 0:
        let cursor = field.cursorCell(theme)
        if cursor.isSome and cursor.get >= clipped.get.x and
            cursor.get < clipped.get.x + clipped.get.width:
          frame.cursor = some(CursorCell(column: cursor.get, row: bounds.y))
    elif current of StaticText:
      let text = StaticText(current)
      for rawLine in text.content.splitLines:
        let safe = if text.isTrustedStyled: trustedSgr(rawLine, theme.useColor)
                   else: present(sanitizePlainText(rawLine), theme.normal, theme)
        lines.add safe
      if lines.len == 0: lines.add ""
    frame.rows.place(bounds, clipped.get, lines, size.width)

  draw(tree.root, frameBounds, true)
  if theme.useColor:
    for index in 0 ..< frame.rows.len:
      frame.rows[index].add ansiReset
  result = move(frame)
