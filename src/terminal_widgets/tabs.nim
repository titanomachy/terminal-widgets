## Persistent tab page and header model.

import std/[options, sets]
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

proc snapshotPages(pages: openArray[TabPage]): seq[TabPage] =
  result = newSeqOfCap[TabPage](pages.len)
  for page in pages:
    result.add page

proc validatePages(pages: openArray[TabPage]) =
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
  validatePages(pages)
  new result
  result.initializeWidgetState(id, "")
  result.pagesValue = snapshotPages(pages)
  result.activeValue = firstEnabled(pages)

proc pages*(tabs: Tabs): seq[TabPage] = snapshotPages(tabs.pagesValue)
proc active*(tabs: Tabs): Option[ItemId] = tabs.activeValue
