# TerminalWidgets implementation specifications

These are proposed implementation contracts, not documentation of an existing
API. Execute the implementation guide using these acceptance criteria.
The plan controls scope and order; these specs control behavior. Resolve conflicts
in both documents before implementation. Do not infer missing functionality from
an unimplemented example or claim an unchecked phase is complete.

| Spec | Phases | Responsibility |
| --- | --- | --- |
| [00-build](00-build.md) | 00, 09, 10 | Packaging, task contracts, generated artifacts |
| [01-core](01-core.md) | 01 | Public model, events, module boundaries |
| [02-composition](02-composition.md) | 02, 05 | Geometry, tree ownership, focus and dispatch |
| [03-controls](03-controls.md) | 03–05 | Checkboxes, switches, radio groups, lists, menus, tabs |
| [04-text-editing](04-text-editing.md) | 06 | Single-line editing, validation and Unicode |
| [05-rendering](05-rendering.md) | 07 | Frames, themes, clipping and safe text |
| [06-runtime](06-runtime.md) | 08 | Session ownership, input loop and presentation |
| [07-verification](07-verification.md) | 09–10 | Test matrix, examples, documentation and release |
| [08-code-review](08-code-review.md) | 11 | Final review and Code Quality feedback |

All public names below are the initial API design. Compile contract examples early
and record necessary naming/signature refinements here. Every requested control
must support headless dispatch and rendering before its interactive example ships.
