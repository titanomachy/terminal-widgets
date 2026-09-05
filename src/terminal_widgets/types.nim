## Core identifiers, geometry, input, event, and dispatch result types.
##
## These values are independent of terminal sessions. ``InputEvent`` and its
## related normalized keyboard types are re-exported from TerminalScreen's
## side-effect-free types module.

import std/[hashes, options]
import terminal_screen/types as screen_types

export screen_types

type
  WidgetId* = distinct string
    ## Stable identity of one widget.

  ItemId* = distinct string
    ## Stable identity of one item within a keyed control.

  Rect* = object
    ## A zero-based rectangle measured in terminal cells.
    xValue, yValue, widthValue, heightValue: int

  Size* = object
    ## A nonnegative viewport size measured in terminal cells.
    widthValue, heightValue: int

  WidgetEventKind* = enum
    ## Typed application events returned after input dispatch.
    boolChanged
    selectionChanged
    textChanged
    activated
    submitted
    validationFailed
    focusChanged

  WidgetEvent* = object
    ## One typed output event. Event payloads are selected by ``kind``.
    source*: WidgetId
    case kind*: WidgetEventKind
    of boolChanged:
      boolValue*: bool
    of selectionChanged:
      selection*: Option[ItemId]
    of textChanged, submitted:
      text*: string
    of activated:
      item*: ItemId
    of validationFailed:
      validationMessage*: string
    of focusChanged:
      previousFocus*: Option[WidgetId]
      newFocus*: Option[WidgetId]

  DispatchResult* = object
    ## The complete, ordered outcome of one input or tree operation.
    handled*: bool
    needsRender*: bool
    events*: seq[WidgetEvent]

proc newWidgetId*(value: string): WidgetId =
  ## Constructs a nonempty widget ID.
  if value.len == 0:
    raise newException(ValueError, "widget ID must not be empty")
  WidgetId(value)

proc newItemId*(value: string): ItemId =
  ## Constructs a nonempty item ID.
  if value.len == 0:
    raise newException(ValueError, "item ID must not be empty")
  ItemId(value)

proc `$`*(value: WidgetId): string {.borrow.}
proc `$`*(value: ItemId): string {.borrow.}
proc `==`*(left, right: WidgetId): bool {.borrow.}
proc `==`*(left, right: ItemId): bool {.borrow.}
proc hash*(value: WidgetId): Hash {.borrow.}
proc hash*(value: ItemId): Hash {.borrow.}

proc requireValid*(value: WidgetId) =
  ## Raises ``ValueError`` when a caller supplied an empty converted ID.
  if string(value).len == 0:
    raise newException(ValueError, "widget ID must not be empty")

proc requireValid*(value: ItemId) =
  ## Raises ``ValueError`` when a caller supplied an empty converted ID.
  if string(value).len == 0:
    raise newException(ValueError, "item ID must not be empty")

proc newRect*(x, y, width, height: int): Rect =
  ## Constructs a rectangle and rejects negative or overflowing extents.
  if x < 0 or y < 0:
    raise newException(ValueError, "rectangle position must be nonnegative")
  if width < 0 or height < 0:
    raise newException(ValueError, "rectangle dimensions must be nonnegative")
  if width > high(int) - x or height > high(int) - y:
    raise newException(ValueError, "rectangle extent overflows int")
  Rect(xValue: x, yValue: y, widthValue: width, heightValue: height)

proc x*(value: Rect): int = value.xValue
proc y*(value: Rect): int = value.yValue
proc width*(value: Rect): int = value.widthValue
proc height*(value: Rect): int = value.heightValue

proc newSize*(width, height: int): Size =
  ## Constructs a viewport size. Zero-sized viewports are valid.
  if width < 0 or height < 0:
    raise newException(ValueError, "size dimensions must be nonnegative")
  Size(widthValue: width, heightValue: height)

proc width*(value: Size): int = value.widthValue
proc height*(value: Size): int = value.heightValue

proc dispatchResult*(handled = false; needsRender = false;
                     events: sink seq[WidgetEvent] = @[]): DispatchResult =
  ## Constructs a dispatch result, preserving event order.
  DispatchResult(handled: handled, needsRender: needsRender, events: events)
