## Retained container and tree construction with atomic ownership validation.
##
## Layout allocation and tree-managed structural mutation are introduced in
## Phase 02. Detached containers may replace children before attachment.

import std/[options, sets, tables]
import terminal_widgets/[types, widget]

type
  ContainerKind* = enum
    rowContainer
    columnContainer
    stackContainer

  Container* = ref object of Widget
    kindValue: ContainerKind
    childrenValue: seq[Widget]

  WidgetTree* = ref object
    rootValue: Widget
    nodesValue: Table[WidgetId, Widget]
    parentsValue: Table[WidgetId, Option[WidgetId]]

  GraphEntry = tuple[widget: Widget, parent: Option[WidgetId]]

proc copyChildren(children: openArray[Widget]): seq[Widget] =
  result = newSeqOfCap[Widget](children.len)
  for child in children:
    if child.isNil:
      raise newException(ValueError, "container child must not be nil")
    result.add child

proc validateGraph(root: Widget; prospectiveContainer: Container = nil;
                   prospectiveChildren: seq[Widget] = @[]): seq[GraphEntry] =
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
    if current.isTreeOwned:
      raise newException(ValueError, "widget already belongs to a tree: " & $current.id)

    visiting.incl identity
    ids.incl current.id
    entries.add (current, parent)
    let children =
      if not prospectiveContainer.isNil and current == Widget(prospectiveContainer):
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
    container.touchWidgetState()

proc newWidgetTree*(root: Widget): WidgetTree =
  ## Atomically validates and takes ownership of a retained widget graph.
  let entries = validateGraph(root)
  new result
  result.rootValue = root
  result.nodesValue = initTable[WidgetId, Widget]()
  result.parentsValue = initTable[WidgetId, Option[WidgetId]]()
  for entry in entries:
    result.nodesValue[entry.widget.id] = entry.widget
    result.parentsValue[entry.widget.id] = entry.parent
  for entry in entries:
    entry.widget.setTreeOwned(true)

proc root*(tree: WidgetTree): Widget = tree.rootValue
