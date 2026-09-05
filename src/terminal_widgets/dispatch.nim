## Input routing and ordered widget event collection.

import std/options
import terminal_widgets/[composition, types, widget]

proc appendOutcome(target: var DispatchResult; source: DispatchResult) =
  target.needsRender = target.needsRender or source.needsRender
  for event in source.events:
    target.events.add event

proc dispatch*(tree: WidgetTree; input: InputEvent): DispatchResult =
  ## Routes one normalized event without invoking application callbacks.
  case input.kind
  of eventResize:
    return tree.layout(newSize(input.size.columns, input.size.rows))
  of eventTimeout, eventEndOfInput:
    return dispatchResult()
  of eventKey:
    case input.keyEvent.key
    of keyTab:
      return tree.moveFocus()
    of keyBacktab:
      return tree.moveFocus(backwards = true)
    else:
      discard

  if tree.focused.isNone:
    return dispatchResult()
  var currentId = tree.focused.get
  while true:
    let current = tree.nodeById(currentId)
    if current.isNil:
      return result
    let outcome = current.handleInput(input)
    result.appendOutcome(outcome)
    if outcome.handled:
      result.handled = true
      return
    let parent = tree.parentOf(currentId)
    if parent.isNone:
      return
    currentId = parent.get
