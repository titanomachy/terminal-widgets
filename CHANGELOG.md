# Changelog

All notable changes to TerminalWidgets are documented in this file.

## Unreleased

### Package setup

- Validated the `0.1.0` package metadata and minimum requirements for Nim 2.0.0,
  TerminalStyle 0.1.1, and TerminalScreen 0.1.1.
- Added the public facade and the source, test, support, and example structure
  defined by the architecture module map.
- Added package-layout coverage and an independently compilable facade example.

### Build containment

- Contained direct root and nested-directory Nim builds, Nimble tasks, generated
  API documentation, compiler caches, test fixtures, and command overrides under
  `build/`.
- Added an artifact-location regression suite covering compilation, execution,
  documentation helpers, source-tree integrity, versioned caches, and isolated
  concurrent-job paths.
- Documented the verified baseline commands and build-directory layout.
