## Standalone public-facade consumer compiled by test_core_contracts.nim.

import std/options
import terminal_widgets

let checkbox = newCheckbox(newWidgetId("alerts"), "Alerts")
let root = newColumn(newWidgetId("root"), [Widget(checkbox)])
discard newWidgetTree(root)

let input: InputEvent = keyInput(keyEnter)
doAssert input.kind == eventKey

let events = @[
  WidgetEvent(kind: boolChanged, source: checkbox.id, boolValue: true),
  WidgetEvent(kind: selectionChanged, source: checkbox.id,
    selection: none(ItemId)),
  WidgetEvent(kind: textChanged, source: checkbox.id, text: "changed"),
  WidgetEvent(kind: activated, source: checkbox.id, item: newItemId("item")),
  WidgetEvent(kind: submitted, source: checkbox.id, text: "submitted"),
  WidgetEvent(kind: validationFailed, source: checkbox.id,
    validationMessage: "invalid"),
  WidgetEvent(kind: focusChanged, source: checkbox.id,
    previousFocus: none(WidgetId), newFocus: some(checkbox.id))
]
let outcome = dispatchResult(handled = true, needsRender = true, events = events)
doAssert outcome.events.len == 7

echo "consumer-ok"
