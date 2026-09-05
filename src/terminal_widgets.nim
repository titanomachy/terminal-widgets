## TerminalWidgets provides retained model types for composable terminal UI
## controls. Importing this facade performs no terminal I/O.
##
## This initial public model includes validated IDs and geometry, normalized
## input types, typed output events, common widget properties, persistent value
## accessors, keyed choices/pages, and tree construction. Layout, dispatch, and
## rendering are added by their corresponding implementation phases.

import terminal_widgets/[checkbox, composition, dispatch, menu, radio_group,
  render, scroll_list, selection, switch, tabs, text_field, theme, types, widget]

export checkbox
export composition except moveFocus, nodeById, parentOf, relayout
export dispatch, menu, radio_group, render, scroll_list, selection, switch, tabs,
  text_field, theme, types
export widget except afterAllocation, canFocus, childContentBounds, childWidgets,
  handleInput, initializeWidgetState, inputInvalidatesLayout,
  interactionChildren, isTreeOwned, setAllocation, setTreeOwned, touchWidgetState
