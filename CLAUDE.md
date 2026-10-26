# CLAUDE.md — RoadSense development guide

> **Status: PROPOSED.** Written before Milestone 1 starts. Becomes binding once the owner approves
> the architecture and Milestone 1 plan. Decisions still open are listed in `ARCHITECTURE.md` §15.

## Design is frozen

The UI was designed in Claude Design and implemented in SwiftUI (project "RoadSense iOS app
design", `RoadSense.dc.html`). **Do not change the visual design**: layout, colors, typography,
spacing, copy, the 2 pt rules, the square corners, the custom tab bar and the stylized map stay
exactly as they look today. Milestone 1 restructures *code* behind the screens; screenshots
before and after a refactor must be visually identical. Only a design change requested by the
owner may alter the look. Missing states the design does not cover (empty, error, permission
denied) must be built from the existing design components and flagged for owner review.

## Read first

Before implementing a milestone or any major feature, read **all three** documents completely:

1. `CLAUDE.md` (this file): how to work in this repo.
2. `REQUIREMENTS.md`: what to build, per milestone, with acceptance criteria.
3. `ARCHITECTURE.md`: how it is structured and why.

If code and documents disagree, stop and ask. Do not silently follow either. When a decision changes
the architecture, update the document in the same change.

## Project overview

RoadSense is a native iOS app for AI-assisted road-condition monitoring. An iPhone is mounted on the
windshield of a municipal vehicle. While the vehicle drives its normal routes, the app records the
road through the camera, detects damage (potholes, cracks, damaged signs) with an on-device Core ML
model, tags each detection with GPS coordinates, stores it locally, and later syncs it to Supabase.

Users are municipal drivers (start and stop an inspection, nothing else while driving) and road
maintenance staff (review issues on a map and in history). The design source is the Claude Design
project "RoadSense iOS app design" (`RoadSense.dc.html`). The UI uses an ink and green palette with
2 pt rules and no corner radius.

## Technology stack

| Area | Choice |
|---|---|
| Language | Swift 6 (language mode 6), strict concurrency |
| UI | SwiftUI, `@Observable` |
| Camera | AVFoundation |
| AI | Core ML + Vision, on device only |
| Location | Core Location (`CLLocationUpdate.liveUpdates`) |
| Persistence (M2) | SwiftData (see ARCHITECTURE.md §9) |
| Backend (M3) | Supabase (`supabase-swift`, the only planned third-party dependency) |
| Tests | Swift Testing (`import Testing`), XCUITest for smoke flows |
| Tooling | Xcode 26, no SwiftLint, no code generators |

Third-party dependencies today: **none**. Keep it that way unless the rules below are met.

## Milestones

1. **Milestone 1: UI & App Foundation.** All screens, navigation, reusable components, app
   structure, DI, mock services and mock data. No real camera, AI, GPS or network.
2. **Milestone 2: AI Detection & Local Data.** Real camera pipeline, Core ML detection, GPS
   association, SwiftData persistence.
3. **Milestone 3: Supabase Integration & Complete MVP.** Authentication, sync, end-to-end MVP.

Never pull work forward from a later milestone "while we are here". Milestone 1 may define the
*protocols* later milestones will implement, but not their production implementations. Milestone
scope and acceptance criteria are in `REQUIREMENTS.md`.

## Folder organization

Target layout (details and rules in `ARCHITECTURE.md` §3):

```
RoadSense/
  App/            entry point, AppEnvironment (DI), root navigation
  DesignSystem/   theme tokens and reusable, feature-agnostic UI components
  Core/           domain models, formatting, errors, small extensions (no UI, no frameworks beyond Foundation/CoreLocation types)
  Services/       one folder per capability: Camera, Detection, Location, Sync; each has protocol, Mock, and (from M2/M3) Live
  Persistence/    SwiftData models, repositories
  Features/       one folder per screen/flow: Home, Inspection, Summary, Map, History, Settings
  Resources/      assets, Core ML model (M2), string catalog
```

The project uses Xcode synchronized folders: files on disk are automatically part of the target.
Move files with `git mv`; never edit `project.pbxproj` by hand for file membership.

Documentation lives at the repository root, **outside** the app folder, so it is never bundled.

## Architecture rules

- **Dependency direction:** `Features → Services/Persistence (via protocols) → Core`.
  `DesignSystem → Core` only. `Core` depends on nothing. `Services` never import SwiftUI.
  Features never import AVFoundation, Vision, CoreML or SwiftData directly; they talk to services.
- **MVVM where it pays off.** A screen that has non-trivial state, async work or service calls gets
  a `@MainActor @Observable` view model. A purely presentational screen (e.g. static settings rows)
  may use `@State`/`@AppStorage` directly. Do not create an empty view model for symmetry.
- **Views stay presentation-only:** no business rules, no formatting logic beyond trivial, no service
  calls from `body`. Anything testable moves to a view model or a Core type.
- **Protocols only at real seams:** camera, detection, location, repository, sync, settings.
  Not for view models, not for single-implementation helpers.
- **No singletons** (`static let shared`) for app services. Services are created once in
  `AppEnvironment` and passed in.
- **Don't build speculative abstractions.** No generic repositories, coordinators, use-case classes
  or "manager" types without a concrete need in the current milestone.
- **Modifying existing architecture:** allowed only to satisfy a requirement. State the problem,
  make the smallest change, update `ARCHITECTURE.md`. Large reshuffles need owner approval first.
  Preserve working UI behavior; refactors must not change what the user sees unless asked.

## Dependency injection

- `AppEnvironment` (struct of service protocol existentials) is created in `RoadSenseApp`:
  `.live` for production, `.mock` for Milestone 1 / previews / tests.
- View models receive their dependencies through `init`. Views obtain them from
  `@Environment(AppEnvironment.self)` only at the feature's root and pass them down.
- Previews and tests build view models with `.mock` services or a one-off fake. No global state.

## State management

- `@Observable` classes (not `ObservableObject`/`@Published`) for view models and shared state.
- `@State` owns a view model at the point it is created; children take it as a plain parameter or
  `@Bindable`.
- Navigation state (selected tab, stack paths, presented covers) lives in one router object in
  `App/`. Features request navigation through closures or the router, never by mutating another
  feature's state.
- Single source of truth: derived values (totals, formatted strings) are computed, never stored
  twice. The Summary screen must show data from the finished `Drive`, not constants.
- User preferences: `UserDefaults` via a small `SettingsStore` (M1). Drives and issues are never
  stored in `UserDefaults`.

## Swift & SwiftUI conventions

- Swift API Design Guidelines. 4-space indent, ~110-column soft limit.
- Value types (`struct`, `enum`) for models; `final class` only when identity or `@Observable` is
  needed. Everything crossing an isolation boundary is `Sendable`.
- Prefer `let`, exhaustive `switch` without `default` on our own enums, and early returns.
- No force unwraps (`!`), `try!`, `fatalError` outside of previews, tests and truly impossible states
  (with a message).
- No `AnyView`. Prefer small subviews and `@ViewBuilder` over deep nesting. Extract a subview once a
  `body` exceeds ~60 lines or a block is reused.
- Colors, fonts, spacing come from `DesignSystem`. No raw hex values or magic numbers in features.
  The design has **no corner radius**; do not add rounded corners.
- Every user-visible string goes through the String Catalog (`Text("key")` / `String(localized:)`).
- Accessibility is part of "done": labels on icon-only controls, Dynamic Type must not break
  layouts, 44 pt minimum touch targets, sufficient contrast, `accessibilityElement` grouping for
  tiles. (Design uses fixed sizes today; moving to scaled text is tracked tech debt.)
- Every screen has a `#Preview` using mock services. Previews must compile.
- Comments explain *why*, not *what*. No commented-out code. No unexplained `TODO`; use
  `// TODO(M2): ...` with the milestone.

## Naming

- Types `UpperCamelCase`, everything else `lowerCamelCase`; acronyms follow Swift style (`gpsFix`,
  `URL`).
- Files are named after the primary type. One primary type per file.
- Views end in `View` (`HomeView`); view models in `ViewModel` (`HomeViewModel`).
- Protocols describe the capability, not `…Protocol`: `LocationService`, `DetectionService`,
  `DriveRepository`. Implementations are prefixed by role: `MockLocationService`,
  `LiveLocationService`.
- The existing `RS` prefix (`RSRule`, `RSTabBar`, `RSFont`) is reserved for **DesignSystem** types
  only.
- Domain terms are fixed: **Drive** (one inspection session), **Issue** (one detected damage,
  `DetectedIssue`), **IssueKind** (`pothole`, `crack`, `sign`). Do not introduce synonyms
  (trip, route, defect, event).
- Test names describe behavior: `func finishedDriveCountsIssuesPerKind()`.

## Error handling

- Use typed errors per capability (`CameraError`, `LocationError`, `PersistenceError`,
  `SyncError`) conforming to `LocalizedError` with user-presentable text.
- Services `throw`; view models catch and expose a small error state for the view
  (`enum LoadState`/`alert` item). Never swallow errors with `try?` unless the failure is
  genuinely irrelevant, and then comment why.
- Distinguish: recoverable (retry, show banner), degraded (e.g. GPS lost: keep recording, flag
  issues as `locationUnavailable`), and fatal for the session (camera denied: block start with an
  explanation and a link to Settings).
- Never lose recorded data because of a downstream failure: persistence success must not depend on
  the network.
- Use `os.Logger` (subsystem `b.held.RoadSense`, one category per capability). No `print`. No
  personal data or precise locations in logs.

## Swift concurrency

- Language mode 6. The target uses default main-actor isolation (`SWIFT_DEFAULT_ACTOR_ISOLATION =
  MainActor`), so **everything is `@MainActor` unless explicitly opted out**. Camera, Vision and
  Core ML code must be explicitly `nonisolated`, an `actor`, or confined to its own serial queue.
  Never run inference or frame handling on the main actor.
- Structured concurrency first: `async let`, `TaskGroup`, `.task {}` on views. Unstructured `Task {}`
  only with a stored handle and cancellation on teardown.
- Streams between layers are `AsyncStream`/`AsyncSequence` (location samples, camera frames,
  detections). Always define backpressure: camera frames use a "keep only newest" buffer.
- `Timer` / `DispatchQueue` only where an Apple API forces it (e.g. `AVCaptureSession` queue).
- No `@unchecked Sendable` without a comment stating the invariant that makes it safe (e.g. a
  `CVPixelBuffer` wrapper that is read-only after hand-off).
- Cancellation must stop the camera, location updates and in-flight inference.

## Testing

- Swift Testing for unit tests (`@Test`, `#expect`); XCUITest only for a few smoke flows
  (start → stop → summary → history).
- Must be unit-tested: view models, Core logic (totals, grouping, dedupe, severity, formatting),
  repositories (in-memory store), sync outbox logic, anything with branching.
- Not unit-tested: pure layout. Cover with previews.
- Tests use mocks/fakes from `Services/*/Mock*`; no network, no real camera, no real GPS, no
  sleeping for fixed time: use injected clocks or `AsyncStream` fakes.
- A change is not done until it builds with **zero warnings**, all tests pass, and the affected
  screens were looked at in the simulator.
- Bug fix ⇒ add a regression test where practical.

## Dependencies

Adding a package requires: (1) a concrete problem Apple frameworks do not reasonably solve,
(2) maintained, permissive license, (3) pinned to an exact or `upToNextMinor` version, (4) listed
with rationale in `ARCHITECTURE.md`, (5) **owner approval before adding**. Approved so far:
`supabase-swift` (M3 only, not before). Do not add UI kits, DI frameworks, logging frameworks,
networking wrappers, or reactive libraries.

## Development workflow

1. Read the three docs. Confirm which milestone and requirement IDs the task serves.
2. Plan small, vertical, buildable steps. Keep the app running at the end of each step.
3. Implement; build; run tests; check in simulator.
4. Update docs if behavior, structure or decisions changed.
5. Do not commit, push, or open PRs unless asked. When asked, commit messages: imperative,
   one logical change per commit.
6. Do not change build settings, deployment target, entitlements or `Info.plist` keys without
   saying so explicitly.

Build / test commands:

```bash
xcodebuild -project RoadSense/RoadSense.xcodeproj -scheme RoadSense \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project RoadSense/RoadSense.xcodeproj -scheme RoadSense \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

(Repo root is `RoadSenseApp/`; the Xcode project is in `RoadSenseApp/RoadSense/`.)

## AI model

The detector is `peterhdd/pothole-detection-yolov8` (YOLOv8s, **pothole only**), converted to
Core ML offline from `best.pt` (script in `tools/model/`, Ultralytics is a build-time tool and never
an app dependency). Do not assume the model detects cracks or signs. The UI renders only
`DetectionService.supportedKinds`. The Ultralytics AGPL license question is open
(`ARCHITECTURE.md` §15 #10); do not claim the model is cleared for commercial release.

## Privacy & safety (non-negotiable)

- Drivers must never need to touch the phone while the vehicle moves; the Inspection screen
  starts/stops only from a stationary-friendly large control and may auto-start (setting).
- Camera frames are processed in memory. **Raw video is not stored.** Saving a cropped evidence
  image is a Milestone 2/3 decision that requires owner approval (faces, license plates).
- Request permissions in context, with accurate usage descriptions; handle denial gracefully.
- Keep the screen awake and avoid thermal/battery runaway during long drives (M2).
- Secrets (Supabase URL/anon key) come from an `.xcconfig` excluded from git. Never commit keys.
