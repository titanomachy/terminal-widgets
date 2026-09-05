## Retained container and tree construction.
##
## Layout allocation and structural mutation are introduced in Phase 02.

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

proc copyChildren(children: openArray[Widget]): seq[Widget] =
  result = newSeqOfCap[Widget](children.len)
  for child in children:
    if child.isNil:
      raise newException(ValueError, "container child must not be nil")
    result.add child

proc newContainer(id: WidgetId; kind: ContainerKind;
                  children: openArray[Widget]): Container =
  let storedChildren = copyChildren(children)
  new result
  result.initializeWidgetState(id, "")
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

proc newWidgetTree*(root: Widget): WidgetTree =
  ## Constructs a tree controller around a non-nil retained root.
  ##
  ## Full uniqueness, ownership, and cycle validation is Phase 01.B work.
  if root.isNil:
    raise newException(ValueError, "widget tree root must not be nil")
  WidgetTree(rootValue: root)

proc root*(tree: WidgetTree): Widget = tree.rootValue
