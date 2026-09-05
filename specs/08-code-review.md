# 08 — Final Code review and Code Quality feedback

Traceability: Phase 11, the final phase of the implementation plan.

Review actual completed code and its verification evidence after Phase 10.
This planning handoff cannot establish implementation quality in advance.

## Required review scope

Assess public API consistency and documentation, separation of state/render/I/O,
dependency direction, ownership under ARC/ORC, deterministic behavior, focus repair,
selection identity, Unicode boundaries, safe text handling, clipping, cleanup on
failure, portability, package contents and build containment. Examine tests for
missing edge cases, accidental dependence on implementation details, ineffective
assertions, and unbounded interactive behavior.

Code Quality feedback must cover readability, naming, module cohesion, complexity,
duplication, error clarity and maintainability. Give concrete examples of good
decisions as well as actionable weaknesses. Avoid an unexplained numerical score.

## Review artifact

Create `review record` only when performing the review. Include:

1. Reviewed revision/worktree state, scope, date, toolchain and evidence examined.
2. Findings table: ID, severity, file/line, reproduction/evidence, impact, proposed
   fix, status and regression-check reference.
3. A Code Quality section assessing the dimensions above with supporting examples.
4. Commands actually executed, their results, and explicit skipped/unverified work.
5. Residual limitations, follow-up task IDs and final release-readiness verdict.

Severity: critical for terminal/data corruption or unrecoverable lifecycle defects;
high for broken documented behavior, invalid memory/UTF-8 operations, or missing
required controls; medium for material maintainability or coverage gaps; low for
localized polish. Rank by demonstrated impact, not speculative possibilities.

## Exit criteria

Every planned control and contract has implementation and verification evidence.
Critical/high findings are fixed and verified. Any medium/low issue left open has
an explicit rationale and concrete follow-up; it cannot conceal a failed mandatory
acceptance criterion. Re-run affected regression checks after fixes and run the
complete release suite on the final code state. Mark Phase 11 complete only after
review feedback, fixes, retesting and the final verdict are recorded. A release
verdict is not authorization to publish.
