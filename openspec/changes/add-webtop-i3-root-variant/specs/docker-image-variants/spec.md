## ADDED Requirements

### Requirement: Latest image remains unchanged by the i3 variant
The system SHALL keep `buntoolbox:latest` behavior compatible while adding the `buntoolbox:i3` variant.

#### Scenario: Default latest build path remains terminal oriented
- **WHEN** the default Docker build path is used for `buntoolbox:latest`
- **THEN** the image SHALL keep its existing terminal/TUI runtime behavior, default command, and default documented ports.

#### Scenario: Default test command still targets latest
- **WHEN** `scripts/test-image.sh` is run without an explicit image or variant argument
- **THEN** it SHALL continue to test `cuipengfei/buntoolbox:latest`.

### Requirement: i3 image uses the canonical Webtop i3 base
The system SHALL build `buntoolbox:i3` from `lscr.io/linuxserver/webtop:ubuntu-i3` or an explicitly recorded equivalent digest/tag.

#### Scenario: i3 base provenance is recorded
- **WHEN** the i3 image is built
- **THEN** the build or Gate 0 evidence SHALL record the webtop image digest, `build_version`, and upstream revision.

#### Scenario: Docker Hub alias is used instead of canonical image
- **WHEN** an implementation uses a Docker Hub alias instead of `lscr.io/linuxserver/webtop:ubuntu-i3`
- **THEN** the implementation SHALL record the alias reason and digest equivalence evidence.

### Requirement: i3 image is root-first for normal interactive workflows
The `buntoolbox:i3` image SHALL present root as the normal interactive user for GUI desktop sessions, terminal sessions, shell configuration, and buntoolbox tools.

#### Scenario: Interactive desktop shell is root
- **WHEN** a user opens a terminal inside the browser-delivered i3 desktop
- **THEN** `whoami` SHALL report `root` and `HOME` SHALL be `/root`.

#### Scenario: Critical GUI processes do not run as abc
- **WHEN** `buntoolbox:i3` is running its browser desktop stack
- **THEN** critical GUI/runtime processes such as Xvfb, i3, Selkies, dbus, and pulseaudio SHALL NOT run as `abc`.

### Requirement: Root-first guard fails closed on abc runtime behavior
The i3 build SHALL include a root-first guard that scans broad webtop runtime surfaces for forbidden `abc` runtime behavior after patching.

#### Scenario: Upstream adds a new abc runtime launcher
- **WHEN** the webtop base contains any runtime script that launches, manages, owns, or mutates runtime state as `abc` after root-first patching
- **THEN** the build SHALL fail before publishing an i3 image.

#### Scenario: abc account remains for compatibility
- **WHEN** `/etc/passwd` still contains an `abc` account after patching
- **THEN** that fact alone SHALL NOT fail the build, provided no forbidden runtime behavior uses `abc`.

### Requirement: i3 image preserves buntoolbox port semantics
The i3 image SHALL reserve `3000` for `openvscode-start` / openvscode-server and move webtop GUI HTTP to `3200`.

#### Scenario: Webtop GUI uses 3200
- **WHEN** `buntoolbox:i3` starts the webtop browser desktop service
- **THEN** the browser GUI HTTP endpoint SHALL be available on `3200` by default.

#### Scenario: Webtop does not occupy 3000
- **WHEN** `buntoolbox:i3` starts the webtop browser desktop service
- **THEN** webtop SHALL NOT listen on `3000`.

#### Scenario: OpenVSCode can use 3000
- **WHEN** `openvscode-start` is launched inside `buntoolbox:i3` without overriding its default port
- **THEN** openvscode-server SHALL be able to listen and serve on `3000`.

### Requirement: Latest and i3 share common toolchain installation logic
The system SHALL share buntoolbox toolchain installation logic between `latest` and `i3` without duplicating a full Dockerfile worth of tool install steps.

#### Scenario: Tool version changes are single-source
- **WHEN** a tool version such as Node, Bun, JDK, uv, or beads is updated
- **THEN** the version SHALL be changed in a shared source rather than independently editing both latest and i3 Dockerfiles.

#### Scenario: Tool install logic is reused by both variants
- **WHEN** both image variants are built
- **THEN** common buntoolbox tools SHALL be installed through shared layer scripts or an equivalent shared mechanism.

### Requirement: Shared layers preserve cache granularity
The shared build structure SHALL preserve Docker layer granularity comparable to the current Dockerfile.

#### Scenario: High-frequency tool changes do not invalidate heavy early layers
- **WHEN** a high-frequency tool version such as beads changes
- **THEN** earlier heavy layers such as JDK, Python, and Node SHALL NOT be invalidated solely because of a monolithic shared install script.

### Requirement: Image tests share common checks and isolate variant checks
The image test scripts SHALL share common buntoolbox tool checks across `latest` and `i3`, while keeping i3-specific runtime checks separate.

#### Scenario: Common tools are tested in both variants
- **WHEN** `scripts/test-image.sh` tests either `latest` or `i3`
- **THEN** it SHALL run the shared common tool checks for buntoolbox tools.

#### Scenario: i3 variant runs GUI runtime checks
- **WHEN** `scripts/test-image.sh` is run with the i3 variant mode
- **THEN** it SHALL additionally verify root-first runtime behavior, webtop port behavior, and absence of critical `abc` GUI processes.

### Requirement: CI publishes latest and i3 independently
The CI workflow SHALL publish `latest` and `i3` tags independently without allowing the i3 build to publish `latest`.

#### Scenario: Master push publishes both tracks
- **WHEN** a push to the default branch passes CI
- **THEN** CI SHALL publish the existing `latest` tag and the new `i3` tag.

#### Scenario: Release tag publishes semver and i3-semver tags
- **WHEN** a `vX.Y.Z` tag is built
- **THEN** CI SHALL publish `X.Y.Z`, `X.Y`, `i3-X.Y.Z`, and `i3-X.Y` tags.

#### Scenario: Pull requests do not push images
- **WHEN** CI runs for a pull request
- **THEN** both image paths MAY build and test, but SHALL NOT push image tags.

### Requirement: Documentation explains variant selection and safety
The README and image metadata SHALL explain the difference between `latest` and `i3`, including ports, root-first behavior, desktop runtime flags, and safety boundaries.

#### Scenario: User chooses the terminal image
- **WHEN** a user wants the existing terminal/TUI buntoolbox workflow
- **THEN** the documentation SHALL direct them to `cuipengfei/buntoolbox:latest`.

#### Scenario: User chooses the browser desktop image
- **WHEN** a user wants browser-delivered i3 desktop workflow
- **THEN** the documentation SHALL provide a `cuipengfei/buntoolbox:i3` example including webtop port `3200` and desktop runtime notes such as `--shm-size=1gb` or equivalent.

#### Scenario: User reads security warning
- **WHEN** documentation describes browser desktop access
- **THEN** it SHALL warn that the desktop endpoint should not be exposed directly to the public internet without appropriate protection.
