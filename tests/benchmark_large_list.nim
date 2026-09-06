## Release benchmark for the fixed 100,000-item/20-row verification fixture.
## Run with: nimble benchmark

import std/[algorithm, cpuinfo, monotimes, os, options, strformat, strutils,
  times]
import terminal_widgets

const
  ItemCount = 100_000
  ViewportRows = 20
  SetupIterations = 9
  SteadyIterations = 301

proc fixture(suffix = ""): seq[ChoiceItem] =
  result = newSeqOfCap[ChoiceItem](ItemCount)
  for index in 0 ..< ItemCount:
    result.add newChoiceItem(newItemId($index), "Item " & $index & suffix)

template elapsedNanoseconds(body: untyped): int64 =
  block:
    let started = getMonoTime()
    body
    (getMonoTime() - started).inNanoseconds

proc median(samples: var seq[int64]): int64 =
  samples.sort()
  samples[samples.len div 2]

proc milliseconds(nanoseconds: int64): string =
  formatFloat(nanoseconds.float / 1_000_000.0, ffDecimal, 3)

proc microseconds(nanoseconds: int64): string =
  formatFloat(nanoseconds.float / 1_000.0, ffDecimal, 3)

when isMainModule:
  let items = fixture()
  let replacements = fixture(" updated")
  var constructionSamples, replacementSamples: seq[int64]
  for iteration in 0 ..< SetupIterations:
    var candidate: ScrollList
    let construction = elapsedNanoseconds:
      candidate = newScrollList(newWidgetId("construct-" & $iteration), items)
    constructionSamples.add construction
    doAssert candidate.itemCount == ItemCount

    let replacement = newScrollList(newWidgetId("replace-" & $iteration), items)
    let replacementTime = elapsedNanoseconds:
      replacement.setItems(replacements)
    replacementSamples.add replacementTime
    doAssert replacement.itemCount == ItemCount

  let list = newScrollList(newWidgetId("steady"), items)
  let tree = newWidgetTree(list)
  discard tree.layout(newSize(32, ViewportRows))
  var navigationSamples, renderSamples: seq[int64]
  for _ in 0 ..< SteadyIterations:
    list.setSelected(some(newItemId("0")))
    let navigation = elapsedNanoseconds:
      discard tree.dispatch(keyInput(keyArrowDown))
    navigationSamples.add navigation
    doAssert list.selected == some(newItemId("1"))

    var metrics: RenderMetrics
    let rendering = elapsedNanoseconds:
      let rows = renderControl(list, plainWidgetTheme(), metrics, focused = true)
      doAssert rows.len == ViewportRows
    renderSamples.add rendering
    doAssert metrics.visitedItems == ViewportRows

  let reportDirectory = currentSourcePath().parentDir().parentDir() /
    "build" / "reports"
  createDir(reportDirectory)
  let report = &"""# Large-list benchmark

- Command: `nimble benchmark`
- Compiler: Nim {NimVersion} ({hostOS}/{hostCPU}, release, default memory manager)
- Machine: {hostOS}/{hostCPU} ({countProcessors()} logical processors)
- Fixture: {ItemCount} keyed items, {ViewportRows}-row viewport
- Samples: setup {SetupIterations}; navigation/render {SteadyIterations}
- Construction median: {milliseconds(median(constructionSamples))} ms
- Replacement median: {milliseconds(median(replacementSamples))} ms
- One-row navigation median: {microseconds(median(navigationSamples))} µs
- 20-row rendering median: {microseconds(median(renderSamples))} µs
- Render visits per sample: {ViewportRows} (asserted)

Construction and replacement are expected O(n). The navigation case moves to
the adjacent enabled item; disabled-item scans are O(distance scanned), not
constant time. Rendering is bounded by visible rows and is enforced by the
operation-count assertion; timings are evidence, not pass/fail thresholds.
"""
  writeFile(reportDirectory / "large_list_benchmark.md", report)
  echo report
