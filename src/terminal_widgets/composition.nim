## Retained container and tree construction with atomic ownership validation.
##
## Layout allocation and tree-managed structural mutation are introduced in
## Phase 02. Detached containers may replace children before attachment.

import std/[options, sets, tables]
import terminal_widgets/[focus, tabs, types, widget]

type
  ContainerKind* = enum
    rowContainer
    columnContainer
    stackContainer

  Padding* = object
    topValue, rightValue, bottomValue, leftValue: int

  ChildSizingKind* = enum
    flexSizing
    fixedSizing

  ChildSizing* = object
    case kind*: ChildSizingKind
    of flexSizing:
      weight*: int
    of fixedSizing:
      cells*: int

  Container* = ref object of Widget
    kindValue: ContainerKind
    childrenValue: seq[Widget]
    paddingValue: Padding
    gapValue: int
    sizingValue: Table[WidgetId, ChildSizing]

  WidgetTree* = ref object
    rootValue: Widget
    nodesValue: Table[WidgetId, Widget]
    parentsValue: Table[WidgetId, Option[WidgetId]]
    focusValue: Option[WidgetId]
    focusOrderValue: seq[WidgetId]
    layoutSizeValue: Option[Size]

  GraphEntry = tuple[widget: Widget, parent: Option[WidgetId]]

proc newPadding*(top, right, bottom, left: int): Padding =
  if top < 0 or right < 0 or bottom < 0 or left < 0:
    raise newException(ValueError, "padding must be nonnegative")
  Padding(topValue: top, rightValue: right, bottomValue: bottom,
    leftValue: left)

proc newPadding*(all: int): Padding = newPadding(all, all, all, all)
proc top*(padding: Padding): int = padding.topValue
proc right*(padding: Padding): int = padding.rightValue
proc bottom*(padding: Padding): int = padding.bottomValue
proc left*(padding: Padding): int = padding.leftValue

proc flex*(weight = 1): ChildSizing =
  if weight <= 0:
    raise newException(ValueError, "flex weight must be positive")
  ChildSizing(kind: flexSizing, weight: weight)

proc fixed*(cells: int): ChildSizing =
  if cells < 0:
    raise newException(ValueError, "fixed size must be nonnegative")
  ChildSizing(kind: fixedSizing, cells: cells)

proc `==`*(left, right: ChildSizing): bool =
  if left.kind != right.kind:
    return false
  case left.kind
  of flexSizing: left.weight == right.weight
  of fixedSizing: left.cells == right.cells

proc copyChildren(children: openArray[Widget]): seq[Widget] =
  result = newSeqOfCap[Widget](children.len)
  for child in children:
    if child.isNil:
      raise newException(ValueError, "container child must not be nil")
    result.add child

proc validateGraph(root: Widget; prospectiveWidget: Widget = nil;
                   prospectiveChildren: seq[Widget] = @[];
                   rejectOwned = true): seq[GraphEntry] =
  ## Validates a complete prospective graph without mutating widget state.
  var visiting = initHashSet[pointer]()
  var visited = initHashSet[pointer]()
  var ids = initHashSet[WidgetId]()
  var entries: seq[GraphEntry]

  proc walk(current: Widget; parent: Option[WidgetId]) =
    if current.isNil:
      raise newException(ValueError, "widget tree nodes must not be nil")
    current.id.requireValid()
    let identity = cast[pointer](current)
    if identity in visiting:
      raise newException(ValueError, "widget tree must not contain cycles")
    if identity in visited:
      raise newException(ValueError, "widget must not be attached more than once")
    if current.id in ids:
      raise newException(ValueError, "duplicate widget ID: " & $current.id)
    if rejectOwned and current.isTreeOwned:
      raise newException(ValueError, "widget already belongs to a tree: " & $current.id)

    visiting.incl identity
    ids.incl current.id
    entries.add (current, parent)
    let children =
      if not prospectiveWidget.isNil and current == prospectiveWidget:
        prospectiveChildren
      else:
        current.childWidgets()
    for child in children:
      walk(child, some(current.id))
    visiting.excl identity
    visited.incl identity

  walk(root, none(WidgetId))
  result = move(entries)

proc newContainer(id: WidgetId; kind: ContainerKind;
                  children: openArray[Widget]): Container =
  let storedChildren = copyChildren(children)
  new result
  result.initializeWidgetState(id, "")
  discard validateGraph(result, result, storedChildren)
  result.kindValue = kind
  result.childrenValue = storedChildren
  result.paddingValue = newPadding(0)
  result.sizingValue = initTable[WidgetId, ChildSizing]()

proc newRow*(id: WidgetId; children: openArray[Widget] = []): Container =
  ## Constructs a retained row. Allocation is added in Phase 02.
  newContainer(id, rowContainer, children)

proc newColumn*(id: WidgetId; children: openArray[Widget] = []): Container =
  ## Constructs a retained column. Allocation is added in Phase 02.
  newContainer(id, columnContainer, children)

proc newStack*(id: WidgetId; children: openArray[Widget] = []): Container =
  ## Constructs a retained stack. Allocation is added in Phase 02.
  newContainer(id, stackContainer, children)

proc kind*(container: Container): ContainerKind = container.kindValue
proc padding*(container: Container): Padding = container.paddingValue
proc gap*(container: Container): int = container.gapValue

proc setPadding*(container: Container; value: Padding) =
  if container.paddingValue != value:
    container.paddingValue = value
    container.touchWidgetState()

proc setGap*(container: Container; value: int) =
  if value < 0:
    raise newException(ValueError, "container gap must be nonnegative")
  if container.gapValue != value:
    container.gapValue = value
    container.touchWidgetState()

proc setSizing*(container: Container; child: WidgetId; value: ChildSizing) =
  var found = false
  for candidate in container.childrenValue:
    if candidate.id == child:
      found = true
      break
  if not found:
    raise newException(ValueError, "sizing target is not a direct child: " & $child)
  if container.sizingValue.getOrDefault(child, flex()) != value:
    container.sizingValue[child] = value
    container.touchWidgetState()

proc sizing*(container: Container; child: WidgetId): ChildSizing =
  container.sizingValue.getOrDefault(child, flex())

proc children*(container: Container): seq[Widget] =
  ## Returns independent sequence storage; widget references retain identity.
  result = newSeqOfCap[Widget](container.childrenValue.len)
  for child in container.childrenValue:
    result.add child

method childWidgets*(container: Container): seq[Widget] =
  container.children

proc setChildren*(container: Container; children: openArray[Widget]) =
  ## Atomically replaces children on a detached container.
  ##
  ## Once attached, use the tree mutation operations introduced in Phase 02 so
  ## parent ownership and focus repair can be updated together.
  if container.isNil:
    raise newException(ValueError, "container must not be nil")
  if container.isTreeOwned:
    raise newException(ValueError, "cannot replace children of an attached container")
  let storedChildren = copyChildren(children)
  discard validateGraph(container, container, storedChildren)
  if container.childrenValue != storedChildren:
    container.childrenValue = storedChildren
    var retained = initTable[WidgetId, ChildSizing]()
    for child in storedChildren:
      if child.id in container.sizingValue:
        retained[child.id] = container.sizingValue[child.id]
    container.sizingValue = move(retained)
    container.touchWidgetState()

proc newWidgetTree*(root: Widget): WidgetTree =
  ## Atomically validates and takes ownership of a retained widget graph.
  let entries = validateGraph(root)
  new result
  result.rootValue = root
  result.nodesValue = initTable[WidgetId, Widget]()
  result.parentsValue = initTable[WidgetId, Option[WidgetId]]()
  result.focusValue = none(WidgetId)
  result.layoutSizeValue = none(Size)
  for entry in entries:
    result.nodesValue[entry.widget.id] = entry.widget
    result.parentsValue[entry.widget.id] = entry.parent
  for entry in entries:
    entry.widget.setTreeOwned(true)

proc root*(tree: WidgetTree): Widget = tree.rootValue
proc focused*(tree: WidgetTree): Option[WidgetId] = tree.focusValue
proc focusOrder*(tree: WidgetTree): seq[WidgetId] = tree.focusOrderValue
proc layoutSize*(tree: WidgetTree): Option[Size] = tree.layoutSizeValue

proc nodeById*(tree: WidgetTree; id: WidgetId): Widget =
  tree.nodesValue.getOrDefault(id)

proc parentOf*(tree: WidgetTree; id: WidgetId): Option[WidgetId] =
  tree.parentsValue.getOrDefault(id, none(WidgetId))

proc setFocused(tree: WidgetTree; value: Option[WidgetId]): DispatchResult =
  let previous = tree.focusValue
  if previous == value:
    return dispatchResult(handled = true)
  tree.focusValue = value
  result = dispatchResult(handled = true, needsRender = true)
  result.events.add WidgetEvent(kind: focusChanged, source: tree.rootValue.id,
    previousFocus: previous, newFocus: value)

proc requestFocus*(tree: WidgetTree; id: WidgetId): DispatchResult =
  ## Focuses one currently eligible widget or rejects the request atomically.
  if id notin tree.focusOrderValue:
    raise newException(ValueError, "widget is not currently focusable: " & $id)
  tree.setFocused(some(id))

proc moveFocus*(tree: WidgetTree; backwards = false): DispatchResult =
  ## Moves focus with wrapping; an empty or singleton order is handled once.
  if tree.focusOrderValue.len == 0:
    return dispatchResult(handled = true)
  if tree.focusOrderValue.len == 1:
    if tree.focusValue.isNone:
      return tree.setFocused(some(tree.focusOrderValue[0]))
    return dispatchResult(handled = true)
  var index = tree.focusOrderValue.find(
    if tree.focusValue.isSome: tree.focusValue.get else: tree.focusOrderValue[0])
  if index < 0: index = 0
  if backwards:
    index = (index - 1 + tree.focusOrderValue.len) mod tree.focusOrderValue.len
  else:
    index = (index + 1) mod tree.focusOrderValue.len
  tree.setFocused(some(tree.focusOrderValue[index]))

proc saturatingSubtract(value, amount: int): int =
  if amount >= value: 0 else: value - amount

proc inset(bounds: Rect; padding: Padding): Rect =
  let left = min(padding.left, bounds.width)
  let top = min(padding.top, bounds.height)
  let afterLeft = bounds.width - left
  let afterTop = bounds.height - top
  let width = saturatingSubtract(afterLeft, padding.right)
  let height = saturatingSubtract(afterTop, padding.bottom)
  newRect(bounds.x + left, bounds.y + top, width, height)

proc clearAllocations(widget: Widget) =
  widget.setAllocation(none(Rect))
  for child in widget.childWidgets():
    clearAllocations(child)

proc allocate(widget: Widget; bounds: Rect) =
  if not widget.visible:
    clearAllocations(widget)
    return
  widget.setAllocation(some(bounds))
  widget.afterAllocation()
  let children = widget.interactionChildren()
  if children.len == 0:
    return
  if widget of Container:
    let container = Container(widget)
    let content = inset(bounds, container.padding)
    if container.kind == stackContainer:
      for child in children:
        allocate(child, content)
      return

    var visibleChildren: seq[Widget]
    for child in children:
      if child.visible:
        visibleChildren.add child
      else:
        clearAllocations(child)
    if visibleChildren.len == 0:
      return
    let axisLength =
      if container.kind == rowContainer: content.width else: content.height
    var gapTotal = 0
    for index in 1 ..< visibleChildren.len:
      gapTotal = min(axisLength, gapTotal + min(container.gap,
        axisLength - gapTotal))
    var remaining = axisLength - gapTotal
    var lengths = newSeq[int](visibleChildren.len)
    var flexWeight = 0
    for index, child in visibleChildren:
      let rule = container.sizing(child.id)
      case rule.kind
      of fixedSizing:
        lengths[index] = min(rule.cells, remaining)
        remaining -= lengths[index]
      of flexSizing:
        if rule.weight > high(int) - flexWeight:
          raise newException(ValueError, "combined flex weight overflows int")
        flexWeight += rule.weight
    if flexWeight > 0:
      var assigned = 0
      for index, child in visibleChildren:
        let rule = container.sizing(child.id)
        if rule.kind == flexSizing:
          let remainder = remaining mod flexWeight
          if remainder != 0 and rule.weight > high(int) div remainder:
            raise newException(ValueError, "flex allocation overflows int")
          lengths[index] = (remaining div flexWeight) * rule.weight +
            (remainder * rule.weight div flexWeight)
          assigned += lengths[index]
      var leftover = remaining - assigned
      for index, child in visibleChildren:
        if leftover == 0: break
        if container.sizing(child.id).kind == flexSizing:
          inc lengths[index]
          dec leftover
    var cursor = if container.kind == rowContainer: content.x else: content.y
    for index, child in visibleChildren:
      let childBounds =
        if container.kind == rowContainer:
          newRect(cursor, content.y, lengths[index], content.height)
        else:
          newRect(content.x, cursor, content.width, lengths[index])
      allocate(child, childBounds)
      cursor += lengths[index]
      if index < visibleChildren.high:
        cursor += min(container.gap,
          (if container.kind == rowContainer: content.x + content.width
           else: content.y + content.height) - cursor)
  else:
    let content = widget.childContentBounds(bounds)
    for child in children:
      allocate(child, content)

proc layout*(tree: WidgetTree; size: Size): DispatchResult =
  ## Stores bounded allocations and silently chooses the initial focus.
  clearAllocations(tree.rootValue)
  allocate(tree.rootValue, newRect(0, 0, size.width, size.height))
  let candidates = focus.focusOrder(tree.rootValue)
  let nextOrder = focusIds(candidates)
  let previous = tree.focusValue
  if previous.isSome and previous.get in nextOrder:
    tree.focusValue = previous
  elif nextOrder.len > 0:
    var repaired = none(WidgetId)
    if previous.isSome:
      let oldIndex = tree.focusOrderValue.find(previous.get)
      if oldIndex >= 0:
        for offset in 1 .. tree.focusOrderValue.len:
          let candidate = tree.focusOrderValue[
            (oldIndex + offset) mod tree.focusOrderValue.len]
          if candidate in nextOrder:
            repaired = some(candidate)
            break
    tree.focusValue =
      if repaired.isSome: repaired else: some(nextOrder[0])
  else:
    tree.focusValue = none(WidgetId)
  tree.focusOrderValue = nextOrder
  tree.layoutSizeValue = some(size)
  result.needsRender = true
  if previous.isSome and tree.focusValue != previous:
    result.events.add WidgetEvent(kind: focusChanged, source: tree.rootValue.id,
      previousFocus: previous, newFocus: tree.focusValue)

proc relayout*(tree: WidgetTree): DispatchResult =
  ## Repeats layout at the last explicit viewport when one exists.
  if tree.layoutSizeValue.isSome:
    tree.layout(tree.layoutSizeValue.get)
  else:
    dispatchResult(needsRender = true)

proc detach*(tree: WidgetTree; id: WidgetId): DispatchResult =
  ## Detaches a non-root subtree, releases ownership, and repairs focus.
  if id == tree.rootValue.id:
    raise newException(ValueError, "cannot detach the tree root")
  let widget = tree.nodeById(id)
  if widget.isNil:
    raise newException(ValueError, "widget does not belong to this tree: " & $id)
  let parentId = tree.parentOf(id)
  if parentId.isNone or not (tree.nodeById(parentId.get) of Container):
    raise newException(ValueError, "widget parent cannot detach children")
  let parent = Container(tree.nodeById(parentId.get))
  var replacement: seq[Widget]
  for child in parent.childrenValue:
    if child.id != id:
      replacement.add child
  parent.childrenValue = move(replacement)
  parent.sizingValue.del(id)
  parent.touchWidgetState()

  proc release(current: Widget) =
    for child in current.childWidgets():
      release(child)
    tree.nodesValue.del(current.id)
    tree.parentsValue.del(current.id)
    current.setTreeOwned(false)
    current.setAllocation(none(Rect))
  release(widget)
  if tree.layoutSizeValue.isSome:
    result = tree.layout(tree.layoutSizeValue.get)
  else:
    result.needsRender = true

proc attach*(tree: WidgetTree; parentId: WidgetId; child: Widget;
             index = -1): DispatchResult =
  ## Attaches one detached subtree to a container after complete validation.
  let parentWidget = tree.nodeById(parentId)
  if parentWidget.isNil or not (parentWidget of Container):
    raise newException(ValueError, "attachment parent must be a tree container")
  let entries = validateGraph(child)
  for entry in entries:
    if entry.widget.id in tree.nodesValue:
      raise newException(ValueError, "duplicate widget ID: " & $entry.widget.id)
  let parent = Container(parentWidget)
  let insertion = if index < 0: parent.childrenValue.len else: index
  if insertion < 0 or insertion > parent.childrenValue.len:
    raise newException(ValueError, "attachment index is out of range")
  parent.childrenValue.insert(child, insertion)
  parent.touchWidgetState()
  for entry in entries:
    tree.nodesValue[entry.widget.id] = entry.widget
    tree.parentsValue[entry.widget.id] =
      if entry.widget == child: some(parentId) else: entry.parent
    entry.widget.setTreeOwned(true)
  if tree.layoutSizeValue.isSome:
    result = tree.layout(tree.layoutSizeValue.get)
  else:
    result.needsRender = true

proc replacePages*(tree: WidgetTree; tabsId: WidgetId;
                   pages: openArray[TabPage]): DispatchResult =
  ## Atomically replaces pages of attached tabs and repairs descendant focus.
  let target = tree.nodeById(tabsId)
  if target.isNil or not (target of Tabs):
    raise newException(ValueError, "page replacement target must be owned tabs")
  validateTabPages(pages)
  let tabsWidget = Tabs(target)

  var oldPointers = initHashSet[pointer]()
  proc collectOld(current: Widget) =
    oldPointers.incl cast[pointer](current)
    for child in current.childWidgets(): collectOld(child)
  for child in tabsWidget.childWidgets(): collectOld(child)

  let entries = validateGraph(target, target, tabPageChildren(pages),
    rejectOwned = false)
  var nextPointers = initHashSet[pointer]()
  for entry in entries:
    if entry.widget == target: continue
    let identity = cast[pointer](entry.widget)
    nextPointers.incl identity
    if entry.widget.isTreeOwned:
      if identity notin oldPointers or tree.nodeById(entry.widget.id) != entry.widget:
        raise newException(ValueError,
          "widget already belongs to a tree: " & $entry.widget.id)
    elif entry.widget.id in tree.nodesValue:
      raise newException(ValueError, "duplicate widget ID: " & $entry.widget.id)

  var oldWidgets: seq[Widget]
  proc snapshotOld(current: Widget) =
    oldWidgets.add current
    for child in current.childWidgets(): snapshotOld(child)
  for child in tabsWidget.childWidgets(): snapshotOld(child)

  for oldWidget in oldWidgets:
    if cast[pointer](oldWidget) notin nextPointers:
      tree.nodesValue.del(oldWidget.id)
      tree.parentsValue.del(oldWidget.id)
      oldWidget.setTreeOwned(false)
      oldWidget.setAllocation(none(Rect))

  tabsWidget.applyTabPages(pages)
  for entry in entries:
    if entry.widget == target: continue
    tree.nodesValue[entry.widget.id] = entry.widget
    tree.parentsValue[entry.widget.id] = entry.parent
    entry.widget.setTreeOwned(true)

  if tree.layoutSizeValue.isSome:
    result = tree.layout(tree.layoutSizeValue.get)
  else:
    result.needsRender = true

proc move*(tree: WidgetTree; id, newParentId: WidgetId;
           index = -1): DispatchResult =
  ## Atomically reparents an owned subtree while preserving widget identity.
  if id == tree.rootValue.id:
    raise newException(ValueError, "cannot move the tree root")
  let widget = tree.nodeById(id)
  let targetWidget = tree.nodeById(newParentId)
  if widget.isNil or targetWidget.isNil or not (targetWidget of Container):
    raise newException(ValueError, "move requires an owned widget and container")
  var subtreeIds = initHashSet[WidgetId]()
  proc collect(current: Widget) =
    subtreeIds.incl current.id
    for descendant in current.childWidgets(): collect(descendant)
  collect(widget)
  if newParentId in subtreeIds:
    raise newException(ValueError, "move would create a cycle")
  let target = Container(targetWidget)
  let insertion = if index < 0: target.childrenValue.len else: index
  if insertion < 0 or insertion > target.childrenValue.len:
    raise newException(ValueError, "move index is out of range")
  let oldParent = Container(tree.nodeById(tree.parentOf(id).get))
  var replacement: seq[Widget]
  for child in oldParent.childrenValue:
    if child.id != id: replacement.add child
  oldParent.childrenValue = move(replacement)
  oldParent.sizingValue.del(id)
  var adjusted = insertion
  if oldParent == target and insertion > oldParent.childrenValue.len:
    adjusted = oldParent.childrenValue.len
  target.childrenValue.insert(widget, adjusted)
  tree.parentsValue[id] = some(newParentId)
  oldParent.touchWidgetState()
  if target != oldParent: target.touchWidgetState()
  if tree.layoutSizeValue.isSome:
    result = tree.layout(tree.layoutSizeValue.get)
  else:
    result.needsRender = true
