## Base widget state, validation, and shared properties.

import std/options
import terminal_widgets/types

type Widget* = ref object of RootObj
  ## Retained base class shared by every control and container.
  idValue: WidgetId
  visibleValue: bool
  enabledValue: bool
  labelValue: string
  helpValue: Option[string]
  revisionValue: uint64
  treeOwnedValue: bool

method childWidgets*(widget: Widget): seq[Widget] {.base.} =
  ## Internal traversal hook overridden by composite widgets.
  @[]

proc initializeWidgetState*(widget: Widget; id: WidgetId; label: string) =
  ## Internal cross-module initializer; applications should use constructors.
  if widget.isNil:
    raise newException(ValueError, "widget must not be nil")
  id.requireValid()
  widget.idValue = id
  widget.visibleValue = true
  widget.enabledValue = true
  widget.labelValue = label
  widget.helpValue = none(string)
  widget.revisionValue = 0
  widget.treeOwnedValue = false

proc touchWidgetState*(widget: Widget) =
  ## Internal revision update used by state-changing control setters.
  if widget.revisionValue < high(uint64):
    inc widget.revisionValue

proc isTreeOwned*(widget: Widget): bool = widget.treeOwnedValue

proc setTreeOwned*(widget: Widget; value: bool) =
  ## Internal ownership update performed only after whole-tree validation.
  widget.treeOwnedValue = value

proc id*(widget: Widget): WidgetId = widget.idValue
proc visible*(widget: Widget): bool = widget.visibleValue
proc enabled*(widget: Widget): bool = widget.enabledValue
proc label*(widget: Widget): string = widget.labelValue
proc helpText*(widget: Widget): Option[string] = widget.helpValue
proc revision*(widget: Widget): uint64 = widget.revisionValue

proc setVisible*(widget: Widget; value: bool) =
  ## Changes local visibility and invalidates the widget only on transition.
  if widget.visibleValue != value:
    widget.visibleValue = value
    widget.touchWidgetState()

proc setEnabled*(widget: Widget; value: bool) =
  ## Changes local enablement and invalidates the widget only on transition.
  if widget.enabledValue != value:
    widget.enabledValue = value
    widget.touchWidgetState()

proc setLabel*(widget: Widget; value: string) =
  ## Changes the plain-text label.
  if widget.labelValue != value:
    widget.labelValue = value
    widget.touchWidgetState()

proc setHelpText*(widget: Widget; value: Option[string]) =
  ## Sets or clears optional plain help text.
  if widget.helpValue != value:
    widget.helpValue = value
    widget.touchWidgetState()

proc setHelpText*(widget: Widget; value: string) =
  widget.setHelpText(some(value))

proc clearHelpText*(widget: Widget) =
  widget.setHelpText(none(string))
