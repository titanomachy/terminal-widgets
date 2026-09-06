## TerminalWidgets provides retained model types for composable terminal UI
## controls. Importing this facade performs no terminal I/O.
##
## The facade includes validated IDs and geometry, normalized input, typed
## output events, persistent controls, composition and focus, Unicode-aware
## single-line editing, semantic themes, and pure full-frame rendering. Import
## ``terminal_widgets/runtime`` explicitly for guarded terminal ownership.

import terminal_widgets/[checkbox, composition, dispatch, editor, menu,
  radio_group, render, scroll_list, selection, static_text, switch, tabs,
  text_field, theme, types, widget]

export checkbox
export composition except layoutSize, moveFocus, nodeById, parentOf, relayout
export dispatch, editor, menu, radio_group, render, scroll_list, selection,
  static_text, switch, text_field, theme, types
export tabs except applyTabPages, snapshotTabPages, tabPageChildren,
  validateTabPages
export widget except afterAllocation, canFocus, childContentBounds, childWidgets,
  handleInput, initializeWidgetState, inputInvalidatesLayout,
  interactionChildren, isTreeOwned, setAllocation, setTreeOwned, touchWidgetState
