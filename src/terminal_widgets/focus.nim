## Pure depth-first focus traversal helpers.

import std/options
import terminal_widgets/[types, widget]

proc focusOrder*(root: Widget): seq[Widget] =
  ## Returns effectively visible/enabled focus stops with nonzero allocation.
  var widgets: seq[Widget]
  proc visit(current: Widget; ancestorVisible, ancestorEnabled: bool) =
    let visible = ancestorVisible and current.visible
    let enabled = ancestorEnabled and current.enabled
    if not visible:
      return
    let bounds = current.allocation
    if enabled and current.canFocus and bounds.isSome and
        bounds.get.width > 0 and bounds.get.height > 0:
      widgets.add current
    for child in current.interactionChildren():
      visit(child, visible, enabled)

  if not root.isNil:
    visit(root, true, true)
  result = move(widgets)

proc focusIds*(widgets: openArray[Widget]): seq[WidgetId] =
  result = newSeqOfCap[WidgetId](widgets.len)
  for widget in widgets:
    result.add widget.id
