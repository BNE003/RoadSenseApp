# REQUIREMENTS.md — RoadSense

> **Status: PROPOSED**, pending owner approval. Requirement IDs are stable; reference them in
> commits and reviews. Items marked ❓ depend on an open decision in `ARCHITECTURE.md` §15.

## Product summary

RoadSense lets a municipal vehicle inspect roads passively. A mounted iPhone detects potholes,
cracks and damaged signs with on-device AI, attaches GPS coordinates, stores everything locally and
syncs to Supabase for the municipality's maintenance team.

**Personas**
- **Driver:** starts an inspection before driving, ends it after. Glances only.
- **Maintenance staff:** reviews drives, issues on a map, history. (M1 to M3: on the same iOS app.
  A web dashboard is out of scope for this document.)

**Domain vocabulary:** *Drive* (one inspection session), *Issue* (one detected damage),
*IssueKind* = pothole | crack | sign.

---

## Milestone 1 — UI & App Foundation

### Goal
A fully navigable, production-quality UI and code foundation running entirely on mock services,
so that Milestone 2 can replace mocks with real implementations without touching feature UI.

### Functional requirements

| ID | Requirement |
|---|---|
| M1-F1 | **Home** screen: wordmark + date, "Ready to drive." headline, GPS status and vehicle row, "Start inspection" primary action, "Recent" list (latest 2 drives from the repository) with "All" link. |
| M1-F2 | **Live inspection** screen (full screen, hides tab bar): camera placeholder, "Recording" indicator, elapsed time, distance, live counters (potholes, cracks, signs), detection boxes with labels, "End inspection". Driven by a mock detection/location source. |
| M1-F3 | **Drive summary** screen: total issues, distance, duration, per-kind breakdown with proportional bars, "View on map", "Save". All values computed from the finished `Drive`. "Save" stores the drive in the (in-memory) repository; "Done" leaves without saving after confirmation if unsaved. |
| M1-F4 | **Map** screen: issue pins, filter (All / Potholes / Cracks / Signs), selection with detail card (kind, when, street, note), issue count. Opening from Summary/History focuses that drive's issues. |
| M1-F5 | **History** screen: drives grouped by section, header totals computed from data, row opens the Map focused on that drive. |
| M1-F6 | **Settings** screen: vehicle, mount height (Low/Standard/High), toggles (auto-start, alert sounds, Wi-Fi-only upload), units, app version read from the bundle. Values persist across launches. |
| M1-F7 | Custom bottom tab bar (Home, Map, History, Settings) visible on the four main screens, hidden during Live and Summary. |
| M1-F8 | Navigation: each tab keeps its own navigation state; Live is presented full screen; Summary follows Live; back/"Done" behave predictably; no dead-end screens. |
| M1-F9 | Empty, loading and error states for Home recent list, History, Map (no issues). Permission-denied placeholder for the camera on Live (UI only; real permission in M2). |
| M1-F10 | Visual fidelity to the Claude Design prototype: layout, colors, 2 pt rules, square corners, type scale. Deviations are documented. |

### Technical requirements

| ID | Requirement |
|---|---|
| M1-T1 | Folder structure and layering as defined in `ARCHITECTURE.md` §3; the single flat folder and `AppModel` god object are removed. |
| M1-T2 | Swift 6 language mode enabled, zero warnings, zero concurrency diagnostics. |
| M1-T3 | `AppEnvironment` DI container with `.mock` configuration; views/view models contain no hard-coded sample data. |
| M1-T4 | Service protocols defined and mock-implemented: `LocationService`, `CameraService`, `DetectionService`, `DriveRepository`, `SettingsStore`; `SyncService` protocol stubbed. Protocols contain only what Milestones 2 and 3 are known to need. |
| M1-T5 | Domain models in `Core/` (`Drive`, `DetectedIssue`, `IssueKind`, `Coordinate`, `DriveSummary`), `Sendable`, independent of UI and persistence. |
| M1-T6 | Mock detection produces a deterministic, scriptable timeline (the prototype's behavior), driven by an injectable clock so tests do not sleep. |
| M1-T7 | `DesignSystem` module-in-folder: tokens (color, type, spacing) and reusable components (rule, stat tile, primary block button, segmented filter, square toggle, section header, list row, tab bar, wordmark). Features use no raw hex values. |
| M1-T8 | Every screen has a working `#Preview`; every view model has unit tests. |
| M1-T9 | String Catalog in place; all UI strings localizable (English source). ❓ German |
| M1-T10 | Accessibility baseline: VoiceOver labels, 44 pt targets, Dynamic Type does not truncate core numbers or hide actions. |
| M1-T11 | Archivo font bundled and registered (OFL) or an explicit decision to use the system font. ❓ |
| M1-T12 | Info.plist / capabilities unchanged except what M1 needs (none). Camera/location permission strings are **not** added until M2. |

### Explicit non-goals
- **No visual redesign.** The existing implemented design is frozen; M1 is a code and structure
  milestone. Pixel-level differences versus the current screens are bugs, except bundling Archivo,
  which makes the app match the original design more closely.
- No `AVCaptureSession`, Vision, Core ML, `CLLocationManager`, SwiftData, Supabase or networking.
- No real authentication, accounts, or onboarding flow.
- No iPad-specific layout, dark mode, landscape, widgets, Live Activities, CarPlay.
- No real map tiles or geocoding: the stylized map from the design stays; issues keep a street label as data.
- No analytics or crash-reporting SDKs.

### Acceptance criteria
1. App builds with Xcode 26 on the iOS 26 simulator, **0 warnings**, Swift 6 mode.
2. Side-by-side screenshots of all six screens (current baseline vs. after M1) show no visual
   difference apart from data now coming from models and Archivo replacing the system font.
   A reviewer can complete the flow Home → Start → (observe detections) → End → Summary → Save →
   History → open drive → Map, and every screen matches the design.
3. The History list contains the saved drive; Home "Recent" updates; counts and distances in Summary
   equal the sum of what Live displayed.
4. Toggling a setting, force-quitting and relaunching preserves it.
5. Replacing `AppEnvironment.mock` with a different environment requires no change in `Features/`
   (demonstrated by a test environment with fakes).
6. `grep` finds no `AVFoundation`, `Vision`, `CoreML`, `SwiftData`, `Supabase` imports in the
   repo, except in files explicitly allowed by the plan.
7. All unit tests pass; view models for Home, Inspection, Summary, Map, History, Settings are covered.
8. Previews compile for all screens including empty/error states.
9. `ARCHITECTURE.md` matches the actual folder layout.

---

## Milestone 2 — AI Detection & Local Data

### Goal
A driver can run a real inspection: the camera feed is analyzed on device, detections are tied to
GPS positions and stored durably on the phone, even with no network.

### Functional requirements

| ID | Requirement |
|---|---|
| M2-F1 | Live screen shows the real camera preview; Start requests camera and location permission in context and handles denial with clear guidance and a Settings link. |
| M2-F2 | Detects **potholes** in real time with the chosen model (`best-3.pt`: `Pothole` plus three crack classes mapped to `crack`; replaced `peterhdd/pothole-detection-yolov8`); boxes and labels are drawn over the preview; the pothole counter updates live. Cracks and damaged signs are **not** detected in M2 (the model does not know them): the Inspection and Summary UI show only the kinds the active `DetectionService` reports as supported, so no permanently-zero counters appear. |
| M2-F3 | Each distinct issue is stored once with kind, confidence, timestamp, coordinate (accuracy, heading, speed), and the owning drive. The same physical issue seen in consecutive frames is not counted repeatedly (deduplication). |
| M2-F4 | Drive records distance (from GPS), duration, route breadcrumb, start/end time. |
| M2-F5 | Summary, History, Map show **real** stored data. Mock repository is no longer used in the production environment. |
| M2-F6 | Inspection survives interruptions: phone call, app backgrounded briefly, thermal throttling, GPS loss. Recording state recovers or ends gracefully with data saved. |
| M2-F7 | Auto-start (setting) begins an inspection when movement is detected and the app is in the foreground. |
| M2-F8 | Alert sound on detection if enabled in Settings. |
| M2-F9 | Mount-height setting influences detection geometry/calibration parameters (at minimum: stored and passed to the detector). |
| M2-F10 | Unfinished drive found at launch (crash/kill) is recovered and offered in History. |

### Technical requirements

| ID | Requirement |
|---|---|
| M2-T1 | `LiveCameraService` (AVFoundation) delivers frames as a back-pressured `AsyncStream`, preview via `AVCaptureVideoPreviewLayer`; session control off the main thread. |
| M2-T2 | `LiveDetectionService` uses Vision + a bundled Core ML model; inference off the main actor, throttled (target ≥ 5 inferences/s on iPhone 13-class devices; frame dropping, never queue growth). |
| M2-T3 | `LiveLocationService` using `CLLocationUpdate.liveUpdates`, accuracy filtering, authorization state surfaced as a stream. |
| M2-T4 | `InspectionSession` coordinator joins frames, detections and the latest location sample, applies dedup, writes issues to the repository, exposes state to the view model. |
| M2-T5 | SwiftData persistence behind `DriveRepository`; domain models mapped at the boundary; schema versioned from day one; each issue has a client-generated UUID and a `syncState` (`pending` for now). ❓ |
| M2-T6 | Model: `best-3.pt` (YOLOv8s, 5 classes: 3 crack types, pothole, other; the earlier choice `peterhdd/pothole-detection-yolov8` was replaced). Converted from the `.pt` file to Core ML (`.mlpackage`, NMS included, FP16, input size confirmed from the checkpoint) by a script kept in `tools/model/` (not part of the app target). Input size, labels, provenance and **license review result** documented in `ARCHITECTURE.md` §11. Model is replaceable without code changes (labels and supported kinds come from model metadata/config). |
| M2-T6a | **License gate before shipping:** the weights derive from Ultralytics YOLOv8 (AGPL-3.0 / commercial Enterprise license), while the model card states Apache-2.0. Owner decides, before M2 ships to customers, whether this is acceptable (legal review or an Ultralytics Enterprise license, or a different detector). Development and internal testing may proceed. |
| M2-T6b | `DetectionService` exposes `supportedKinds`; adding a second model (cracks, signs) later must not require UI changes. |
| M2-T7 | Info.plist: `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription` (and background location only if proven necessary ❓). |
| M2-T8 | Idle timer disabled during inspection; thermal state and battery monitored; sampling rate degrades under `serious` thermal state. |
| M2-T9 | Performance budget measured on device: sustained 30-min inspection without crash, thermal state ≤ `fair` at typical ambient, memory stable (no growth > 50 MB over 30 min). |
| M2-T10 | Unit tests for dedup, distance accumulation, repository, session coordinator with fake streams; recorded-video or still-image fixture test for the detector (accuracy smoke test). |
| M2-T11 | Logging via `os.Logger`; no location or image data in logs. |

### Explicit non-goals
- No networking, Supabase, accounts or sync (issues stay `pending`).
- No storing or uploading raw video. Evidence crops only if approved ❓.
- No training pipeline or model-improvement tooling; no custom model training in the app repo.
- No crack or damaged-sign detection (not covered by the chosen model; a second model is a later
  decision).
- No background (screen-off) recording, no CarPlay, no iPad.
- No road-surface roughness via accelerometer (possible future signal).
- No severity grading beyond what the model outputs directly.

### Acceptance criteria
1. On a physical iPhone mounted in a car, a ≥ 20-minute drive completes with the app in the
   foreground; the drive and its issues are stored and shown in Summary, History and Map.
2. Permission denial paths work (camera denied, location denied, location "approximate only").
3. Killing the app mid-drive and relaunching shows a recoverable drive with all issues stored so far.
4. Airplane mode does not affect recording.
5. The model card publishes no numeric metrics, so M2 includes a validation step: run the converted
   model on a labelled set of footage from the actual mounted-phone setup (to be collected with the
   owner; ≥ 200 pothole sightings and a comparable amount of negative road footage) and report
   precision/recall. Targets are set with the owner after the first measurement (placeholder:
   ≥ 0.6 mAP@0.5). The Core ML output must also match the original PyTorch/ONNX model on a fixed
   set of test images (same boxes within tolerance).
6. Dedup test: a pothole visible for 3 seconds yields exactly one issue.
7. No inference or frame processing occurs on the main thread (verified with Instruments / Main
   Thread Checker).
8. All M1 acceptance criteria still hold with the production environment.

---

## Milestone 3 — Supabase Integration & Complete MVP

### Goal
Detected data flows reliably from the vehicle to the municipality's Supabase backend, with
authentication, so the end-to-end MVP is usable by a real pilot customer.

### Functional requirements

| ID | Requirement |
|---|---|
| M3-F1 | Sign in / sign out with Supabase Auth (method ❓: email+password, magic link, or SSO). Session persists securely and refreshes. |
| M3-F2 | Drives and issues sync automatically when conditions allow (connectivity; Wi-Fi only if the setting is on) and manually via a "Sync now" action. |
| M3-F3 | Sync status visible per drive and globally (pending / syncing / synced / failed with retry). |
| M3-F4 | Sync is **idempotent and resumable**: interrupted uploads continue; no duplicates on the server. |
| M3-F5 | Vehicle and organization are associated with uploaded data (settings screen selects/shows the vehicle). ❓ |
| M3-F6 | Optional evidence image per issue, if approved ❓: uploaded to Supabase Storage with privacy safeguards. |
| M3-F7 | History/Map can show issues that exist on the server for the organization (read side), clearly distinguished from local-only ones. ❓ scope |
| M3-F8 | Graceful handling of expired session, revoked access, server errors, and offline use. |
| M3-F9 | Account deletion / data-removal path required for App Store compliance. |

### Technical requirements

| ID | Requirement |
|---|---|
| M3-T1 | `supabase-swift` added via SPM, pinned; used only inside `Services/Sync` and an `AuthService`. No Supabase types in `Core` or `Features`. |
| M3-T2 | Backend schema (tables, indexes, PostGIS for geometry if used), Row Level Security policies and migrations kept in `supabase/` in the repo and versioned. |
| M3-T3 | `SyncService` implementation based on an outbox (`syncState` on records), exponential backoff, batch upserts keyed by client UUID, conflict policy "server never overwrites local detections". |
| M3-T4 | Auth tokens stored in Keychain; URL and anon key from `.xcconfig`, not committed. |
| M3-T5 | Sync runs in a structured, cancellable task; observes connectivity via `NWPathMonitor`; background upload via `URLSession` background configuration only if justified ❓. |
| M3-T6 | Environments: at least `development` and `production` Supabase projects selectable by build configuration. |
| M3-T7 | Integration tests against a local Supabase (CLI) or a dedicated test project; unit tests for the outbox with a fake remote. |
| M3-T8 | Observability: structured logs; crash reporting only if approved ❓. |
| M3-T9 | App Store readiness: privacy manifest, privacy nutrition labels, usage strings, App Review notes for camera/location, TestFlight distribution. |
| M3-T10 | All previous milestones' acceptance criteria still hold. |

### Explicit non-goals
- No municipal web dashboard, GIS export, or work-order management.
- No multi-device real-time collaboration, push notifications, or in-app chat.
- No server-side AI inference or re-classification pipeline.
- No Android client.
- No custom backend beyond Supabase (Postgres, Auth, Storage, optionally Edge Functions).

### Acceptance criteria
1. A signed-in user completes a drive offline; when connectivity returns, all drives and issues
   appear in Supabase exactly once (verified by row counts and UUIDs).
2. Killing the app during upload and relaunching completes the sync without duplicates.
3. User A cannot read or write user/organization B's data (RLS tests pass).
4. "Wi-Fi only" setting is respected (verified with network conditioner/cellular).
5. Expired/invalid session routes to sign-in without losing local data.
6. Account deletion works end to end.
7. TestFlight build is installed on at least two physical devices and a full pilot-day scenario
   (sign in, 2 drives, offline then online) is performed successfully.
8. Zero known data-loss bugs; zero warnings; all tests green; docs updated.
