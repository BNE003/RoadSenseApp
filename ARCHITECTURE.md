# ARCHITECTURE.md — RoadSense

> **Status: PROPOSED**, pending owner approval. Section 15 lists decisions that need an answer.
> Code in this document is a design sketch, not final signatures.

## 1. Goals and principles

- Small team, one app target, one codebase. Simple beats clever.
- UI, camera, detection, location, persistence and sync are separate concerns with narrow
  interfaces, so each can be replaced, mocked and tested alone.
- Milestone 1 runs entirely on mocks; Milestones 2 and 3 swap in production implementations
  **without changing feature UI**.
- Offline-first: the phone is the source of truth for what it detected; the server is a sync target.
- Apple frameworks first. No third-party code except `supabase-swift` in Milestone 3.
- Abstractions are added when a second implementation or a test needs them, not before.

## 2. High-level architecture

```
┌────────────────────────────── App ──────────────────────────────┐
│ RoadSenseApp · AppEnvironment (DI) · AppRouter                  │
└───────────────┬─────────────────────────────────────────────────┘
                │ creates / injects
┌───────────────▼─────────────── Features (SwiftUI) ──────────────┐
│ Home · Inspection · Summary · Map · History · Settings          │
│ View ←→ ViewModel (@MainActor @Observable)                      │
└───────┬───────────────────────┬─────────────────────────────────┘
        │ uses                  │ uses
┌───────▼──────────┐   ┌────────▼──────────────────────────────────┐
│ DesignSystem     │   │ Services (protocols + Mock + Live)         │
│ tokens,          │   │ Camera · Detection · Location · Sync       │
│ components       │   │ InspectionSession (coordinator)            │
└───────┬──────────┘   └────────┬───────────────────────────────────┘
        │                       │ persists via
        │              ┌────────▼───────────┐
        │              │ Persistence        │
        │              │ DriveRepository    │
        │              │ (SwiftData, M2)    │
        │              └────────┬───────────┘
        └───────────┬───────────┘
              ┌─────▼─────┐
              │   Core    │  domain models, formatting, errors
              └───────────┘
```

One process, one module (the app target). Layers are enforced by folder convention and review, not
by separate Swift packages. If build times or boundary erosion become a problem we can extract
`Core` + `Services` into a local package later; the dependency rules below already allow it.

## 3. Project structure

```
RoadSenseApp/                         repo root
  CLAUDE.md  REQUIREMENTS.md  ARCHITECTURE.md
  supabase/                           (M3) migrations, RLS policies, config
  RoadSense/                          Xcode project directory
    RoadSense.xcodeproj
    RoadSense/                        app target (synchronized folder)
      App/
        RoadSenseApp.swift            entry point, registers fonts, builds the environment
        AppEnvironment.swift          service container; .mock (M1), .live() from M2
        AppRouter.swift               selected tab, map focus, inspection cover
        RootView.swift                tab container, RSTabBar, inspection full-screen cover
        LaunchOptions.swift           DEBUG launch arguments (-RS_SCREEN, -RS_CAMERA_DENIED)
      DesignSystem/
        Tokens/                       Colors, Typography (Archivo), Layout
        Components/                   RSRule, RSBlockButton, RSStatTile, RSSegmentedControl, RSSquareToggle /
                                      RSToggleRow, RSSectionHeader, RSListRow / RSValueRow, RSBarMeter,
                                      RSTabBar, RSWordmark, RSStateMessage
      Core/
        Models/                       Drive, DriveSummary, HistoryTotals, DetectedIssue, IssueKind, Coordinate,
                                      NormalizedRect, MapViewport, MapFocus, MountHeight
        Formatting/                   DriveFormatting (distance, duration, relative dates)
        Errors/                       CameraError, LocationError, PersistenceError (SyncError arrives with M3)
      Services/
        Camera/                       CameraService, MockCameraService, (M2) LiveCameraService
        Detection/                    DetectionService, MockDetectionService, (M2) LiveDetectionService
        Location/                     LocationService, MockLocationService, (M2) LiveLocationService
        Inspection/                   InspectionSession (coordinator), IssueDeduplicator
        Sync/                         SyncService, NoopSyncService, (M3) SupabaseSyncService, AuthService
        Settings/                     SettingsStore, UserDefaultsSettingsStore
      Persistence/                    DriveRepository, InMemoryDriveRepository,
                                      (M2) SwiftData models + SwiftDataDriveRepository
      Features/
        Home/        HomeView, HomeViewModel
        Inspection/  InspectionFlowView (live → summary), LiveView, InspectionViewModel, (M2) CameraPreview
        Summary/     SummaryView, SummaryViewModel
        Map/         MapView, MapViewModel
        History/     HistoryView, HistoryViewModel
        Settings/    SettingsView, SettingsViewModel
      Resources/
        Assets.xcassets, Fonts/ (Archivo, SIL OFL), Localizable.xcstrings, (M2) PotholeDetector.mlpackage
      PreviewSupport/                 SampleData: the design's drives and issues, used by mocks, previews, tests
    RoadSenseTests/                   unit tests, mirror the folder layout
    RoadSenseUITests/                 smoke flows
```

Rules:
- A feature folder contains only that feature's views and view model. Anything used by two
  features moves to `DesignSystem` (UI) or `Core` (logic).
- `Mock*` types live next to their protocol and are compiled into the app (needed for previews and
  for the Milestone 1 build). They are small and deterministic.
- `Persistence` is separate from `Services` because it has storage-specific types
  (SwiftData `@Model`) that must not leak. The *protocol* `DriveRepository` is Core-facing; models
  in `Core` are what everyone else sees.

## 4. Components and responsibilities

| Component | Responsibility | Must not |
|---|---|---|
| **Views** | Render state, forward user intent to view model. | Hold business rules, call services in `body`. |
| **ViewModels** | Screen state, intent handling, mapping domain → display values; calls services/repositories. | Import SwiftUI view types beyond `Observation`, know concrete service types. |
| **AppRouter** | Selected tab, map focus, full-screen cover for Inspection, post-drive routing. | Know feature internals. |
| **AppEnvironment** | Creates and holds services once; hands them to feature roots. | Contain logic. |
| **InspectionSession** | Orchestrates one Drive: starts camera/location/detection, merges detections with the latest location, deduplicates, persists issues, exposes a live `State` stream. Owns drive lifecycle (start → recording → finished/failed). | Touch UI; know AVFoundation/Vision specifics. |
| **CameraService** | Camera permission, session lifecycle, frame stream, preview source. | Run inference. |
| **DetectionService** | Frame in, normalized detections out (kind, confidence, box). Owns model loading and throttling. | Know GPS, storage, UI. |
| **LocationService** | Authorization state, stream of `LocationSample`, accuracy filtering. | Know detections. |
| **DriveRepository** | Persist/query drives and issues, observe changes, outbox state for sync. | Expose SwiftData types. |
| **SyncService** (M3) | Push pending records, pull (optional), report status; owns retry/backoff. | Be called from views. |
| **AuthService** (M3) | Session lifecycle and token access. | Be known to the camera/detection stack. |
| **SettingsStore** | Typed access to user preferences (UserDefaults). | Store drives. |
| **Core models** | Pure value types and logic (statistics, grouping). | Import UI, SwiftData, Supabase. |

## 5. Data flow

### Live inspection (M2 target; M1 uses the same shape with mocks)

```
CameraService ──frames──▶ DetectionService ──detections──┐
                                                         ▼
LocationService ──samples──▶ InspectionSession ◀── latest location
                                   │  dedupe, tag, assign drive
                                   ├──▶ DriveRepository (save issue immediately)
                                   └──▶ State stream ──▶ InspectionViewModel ──▶ InspectionView
```

1. `InspectionViewModel.start()` asks `InspectionSession.start(settings:)`.
2. Session starts location first (fast fail on denial), then camera, then detection.
3. Frames flow camera → detector; the detector keeps only the newest frame while busy.
4. Each detection batch is stamped with the most recent acceptable `LocationSample`
   (≤ 2 s old, accuracy ≤ 30 m; otherwise the issue is stored with `locationQuality = .unavailable`).
5. The deduplicator merges repeated sightings of the same issue (same kind, within a distance and
   time window, with box continuity) into one `DetectedIssue`, keeping the best-confidence sighting.
6. Issues are written to the repository immediately (crash safety); the view model only receives
   state updates for display.
7. `stop()` finalizes the `Drive` (end time, distance, statistics) and returns it for the Summary.

### Review

`HomeViewModel`, `HistoryViewModel`, `MapViewModel`, `SummaryViewModel` read drives and issues from
`DriveRepository` (async queries + observation). Nothing in review reads from the live pipeline.

### Sync (M3)

Repository records carry `syncState`. `SyncService` observes pending records and connectivity,
uploads in batches (UUID-keyed upserts), then marks them `synced`. UI reads `syncState` from the
repository like any other field.

## 6. Dependency direction and DI

```
Features ──▶ Services (protocol)  ──▶ Core
Features ──▶ Persistence (protocol) ─▶ Core
Features ──▶ DesignSystem ─────────────▶ Core
App ──▶ everything (composition root)
Services(Live) ──▶ Apple frameworks (AVFoundation, Vision, CoreML, CoreLocation) / Supabase
Persistence(Live) ──▶ SwiftData
```

Forbidden: Core → anything; Services → Features/DesignSystem/SwiftUI; Features → Apple
infrastructure frameworks; Features → another Feature's internals.

**DI mechanism:** constructor injection. `AppEnvironment` is a struct of protocol existentials plus the
clock and a `now` function (so time is injectable in tests):

```swift
struct AppEnvironment {
    var location: any LocationService
    var camera: any CameraService
    var detection: any DetectionService
    var drives: any DriveRepository
    var settings: any SettingsStore
    var sync: any SyncService
    var clock: any Clock<Duration>
    var now: @Sendable () -> Date

    func makeInspectionSession() -> InspectionSession
    static func mock(…) -> AppEnvironment      // M1 default, previews, tests, UI tests
    // static func live() -> AppEnvironment    // M2, M3
}
```

`RoadSenseApp` creates it and passes it to `RootView`, which hands it to each feature's view model by
initializer. It is deliberately *not* in the SwiftUI environment: a struct of existentials gains
nothing from it, and explicit parameters keep dependencies visible. No service locator calls deeper in
the tree. No third-party DI container.

## 7. Service protocols (sketch)

Only what Milestones 2 and 3 are known to need.

```swift
protocol LocationService: Sendable {
    func authorizationUpdates() -> AsyncStream<LocationAuthorization>
    func requestAuthorization() async -> LocationAuthorization
    func samples() -> AsyncThrowingStream<LocationSample, any Error>   // cancels updates when finished
}

protocol CameraService: Sendable {
    func requestAuthorization() async -> CameraAuthorization
    func frames() -> AsyncThrowingStream<CameraFrame, any Error>       // newest-wins buffering
    var previewSource: CameraPreviewSource? { get }                     // opaque handle on the AVCaptureSession
    var frameAspectRatio: Double? { get }                               // for placing boxes over the preview
}

protocol DetectionService: Sendable {
    var supportedKinds: Set<IssueKind> { get }                          // what this model can detect
    func prepare() async throws                                         // load/compile model
    func detect(in frame: CameraFrame, mountHeight: MountHeight) async throws -> [RawDetection]
}

protocol DriveRepository: Sendable {
    func save(_ drive: Drive) async throws                              // insert or replace
    func driveSummaries(limit: Int?) async throws -> [DriveSummary]     // newest first, no issues loaded
    func totals() async throws -> HistoryTotals
    func issues(focus: MapFocus) async throws -> [DetectedIssue]        // .all or .drive(id)
    func append(_ issue: DetectedIssue) async throws                    // M2: incremental, crash-safe
    func checkpoint(driveID:endedAt:distanceMeters:route:) async throws // M2
    func delete(driveID: Drive.ID) async throws                         // M2
    func recoverUnfinishedDrives() async throws -> Int                  // M2
    // M3 adds the sync outbox
}

@MainActor protocol SettingsStore: AnyObject { /* typed properties, UserDefaults-backed */ }

protocol SyncService: Sendable {
    func statusUpdates() -> AsyncStream<SyncStatus>
    func syncNow() async
}
```

`CameraFrame` is a timestamp in M1 and wraps a `CVPixelBuffer` plus timestamp from M2 as `Sendable` (read-only after hand-off).
`RawDetection` = kind, confidence, normalized rect. Display geometry is derived in the Inspection
feature, never in the detector.

## 8. Mock vs production implementations

| Protocol | Milestone 1 | Milestone 2 | Milestone 3 |
|---|---|---|---|
| `CameraService` | `MockCameraService` (no frames; placeholder preview) | `LiveCameraService` | – |
| `DetectionService` | `MockDetectionService` (scripted timeline, injectable clock) | `LiveDetectionService` (Vision + Core ML) | – |
| `LocationService` | `MockLocationService` (simulated route along fixed coordinates) | `LiveLocationService` | – |
| `DriveRepository` | `InMemoryDriveRepository` (seeded from `PreviewSupport`) | `SwiftDataDriveRepository` | + outbox fields |
| `SettingsStore` | `UserDefaultsSettingsStore` (real) | – | – |
| `SyncService` | `NoopSyncService` | `NoopSyncService` | `SupabaseSyncService` |

Mocks stay after M2: they power previews, unit tests, UI tests and simulator runs (the simulator
has no camera). `AppEnvironment.live()` is selected by build configuration or launch argument
(`-RS_USE_MOCKS`) for development on simulator.

## 9. Local persistence strategy

- **Choice (proposed): SwiftData.** Deployment target is far above iOS 17, data is small and
  relational (Drive 1—n Issue), queries are simple, and it needs no dependency. Alternative: GRDB
  (more control, third-party). See §15.
- **Domain/persistence split:** `@Model` classes (`DriveEntity`, `IssueEntity`) live only in
  `Persistence/`. The repository maps to/from `Core` value types. The cost is two shapes per record;
  the benefit is Sendable domain models, trivially testable logic and no SwiftData in view models.
- **Concurrency:** `SwiftDataDriveRepository` is backed by a `ModelActor` so writes never touch the
  main actor. Issues are saved one by one as they occur (crash safety); drive statistics are
  finalized at stop.
- **Identity:** every `Drive` and `DetectedIssue` has a client-generated `UUID` that is also the
  server primary key in M3 (idempotent upserts).
- **Sync fields (added in M2 as a best guess; M3 may adjust them to the delivered Supabase schema
  via a schema migration):** `syncState` (`pending | syncing | synced | failed`), `updatedAt`,
  `deletedAt?` (soft delete).
- **Schema versioning:** `VersionedSchema` + migration plan from the first shipped model.
- **Route breadcrumb:** stored as a compact array of coordinates on the drive (downsampled to
  ~1 point per 5 s or 20 m), not one row per GPS fix.
- **No raw video.** Optional evidence crops, if approved, are files on disk referenced by path;
  the database stores only the path.
- **Preferences** use `UserDefaults`, not SwiftData.
- Domain models (sketch): `Drive(id, startedAt, endedAt?, vehicleName, distanceMeters, status,
  route, issues)`, `DetectedIssue(id, driveID, kind, confidence, detectedAt, coordinate,
  locationQuality, note?)`, `DriveSummary` (counts per kind, computed from issues; also what lists need without loading issues).

## 10. Camera architecture (M2)

- `LiveCameraService` owns one `AVCaptureSession` on a dedicated serial `DispatchQueue`
  (AVFoundation requirement). Marked `nonisolated`/actor-confined; **not** `@MainActor`.
- Input: back wide camera, `.hd1280x720` preset (enough for a 640-px model input, lower thermal
  cost than 4K), 30 fps, continuous autofocus, fixed zoom. Orientation locked to the mount
  orientation (portrait or landscape, see §15).
- Output: `AVCaptureVideoDataOutput` with `alwaysDiscardsLateVideoFrames = true`; the delegate
  yields frames into an `AsyncStream` with `.bufferingNewest(1)`.
- Preview: `CameraPreview` (`UIViewRepresentable` over `AVCaptureVideoPreviewLayer`) shares the same
  session. The preview and processing are independent; inference rate does not affect preview.
- Lifecycle: start on `InspectionSession.start`, stop on stop/cancel/scene-inactive. Handle
  `AVCaptureSession.wasInterrupted` and runtime errors with a bounded restart.
- Idle timer disabled while recording. Thermal and battery monitored by the session (§14).

## 11. Detection architecture (M2)

- `LiveDetectionService` is an `actor`. It loads a Core ML model compiled in the bundle, wrapped in
  `VNCoreMLModel`, and runs `VNCoreMLRequest` through `VNImageRequestHandler` with the frame's
  pixel buffer.
- **Model (current):** `best-3.pt`, YOLOv8s on the RDD road-damage dataset: Longitudinal, Transverse
  and Alligator Crack (all mapped to `crack`), Pothole, Other (ignored). It replaced
  `peterhdd/pothole-detection-yolov8`. PyTorch weights only, so we convert:
  `yolo export model=<weights>.pt format=coreml nms=True half=True imgsz=<training size>`
  (Ultralytics + coremltools, run offline from `tools/model/`, output committed as
  `Resources/PotholeDetector.mlpackage`; the Ultralytics Python package is a build-time tool only,
  never part of the app). The card does not state the input size or metrics; read both from the
  checkpoint and from our own validation (see REQUIREMENTS M2-T6, acceptance 5).
  Compute units `.all` (Neural Engine).
- **Limitation:** this model detects **potholes only**. Cracks and damaged signs (present in the UI)
  need another model later. Therefore `DetectionService` declares `supportedKinds: Set<IssueKind>`
  and the UI renders counters/filters from it; production shows only "Potholes" until a second
  model exists. Model metadata (`labels`, `supportedKinds`, input size, version) is read from a
  small `model.json` next to the model so replacing it needs no code change.
- **License risk (open, §15 #10):** Ultralytics YOLOv8 code and weights are AGPL-3.0 (or paid
  Enterprise license). The card declares Apache-2.0, but a model trained with Ultralytics tooling
  is generally treated as an AGPL derivative. For a commercial municipal product this needs a
  decision before shipping, not before development.
- **Dataset caveat:** public pothole datasets are mostly handheld/dashcam photos in daylight;
  windshield-mounted, glare, wet roads and night will degrade quality. Validate on our own footage.
- **Throttling:** process the newest frame only; target 5 to 10 inferences/s, adaptive: halve when
  `ProcessInfo.thermalState >= .serious`.
- **Post-processing:** confidence threshold per kind (configurable), NMS if the model does not do
  it, a region-of-interest crop to the road area (excludes dashboard/hood; depends on mount height
  and orientation).
- **Output:** `[RawDetection]` with normalized (0…1) rectangles in image space.
- **Deduplication (in `InspectionSession`/`IssueDeduplicator`, not in the detector):** a pure
  tracker, fed with each processed frame's detections and its timestamp. A detection continues a
  track of the same kind if it overlaps the track's last box or its motion-extrapolated box
  (IoU ≥ 0.2), lies mostly inside it (≥ 70 % of the smaller box), or appears within one box length
  of it (near the car the image motion accelerates). A track waits 2 s for its object, not a fixed
  number of frames, so a detector that flickers around its threshold does not split one pothole into
  several; two boxes on one object in the same frame count once (the most confident defines it).
  `DeduplicationSimulationTests` drives 200 simulated passes at a pothole with random misses, jitter
  and second boxes: the old tracker (1 missed frame, IoU ≥ 0.3 on the last box) produced 7.3 issues
  per pothole on average (up to 12); the current one produces exactly 1. Not covered: two real
  potholes that overlap in the image are merged; the same pothole passed twice more than 2 s apart
  counts twice.
- **Mock (M1):** `MockDetectionService` replays a scripted `[ScriptedDetection(at:, kind:, rect:)]`
  against an injectable `Clock`. The prototype's pothole/sign/crack sequence becomes the default
  script.

## 12. Location architecture (M2)

- `LiveLocationService` uses `CLLocationUpdate.liveUpdates(.automotiveNavigation)` (iOS 17+),
  yields `LocationSample(coordinate, horizontalAccuracy, speed, course, timestamp)`.
- Authorization: When-In-Use is enough while the app is in the foreground (screen stays on).
  "Always"/background location is **not** requested unless the pilot proves it is necessary
  (❓ §15).
- Filtering: drop samples with `horizontalAccuracy < 0` or > 50 m, or older than a few seconds;
  distance accumulates only between accepted samples, ignoring jitter below ~3 m while stationary.
- Missing/stale GPS never stops recording; issues get `locationQuality = .unavailable`.
- Mock (M1): `MockLocationService` walks a fixed polyline at constant speed, so distance, time
  and map coordinates are consistent in the prototype.

## 13. Future Supabase integration (M3, no work before)

- **Boundaries:** `supabase-swift` is imported only in `SupabaseSyncService` and `SupabaseAuthService`
  (`Services/Sync`). Domain models never carry Supabase types; DTOs map to/from `Core` models.
- **Backend (in `supabase/`):** tables `organizations`, `vehicles`, `drives`, `issues` (UUID PKs
  supplied by the client), geometry as `lat/lon` columns plus a PostGIS `geography(Point)` generated
  column for spatial queries; RLS by organization membership; Storage bucket only if evidence
  images are approved.
- **Sync algorithm:** push-only first. Select `pending|failed` records ordered by `updatedAt`, upsert
  in batches (50 to 200) with `on conflict (id)`, mark `synced` in one transaction after server
  acknowledgement; exponential backoff with jitter; stop on auth errors and surface them. Pull is
  added only if the product needs server-originated data in the app.
- **Auth:** session in Keychain; refresh handled by the SDK; the app works fully offline with a
  previously valid session; sign-out leaves local data unless the user chooses to delete it.
- **Config:** `Config/Debug.xcconfig`, `Release.xcconfig` (gitignored values), read via Info.plist
  substitution.
- The owner delivers the Supabase structure before M3 starts; M3's first step is reconciling the
  local models with it. Preparation done earlier (M2): UUID identity, `syncState`, `updatedAt`, `deletedAt`, a `SyncService`
  protocol and `NoopSyncService`.

## 14. Error handling and concurrency

### Error strategy

| Class | Examples | Behavior |
|---|---|---|
| **Blocking** | camera denied, model failed to load | Do not start; explain; offer remedy (Settings link, retry). |
| **Degraded** | GPS lost, thermal serious, low storage | Keep recording; show unobtrusive banner; mark data quality. |
| **Recoverable** | transient save failure, sync network error | Retry with limit/backoff; surface only after exhaustion. |
| **Programmer** | impossible state | `assertionFailure` in debug, safe fallback + log in release. |

Typed errors per capability, converted to user-facing text at the view-model layer. Recorded data
is persisted before any network activity. Logging via `os.Logger` with privacy annotations.

### Concurrency strategy

- Language mode 6; project default isolation is `MainActor`. Layers:
  - **Main actor:** Views, view models, `AppRouter`, `SettingsStore`.
  - **Actors / own queue:** `LiveDetectionService` (actor), `LiveCameraService` (serial queue,
    `Sendable` facade), repository `ModelActor`, `SyncService` (actor).
  - **Core:** value types, `Sendable`, `nonisolated` pure functions.
- **Cross-layer communication:** `AsyncStream`/`AsyncThrowingStream` with explicit buffering policy;
  `.bufferingNewest(1)` for frames, `.unbounded` never.
- **Ownership:** `InspectionSession` runs a `TaskGroup` (location task, camera→detection task,
  state aggregation). `stop()` cancels the group and awaits teardown; the view model holds the
  handle and cancels on disappearance of the Inspection cover.
- **Hand-off of `CVPixelBuffer`** across actors uses a small `Sendable` wrapper
  (`@unchecked Sendable`, buffer is never mutated after capture), documented in code.
- No `DispatchQueue.main.async`; no `Task.detached` unless isolation must be shed deliberately.
- Tests use fake streams and an injected `Clock`; no wall-clock sleeps.

### Navigation and UI structure

- `RootView` switches between the four screens and keeps the design's custom square tab bar (system
  `TabView` would apply the iOS 26 glass look, which the design does not use). The design has no
  push navigation, so there are no per-tab `NavigationStack`s; add one only when a screen needs it.
- Inspection is a `fullScreenCover` containing `InspectionFlowView`, which shows Live, then Summary
  (or a failure view), so the tab bar is hidden for the whole flow.
- Summary "Save" persists the drive then shows History; "View on map" saves, then shows the map
  focused on that drive; "Done" asks for confirmation if the drive is unsaved.
- The Map takes a `MapFocus` (`all | drive(id)`) from the router; History rows open the map focused
  on that drive. Since M2 the map is a real MapKit map (owner request), muted to the design's
  greyscale, with the design's square pins as annotations; `MapRegionFit` frames every pin with
  room for the header and card, and re-frames when the focus or filter changes. Issues without a
  GPS fix have no pin. `MapViewport` remains only to place the mock data and the mock route.

## 15. Open decisions (need owner approval)

| # | Question | Recommendation |
|---|---|---|
| 1 | **Swift 6 language mode** (project is currently `SWIFT_VERSION = 5.0`). | Enable now, in the first M1 step; the code base is tiny. |
| 2 | **Deployment target** is iOS 26.0 (Xcode default). Fleet phones may be older. | Lower to iOS 18.0 unless you want iOS 26-only APIs; everything in this plan works on iOS 18 (`@Observable`, SwiftData, `CLLocationUpdate`). |
| 3 | **Devices & orientation:** iPad is currently enabled; landscape is enabled; the design is portrait. Windshield mounts are often landscape. | iPhone only. Portrait-only UI for M1; decide landscape camera orientation before M2 from a real mount test. |
| 4 | **Map:** ✅ superseded: M2 uses a real MapKit map at the owner's request (muted style, same pins, header, filter and card). Earlier decision: keep the drawn map. MapKit vs. keeping the stylized drawn map. Because the design is frozen, M1 keeps the drawn map, but makes it data-driven: issues carry real `Coordinate`s which are projected into the map canvas from their bounding box. | Keep the drawn map for M1 (no design change). Revisit MapKit only if you later want a real map; the projection code is the only part that would change. |
| 5 | **Persistence:** SwiftData vs. GRDB. | SwiftData behind `DriveRepository`. |
| 6 | **Tab bar:** keep custom square tab bar vs. system `TabView`. | Keep custom (design fidelity); revisit only if accessibility issues. |
| 7 | **Font:** bundle Archivo (SIL OFL) vs. system font. | Bundle Archivo (variable font) in M1. |
| 8 | **Logo:** the extracted `logo.png` glyph strongly resembles a third-party AI brand mark. | Confirm it is intended; otherwise provide the final logo. |
| 9 | **Localization:** English only or English + German from the start. | Use a String Catalog now, English source; German added when requested. |
| 10 | **AI model:** ✅ chosen: `best-3.pt` (cracks and potholes; replaced the peterhdd model). Open: (a) **AGPL/Ultralytics license** for a commercial product, and the licence of these weights (not checked); (b) how cracks and signs are handled (UI shows only supported kinds in M2); (c) accuracy targets after our own validation. | Proceed with development; resolve (a) before any customer release. Hide cracks/signs in production UI until a model exists. |
| 11 | **Evidence images & privacy** (faces, license plates, GDPR). | Default: no images stored. Decide with data-protection input before M3. |
| 12 | **Backend & auth:** no Supabase project exists yet; owner will provide the structure before Milestone 3. M2 therefore designs the local records without knowing the server schema (generic UUID identity, `syncState`, timestamps), and M3 starts by reconciling local models with the delivered schema, which may need a SwiftData migration. Still open: tenant model (org/vehicle), auth method. | Org → vehicle → drive; email+password or magic link for pilot. No Supabase code and no schema assumptions beyond UUID identity before M3. |
| 13 | **Background location:** needed? | Assume not (screen stays on in a mounted phone). Validate in pilot. |
| 14 | **Document location:** repo root vs. inside Xcode project folder. | Repo root (done), keeps docs out of the app bundle and leaves room for `supabase/`. |
| 15 | **Uncommitted baseline:** the Milestone-0 design UI is not committed yet. | Commit it as a baseline before refactoring, on your request. |

## Appendix A — State of the code base before Milestone 1 (inspected 2026-10-26)

~950 lines, one target, no dependencies, flat folder `RoadSense/` with 10 Swift files.

**Implemented (as visual prototype, all mock):** six screens matching the design (Home, Live,
Summary, Map, History, Settings), custom tab bar, simulated live inspection, filtered map pins,
settings toggles. Builds cleanly, runs on iOS 26 simulator.

**Partially implemented:** state is in-memory only (settings do not persist); "Save" only navigates;
navigation is a single `Screen` enum, not a `NavigationStack`; map is a drawn canvas using the
design's 370×824 coordinate space; typography uses the system font instead of Archivo.

**Missing:** DI/services, domain models, persistence, permissions and Info.plist usage strings,
camera, Vision/Core ML, location, sync/auth, localization, accessibility work, dark mode (forced
light), tests beyond Xcode templates, error/empty/loading states.

**Architectural issues / tech debt for later milestones**
1. `AppModel` is a god object: navigation, live simulation timer, map filter, settings.
2. `Models.swift` mixes domain types, sample data and live-simulation logic.
3. Sample data hard-coded in model types; Summary shows constants (`11`, `24.6`, `38`, `Today, 09:41`)
   and the Summary timestamp.
4. Views read `AppModel` directly from the environment and navigate by mutating it.
5. Design-coordinate scaling (370×824) is baked into Live and Map; real camera and MapKit
   need geometry that is independent of screen size.
6. `Timer` in an `@Observable` class with no teardown; replaced by an injectable-clock stream.
7. Fixed font sizes ignore Dynamic Type; text styles mix `Text + Text` (deprecated, already removed).
8. Build settings: Swift 5 mode; iPad and landscape enabled; deployment target iOS 26; default
   actor isolation `MainActor` (good for UI, but infrastructure must opt out explicitly).
9. No `Info.plist` keys (fine for M1; required in M2).
10. Template tests (`RoadSenseTests`, `RoadSenseUITests`) are empty.

**Reusable as is:** color tokens, `RSRule`/`RSVRule`, `RSWordmark`/`RSLogo`, `RSBlockButtonStyle`,
all screen layouts (views), `IssueKind`, sample data (move to `PreviewSupport`), `SquareToggle`,
`DetectionBox`, `StylizedMap` (removed in M2 when the map became MapKit).

**Will need refactoring:** `AppModel` (split), `Models.swift` (split), `ContentView` (becomes
`RootView` + `AppRouter`), `RSTabBar` (move to DesignSystem), `MapScreenView` (data-driven focus),
`LiveView` (consumes `InspectionViewModel`, not timer state), `SummaryView` (data from `Drive`).

## Appendix B — Proposed Milestone 1 implementation order

Each step leaves the app building and visually unchanged unless noted.

0. **Baseline & decisions:** answer §15, optionally commit the current UI as a baseline;
   enable Swift 6 mode (and deployment/device settings per decisions); fix warnings.
1. **Folder restructure** with `git mv` into the §3 layout; split files without behavior change.
2. **Core models** (`Drive`, `DetectedIssue`, `IssueKind`, `Coordinate`, `DriveStatistics`) +
   formatting + unit tests.
3. **Service protocols and mocks** (`Location`, `Camera`, `Detection`, `DriveRepository`,
   `SettingsStore`, `Sync` stub) + `PreviewSupport` data; `InMemoryDriveRepository`.
4. **`InspectionSession`** coordinator against mocks, with injectable clock; tests (state, counts,
   distance, completion).
5. **`AppEnvironment` + `AppRouter` + `RootView`:** per-tab `NavigationStack`, Inspection as
   full-screen cover, post-drive flow; remove `AppModel`.
6. **View models** for Home, Inspection, Summary, Map, History, Settings; wire views to them;
   Summary/History/Home show repository data; "Save" persists to the in-memory repository;
   settings persist through `SettingsStore`.
7. **DesignSystem extraction:** tokens, bundled Archivo, reusable components; features lose raw
   styling; String Catalog adoption.
8. **Data-driven stylized map:** keep the drawn map, project issue coordinates into it, add `MapFocus`.
9. **States and polish:** empty/loading/error/permission-placeholder states, accessibility pass,
   previews for every state.
10. **Verification:** unit tests green, UI smoke test (start → stop → save → history → map),
    simulator walkthrough against the design, zero warnings, docs reconciled with code,
    acceptance criteria checklist from `REQUIREMENTS.md` ticked.

## Appendix C — Milestone 1 as built

Differences between the plan above and the code, and things to know before Milestone 2:

- **Settings applied:** Swift 6 language mode, deployment target iOS 18.0, iPhone only, portrait only.
- **No `changes()` stream, no `append`, no per-tab `NavigationStack`:** not needed yet (see §7, §14).
  M2 adds incremental persistence and recovery of unfinished drives.
- **`Drive` vs `DriveSummary`:** lists load summaries only. The seeded mock summaries intentionally
  do not equal the number of seeded map issues (design shows 43 issues over five drives but only
  seven map pins); real data is consistent because a summary is computed from a drive's issues.
- **Distance starts at 0.0 km** on a new inspection (the prototype started at 0.4 km); the mock
  drives at 40 km/h along a straight line inside the demo map viewport.
- **Mock detection** replays the prototype's pothole/crack/sign timeline; `InspectionSession`
  de-duplicates sightings, so counters count issues, not frames.
- **New states built from existing components** (flag for owner review): empty Home/History lists,
  load-error message with "Try again", camera-denied "Can't start" screen, empty map card, "Discard
  this drive?" confirmation, GPS "Searching"/"Location off" labels.
- **Locale:** numbers and dates follow the device region (the simulator uses a German region, so
  "24,6 km"). The design's English copy is the source language of the string catalog; the catalog
  fills in when the project is built in Xcode.
- **Debug launch arguments** (`-RS_SCREEN home|live|summary|map|history|settings`,
  `-RS_CAMERA_DENIED YES`) exist only in DEBUG builds, for screenshots and UI tests.
- **Logo:** still the glyph extracted from the design's `logo.png` (see §15 #8).
- **Tests:** 61 unit tests (Swift Testing) plus 3 UI smoke tests; `ManualClock` and fakes live in
  `RoadSenseTests/Support/`.

## Appendix D — Milestone 2 as built

What exists, how it differs from §7 to §12, and what is **not** verified yet.

**Model (facts measured from the checkpoint)**

- Current: `best-3.pt` (YOLOv8s, Ultralytics 8.4.71, Kaggle, 100 epochs, 640 × 640, RDD data):
  classes Longitudinal Crack, Transverse Crack, Alligator Crack, Pothole, Other. Checkpoint metrics
  over all classes: precision 0.66, recall 0.58, mAP@0.5 0.63 (per class not available). The file is
  byte-identical to the earlier `best-2.pt`.
- **It does not find potholes on the photos tried.** On 5 close-up pothole photos (water-filled
  potholes from the validation montage published with `peterhdd/...`) it reported none even at
  conf 0.05, where YOLOv8m and YOLOv9c found them at 0.8 to 0.9. Those photos differ from the RDD
  domain, so this says little about windshield footage; it needs validation on real footage before
  anyone relies on its pothole class. Its crack classes do fire (alligator, transverse).
- Previous models, all replaced: `peterhdd/pothole-detection-yolov8` (mAP@0.5 0.39); YOLOv8m
  (`Yolov8-fintuned-on-potholes.pt`, mAP@0.5 0.69); YOLOv9c (`yolov9c.pt`, one class, mAP@0.5
  0.79, 25.5 M parameters). Their files are still in `tools/model/`.
- Exported by `tools/model/convert.py` (Ultralytics 8.4.189, coremltools 9.0, FP16, NMS inside the
  package) to `Resources/Models/PotholeDetector.mlpackage` plus `model.json`. Class names map to
  app kinds by name in the script; unmapped classes are ignored. Re-run it to replace the model
  (`--weights` selects the file). Core ML output equals PyTorch for the same input, and
  `LiveDetectionServiceTests` checks the full pipeline against a PyTorch reference box.
- **Confidence.** The app reads `VNRecognizedObjectObservation.confidence`, the detection score.
  Do not use `labels[].confidence`: Vision reports it normalized to sum 1 per box (0.999 for a box
  whose score is 0.41). The exported package's confidence output has 80 columns for 5 classes
  (unused columns are 0). Scores on borderline images vary by about ±0.15 with the resampling
  method, even in PyTorch alone.
- **Caveats.** All metrics are from the training run's own dataset, not windshield footage. The
  licence of these weights is not checked; the Ultralytics AGPL question (§15 #10) applies too.

**Pipeline**

`LiveCameraService` (portrait 720p BGRA, `.bufferingNewest(1)`, own serial queue) →
`InspectionSession` (thermal throttle, 0.1 s / 0.4 s / 1 s between inferences) →
`LiveDetectionService` (actor): crop `RoadRegion` (depends on mount height), letterbox to 640 with
`FrameLetterboxer` (Core Image, gray 114 padding), Vision with `.scaleFill`, map boxes back through
`Letterbox.toSource` and `NormalizedRect.mapped(from:)`. Letterboxing is done by the app, not by
Vision's `.scaleFit`, so the box mapping is deterministic and unit-tested. Boxes are shown with
`NormalizedRect.aspectFilled` to match the aspect-fill preview.

**Persistence**

- `SwiftDataDriveRepository` (`@ModelActor`), `RoadSenseSchemaV1` + `RoadSenseMigrationPlan`;
  `DriveEntity`/`IssueEntity` never leave `Persistence/`. Sync fields (`syncState`, `updatedAt`,
  `deletedAt`) exist and stay `pending`.
- Protocol additions: `append`, `checkpoint`, `delete`, `recoverUnfinishedDrives`. `Drive` gained
  `status` (`inProgress | finished`) and `route`; `DetectedIssue` gained accuracy, speed, heading.
- Crash safety: the drive is stored `inProgress` before the first frame, each issue is appended
  immediately, totals are checkpointed every 10 s. The Summary's **Save** finalizes the drive,
  **Discard** deletes it (M1's behavior is unchanged). A drive still `inProgress` at the next
  launch is finished by `AppEnvironment.recoverUnfinishedDrives()` and shows up in History.
  In-progress drives are excluded from lists, totals and the map.

**Wiring**

- `AppEnvironment.live()` is the default on a device; `.mock()` is used when the app runs in the
  simulator (it has no camera) or with `-RS_USE_MOCKS YES`; `-RS_USE_LIVE YES` forces live in the
  simulator. If the model or store cannot open, the app shows "Can't start" instead of falling back
  to mocks (that would silently lose data).
- Auto-start: `MovementDetector` (3 samples ≥ 4 m/s, re-arms below 1.5 m/s), watched on Home only
  while location is already authorized and no inspection is open; off for mocks.
- Alert sound: `AlertService` (system sound), honors the Settings toggle.
- **Info.plist (build settings):** `INFOPLIST_KEY_NSCameraUsageDescription` and
  `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` added to both app configurations.
- Idle timer disabled while the live screen is shown.

**Not done / not verified (needs a physical iPhone or owner input)**

- Camera preview, real GPS, interruptions (call, backgrounding), thermal behavior and the 30-minute
  performance budget (M2-T8/T9) are implemented but have **never run on a device**.
- Battery monitoring: not implemented (thermal throttling is).
- No banner for degraded states (GPS lost, approximate location only, serious thermal state):
  issues are saved without coordinates and the pipeline slows down silently. A banner needs a
  design decision.
- `RoadRegion` values and the 0.3 confidence threshold are starting values, not tuned.
- Validation on labelled mounted-phone footage (acceptance 5) and the licence decision (§15 #10).
- Camera orientation is portrait. A landscape windshield mount is still an open decision (§15 #3).
- The test fixture `RoadSenseTests/Fixtures/portrait-frame-with-pothole.jpg` is built from a tile of
  the validation montage published with the model; its image licence is unknown.
- Gotcha: after changing `AppEnvironment` or other widely used types, run `xcodebuild clean` before
  testing; a stale incremental build crashed the test host with `swift_retain` bus errors.

