## Persistent tab page and header model.

import std/[options, sets]
import terminal_style
import terminal_widgets/[types, widget]

type
  TabPage* = object
    ## One keyed page whose child root keeps retained widget identity.
    idValue: ItemId
    labelValue: string
    enabledValue: bool
    childValue: Widget

  Tabs* = ref object of Widget
    pagesValue: seq[TabPage]
    activeValue: Option[ItemId]
    headerOffsetValue: int

proc newTabPage*(id: ItemId; label: string; child: Widget;
                 enabled = true): TabPage =
  id.requireValid()
  if child.isNil:
    raise newException(ValueError, "tab page child must not be nil")
  TabPage(idValue: id, labelValue: label, enabledValue: enabled,
    childValue: child)

proc id*(page: TabPage): ItemId = page.idValue
proc label*(page: TabPage): string = page.labelValue
proc enabled*(page: TabPage): bool = page.enabledValue
proc child*(page: TabPage): Widget = page.childValue

proc setLabel*(page: var TabPage; value: string) = page.labelValue = value
proc setEnabled*(page: var TabPage; value: bool) = page.enabledValue = value

proc snapshotTabPages*(pages: openArray[TabPage]): seq[TabPage] =
  ## Internal snapshot helper used by tree-managed page replacement.
  result = newSeqOfCap[TabPage](pages.len)
  for page in pages:
    result.add page

proc validateTabPages*(pages: openArray[TabPage]) =
  ## Internal validation shared by detached and tree-managed replacement.
  var seen = initHashSet[ItemId]()
  for page in pages:
    page.id.requireValid()
    if page.child.isNil:
      raise newException(ValueError, "tab page child must not be nil")
    if page.id in seen:
      raise newException(ValueError, "duplicate tab page ID: " & $page.id)
    seen.incl page.id

proc firstEnabled(pages: openArray[TabPage]): Option[ItemId] =
  for page in pages:
    if page.enabled:
      return some(page.id)
  none(ItemId)

proc newTabs*(id: WidgetId; pages: openArray[TabPage]): Tabs =
  validateTabPages(pages)
  new result
  result.initializeWidgetState(id, "")
  result.pagesValue = snapshotTabPages(pages)
  result.activeValue = firstEnabled(pages)

proc pages*(tabs: Tabs): seq[TabPage] = snapshotTabPages(tabs.pagesValue)
proc active*(tabs: Tabs): Option[ItemId] = tabs.activeValue
proc headerOffset*(tabs: Tabs): int = tabs.headerOffsetValue

proc accepts(pages: openArray[TabPage]; id: ItemId): bool =
  for page in pages:
    if page.id == id: return page.enabled

proc pageIndex(pages: openArray[TabPage]; id: ItemId): int =
  for index, page in pages:
    if page.id == id: return index
  -1

proc replacement(pages, oldPages: openArray[TabPage];
                 previous: Option[ItemId]): Option[ItemId] =
  if previous.isSome and pages.accepts(previous.get):
    return previous
  if pages.len == 0:
    return none(ItemId)
  var oldIndex = 0
  if previous.isSome:
    let found = oldPages.pageIndex(previous.get)
    if found >= 0: oldIndex = found
  let start = min(oldIndex, pages.high)
  for index in start .. pages.high:
    if pages[index].enabled: return some(pages[index].id)
  if start > 0:
    for index in countdown(start - 1, 0):
      if pages[index].enabled: return some(pages[index].id)
  none(ItemId)

proc tabPageChildren*(pages: openArray[TabPage]): seq[Widget] =
  ## Internal child projection used by composition ownership validation.
  result = newSeqOfCap[Widget](pages.len)
  for page in pages:
    result.add page.child

proc applyTabPages*(tabs: Tabs; pages: openArray[TabPage]) =
  ## Internal mutation hook; callers must validate ownership before invoking it.
  let stored = snapshotTabPages(pages)
  let nextActive = replacement(stored, tabs.pagesValue, tabs.activeValue)
  if tabs.pagesValue != stored or tabs.activeValue != nextActive:
    tabs.pagesValue = stored
    tabs.activeValue = nextActive
    tabs.headerOffsetValue = 0
    tabs.touchWidgetState()

proc setPages*(tabs: Tabs; pages: openArray[TabPage]) =
  ## Atomically replaces pages while detached, preserving an eligible active ID.
  ## Attached tabs must use ``WidgetTree.replacePages`` so descendants remain
  ## registered and focus can be repaired.
  if tabs.isNil:
    raise newException(ValueError, "tabs must not be nil")
  if tabs.isTreeOwned:
    raise newException(ValueError, "cannot replace pages of attached tabs")
  validateTabPages(pages)
  tabs.applyTabPages(pages)

proc setActive*(tabs: Tabs; value: Option[ItemId]) =
  ## Programmatically selects an enabled tab without emitting a user event.
  if value.isSome and not tabs.pagesValue.accepts(value.get):
    raise newException(ValueError, "active tab must exist and be enabled")
  if tabs.activeValue != value:
    tabs.activeValue = value
    tabs.touchWidgetState()

proc enabledIds(tabs: Tabs): seq[ItemId] =
  for page in tabs.pagesValue:
    if page.enabled: result.add page.id

proc moveActive(tabs: Tabs; key: Key): bool =
  let ids = tabs.enabledIds()
  if ids.len == 0: return false
  var index = if tabs.activeValue.isSome: ids.find(tabs.activeValue.get) else: 0
  if index < 0: index = 0
  let next = case key
    of keyArrowLeft: max(0, index - 1)
    of keyArrowRight: min(ids.high, index + 1)
    of keyHome: 0
    of keyEnd: ids.high
    else: index
  let value = some(ids[next])
  if tabs.activeValue != value:
    tabs.activeValue = value
    tabs.touchWidgetState()
    return true

method canFocus*(tabs: Tabs): bool = tabs.activeValue.isSome

method childWidgets*(tabs: Tabs): seq[Widget] =
  ## Exposes retained page roots to internal tree validation and traversal.
  result = newSeqOfCap[Widget](tabs.pagesValue.len)
  for page in tabs.pagesValue:
    result.add page.child

method interactionChildren*(tabs: Tabs): seq[Widget] =
  if tabs.activeValue.isSome:
    for page in tabs.pagesValue:
      if page.id == tabs.activeValue.get:
        return @[page.child]

method childContentBounds*(tabs: Tabs; bounds: Rect): Rect =
  let headerHeight = min(1, bounds.height)
  newRect(bounds.x, bounds.y + headerHeight, bounds.width,
    bounds.height - headerHeight)

method afterAllocation*(tabs: Tabs) =
  let bounds = tabs.allocation
  if bounds.isNone or bounds.get.width == 0 or tabs.activeValue.isNone:
    tabs.headerOffsetValue = 0
    return
  var cursor = 0
  var activeStart = 0
  var activeEnd = 0
  for index, page in tabs.pagesValue:
    let width = displayWidth(" " & page.label & " ")
    if page.id == tabs.activeValue.get:
      activeStart = cursor
      activeEnd = cursor + width
    cursor += width
    if index < tabs.pagesValue.high: inc cursor
  let viewport = bounds.get.width
  let maximum = max(0, cursor - viewport)
  tabs.headerOffsetValue = min(tabs.headerOffsetValue, maximum)
  if activeEnd - activeStart > viewport:
    tabs.headerOffsetValue = min(activeStart, maximum)
  elif activeStart < tabs.headerOffsetValue:
    tabs.headerOffsetValue = activeStart
  elif activeEnd > tabs.headerOffsetValue + viewport:
    tabs.headerOffsetValue = min(maximum, activeEnd - viewport)

method handleInput*(tabs: Tabs; input: InputEvent): DispatchResult =
  if input.kind != eventKey:
    return
  if input.keyEvent.key in {keyEnter, keySpace}:
    result.handled = tabs.activeValue.isSome
    return
  if input.keyEvent.key notin {keyArrowLeft, keyArrowRight, keyHome, keyEnd}:
    return
  result.handled = true
  if tabs.moveActive(input.keyEvent.key):
    tabs.afterAllocation()
    result.needsRender = true
    result.events.add WidgetEvent(kind: selectionChanged, source: tabs.id,
      selection: tabs.activeValue)

method inputInvalidatesLayout*(tabs: Tabs; input: InputEvent;
                               outcome: DispatchResult): bool =
  outcome.needsRender and input.kind == eventKey and input.keyEvent.key in {
    keyArrowLeft, keyArrowRight, keyHome, keyEnd}
