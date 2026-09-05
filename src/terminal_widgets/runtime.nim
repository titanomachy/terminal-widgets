## Explicit interactive loop with owned and borrowed TerminalScreen paths.
##
## Import this module explicitly; the side-effect-free package facade does not
## open sessions or acquire terminal modes.

import std/[options, strutils]
import terminal_screen
import terminal_widgets/[composition, dispatch, render, terminal_screen_adapter,
  theme, types, widget]

export terminal_screen_adapter

type
  RunTermination* = enum
    requestedStop
    cancelled
    endOfInput

  RunResult* = object
    ## Normal runtime termination and the number of full frames presented.
    termination*: RunTermination
    framesPresented*: int

  RunAction* = enum
    continueRunning
    stopRunning

  RuntimeEventContext* = object
    ## One fully dispatched input delivered after ordered widget events exist.
    input*: InputEvent
    outcome*: DispatchResult

  RuntimeEventHandler* = proc(context: RuntimeEventContext): RunAction {.closure.}

  RuntimeOptions* = object
    ## Runtime policy independent of TerminalScreen's session options.
    pollTimeoutMs*: int
    fallbackSize*: Size
    theme*: WidgetTheme
    ownBorrowedPresentation*: bool

proc defaultRuntimeOptions*(): RuntimeOptions =
  RuntimeOptions(
    pollTimeoutMs: 50,
    fallbackSize: newSize(80, 24),
    theme: defaultWidgetTheme(),
    ownBorrowedPresentation: false
  )

proc validate(options: RuntimeOptions) =
  if options.pollTimeoutMs <= 0 or options.pollTimeoutMs > 60_000:
    raise newException(ValueError,
      "runtime pollTimeoutMs must be in 1..60000")
  if options.fallbackSize.width <= 0 or options.fallbackSize.height <= 0:
    raise newException(ValueError,
      "runtime fallback dimensions must be positive")
  options.theme.validateTheme()

type WidgetStamp = tuple[id: WidgetId, revision: uint64, visible, enabled: bool]

proc modelStamp(tree: WidgetTree): seq[WidgetStamp] =
  var stamps: seq[WidgetStamp]
  proc visit(current: Widget) =
    stamps.add (current.id, current.revision, current.visible, current.enabled)
    for child in current.childWidgets(): visit(child)
  visit(tree.root)
  result = move(stamps)

proc requireCapabilities(capabilities: TerminalCapabilities) =
  if not capabilities.inputIsTerminal or not capabilities.outputIsTerminal or
      not capabilities.supportsAnsi or not capabilities.supportsRawMode:
    raise newException(TerminalUnavailableError,
      "interactive ANSI terminal input, output, and raw mode are required")

proc runtimeSize(value: Option[TerminalSize]; fallback: Size): Size =
  if value.isSome:
    newSize(value.get.columns, value.get.rows)
  else:
    fallback

proc runWidgetsWithBackend*(tree: WidgetTree; backend: RuntimeBackend;
                            options = defaultRuntimeOptions();
                            onEvents: RuntimeEventHandler = nil;
                            ownedSession = true;
                            ownPresentation = true): RunResult =
  ## Runs one backend with transactional acquisition and complete cleanup.
  if tree.isNil or tree.root.isNil:
    raise newException(ValueError, "widget tree must not be nil")
  if backend.isNil:
    raise newException(ValueError, "runtime backend must not be nil")
  options.validate()

  var
    opened = false
    alternate = false
    cursor = false
    autowrap = false
    presentationStarted = false
    primary: ref CatchableError
    cleanupErrors: seq[string]

  try:
    if ownedSession:
      backend.openOwned()
      opened = true
    backend.capabilities().requireCapabilities()
    var size = runtimeSize(backend.initialSize(), options.fallbackSize)

    if ownPresentation:
      # Register each restoration before attempting the matching acquisition;
      # a backend write may fail after partially reaching the terminal.
      alternate = true
      backend.enterAlternateScreen()
      cursor = true
      backend.hideCursor()
      autowrap = true
      backend.disableAutoWrap()

    discard tree.layout(size)
    presentationStarted = true
    backend.present(tree.render(size, options.theme), ownPresentation)
    inc result.framesPresented

    var running = true
    while running:
      let input = backend.readInput(options.pollTimeoutMs)
      if input.kind == eventEndOfInput:
        result.termination = endOfInput
        break
      if input.kind == eventKey and input.keyEvent.key == keyCtrlC:
        result.termination = cancelled
        break
      if input.kind == eventTimeout:
        continue

      let beforeCallback = tree.modelStamp()
      var outcome: DispatchResult
      if input.kind == eventResize:
        size = newSize(input.size.columns, input.size.rows)
        outcome = tree.layout(size)
      else:
        outcome = tree.dispatch(input)

      var action = continueRunning
      if not onEvents.isNil:
        action = onEvents(RuntimeEventContext(input: input, outcome: outcome))
      if action == stopRunning:
        result.termination = requestedStop
        running = false
        continue

      let applicationChanged = tree.modelStamp() != beforeCallback
      if applicationChanged and input.kind != eventResize:
        let layoutOutcome = tree.layout(size)
        outcome.needsRender = outcome.needsRender or layoutOutcome.needsRender
        if layoutOutcome.events.len > 0 and not onEvents.isNil:
          let repairAction = onEvents(RuntimeEventContext(input: input,
            outcome: layoutOutcome))
          if repairAction == stopRunning:
            result.termination = requestedStop
            running = false
            continue
      if input.kind == eventResize or outcome.needsRender or applicationChanged:
        backend.present(tree.render(size, options.theme), ownPresentation)
        inc result.framesPresented
  except CatchableError as error:
    primary = error

  template cleanup(label: string; condition: bool; operation: untyped) =
    if condition:
      try:
        operation
      except CatchableError as error:
        cleanupErrors.add label & ": " & error.msg

  cleanup("reset styles", presentationStarted, backend.resetStyles())
  cleanup("restore autowrap", autowrap, backend.enableAutoWrap())
  cleanup("restore cursor", cursor, backend.showCursor())
  cleanup("leave alternate screen", alternate, backend.leaveAlternateScreen())
  cleanup("close session", opened, backend.closeOwned())

  if not primary.isNil:
    if cleanupErrors.len > 0:
      primary.msg.add("; cleanup failures: " & cleanupErrors.join("; "))
    raise primary
  if cleanupErrors.len > 0:
    raise newException(TerminalStateError,
      "runtime cleanup failed: " & cleanupErrors.join("; "))

proc runWidgets*(tree: WidgetTree; options = defaultRuntimeOptions();
                 onEvents: RuntimeEventHandler = nil): RunResult =
  ## Opens, owns, restores, and closes one TerminalScreen session.
  let backend = newOwnedTerminalBackend()
  runWidgetsWithBackend(tree, backend, options, onEvents,
    ownedSession = true, ownPresentation = true)

proc runWidgets*(tree: WidgetTree; session: TerminalSession; output: File;
                 options = defaultRuntimeOptions();
                 onEvents: RuntimeEventHandler = nil): RunResult =
  ## Uses an open caller-owned session and its exact output stream.
  ##
  ## The caller must already have established raw mode. By default this path
  ## neither changes screen/cursor/autowrap modes nor closes the session. Set
  ## ``ownBorrowedPresentation`` only when the stated baseline is the normal
  ## screen with a visible cursor and enabled autowrap.
  let backend = newBorrowedTerminalBackend(session, output)
  runWidgetsWithBackend(tree, backend, options, onEvents,
    ownedSession = false,
    ownPresentation = options.ownBorrowedPresentation)
