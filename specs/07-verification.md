# 07 — Verification, examples and release evidence

Traceability: Phases 09–10; acceptance evidence required throughout earlier phases.

## Test strategy

Use `std/unittest` and deterministic fixtures. Organize suites around public
behavior: core, composition/focus, boolean/radio controls, list/menu, tabs, editor,
rendering, runtime, build policy and cross-control integration. Tests should expose
meaningful failures rather than mirror private implementation details.

| Area | Required evidence |
| --- | --- |
| State | User events and programmatic setters preserve documented invariants |
| Focus | One eligible focused ID or none; repair after all tree/viewport mutations |
| Rendering | Exact bounded frames, valid UTF-8, closed styles, safe plain content |
| Editor | Supported cluster operations, atomic insertion rejection, validation |
| Runtime | Scripted lifecycle/failure tests and real terminal evidence |
| Packaging | Consumer import after installation with no development paths |
| Build | No generated products outside `build/` after every supported command |
| Composition | A mixed form preserves values through tab, focus and resize changes |

Run seeded generated event sequences against small trees and assert invariants
after every operation. Include trees with all controls disabled, removed focused
nodes, duplicate IDs, and empty data. Keep failing seeds and minimal reproductions.
Runtime tests must be bounded by timeouts so CI cannot wait indefinitely for input.

## Compatibility and performance

CI target: Nim 2.0.x and current stable on Linux, Windows and macOS with the default
memory manager; additionally stable/Linux with ARC and ORC. Record exact patch
versions in CI output. Validate dependency minimums as well as the normal resolved
versions. Unsupported compiler/platform combinations must be labeled unverified or
failing, not silently omitted from claimed support.

With 100,000 keyed list items and a 20-row viewport, instrument rendering to prove
only visible rows are visited. Record construction/replacement time separately
from navigation and rendering; O(n) setup is acceptable. Use a release build,
fixed fixture, viewport and iteration count; record compiler, machine and median
timings under `build/reports/`. Prefer operation-count assertions over flaky timing
thresholds. O(n) disabled-item scans must not be misrepresented as constant time.

An external consumer test must install/copy the built package into an isolated
Nimble environment, import the facade and opt-in runtime, and compile without
`../terminal-*` paths. Inspect package contents and verify importing/constructing
widgets neither prints nor opens a terminal. Keep test fixtures/output in `build/`.

## Documentation and release

Create independently compilable examples: `checkbox.nim`, `switch.nim`,
`radio_group.nim`, `scroll_list.nim`, `menu.nim`, `tabs.nim`, `text_field.nim`,
`headless_form.nim`, and `form.nim`. Each interactive example states its exit key
and uses the guarded runtime. `headless_form` must run deterministically in CI.
Place a compile/run command in each example's source comment. `nimble examples`
compiles interactive examples without executing them.

Expand README only with implemented, verified behavior: introduction, platform
evidence, requirements, TerminalDeck relationship, table of contents, installation,
quick start, API overview with component links, examples, development/docs, and
MIT attribution. Preserve and correctly fence the existing ecosystem tree; reuse
the supplied SVG if helpful. Do not invent screenshots or successful test claims.

Author `docs/api.md`, `docs/behavior.md`, and `docs/runtime.md` describing public
contracts, fixed key bindings, Unicode boundary scope, plain rendering, errors,
session ownership and cleanup. Generate compiler API docs in `build/docs` only.
Ensure README snippets correspond to compiled examples. Document how applications
combine static companion-library output while maintaining a single terminal owner.

Release readiness requires passing `nimble releaseCheck`, compatibility evidence,
resolved dependency floors, installed consumer success, no generated-file leakage,
and the final review in Phase 11. Leave package publication/tagging to the owner.
Maintain `implementation records` with item IDs, implementation files, commands/results,
documented deviations and known platform gaps. Do not mark a test passed if it was
only compiled or skipped for lack of terminal access.
