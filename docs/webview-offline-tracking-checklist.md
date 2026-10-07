# DynaOps App — Angular-in-Flutter WebView, Background Tracking & Offline Tracking Queue

Implementation checklist for hosting the existing **DynaOps365** Angular application inside the **dynaopsapp** Flutter shell on Android, with native background location tracking, a local SQLite queue for fixes captured offline, a sync manager that batches them when connectivity returns, and a versioned Angular ↔ Flutter bridge.

Produced from a read-through of both repositories plus the reference document *"Angular + Flutter WebView + Offline-First + Background Tracking Architecture"*. Decisions were taken on **2026-10-05** (see §0). It is a **plan and checklist only** — nothing has been implemented yet.

| Legend | Meaning |
|---|---|
| `[ ]` | Not started |
| `[~]` | In progress |
| `[x]` | Done and verified on a device |
| **OPEN** | Still needs an answer; a working assumption is stated so work is not blocked |
| **ANGULAR** | A small, additive change on the Angular side (no rewrite) |
| **DEFERRED** | Explicitly out of scope for this release, kept for later |
| **LEGACY** | Old DynaOps tracker integration (`dyngis://`, hand-off). Stays in the Angular project **unchanged**; the Flutter shell neither uses nor handles it |
| **FUTURE** | Planned next phase (offline business features, §10.2): in the plan, **not to be implemented now** |

**Before implementing any milestone:** follow the project skills (§3) and the file header rule (§3.1). Every Dart file under `lib/` you create or edit gets a short header doc comment.

Repos referenced (paths are relative to this file):

* Angular: [`../../DynaOps365`](../../DynaOps365) — Angular 19, standalone + signals, Transloco, PrimeNG, PWA (ngsw), nswag clients.
* Flutter: [`..`](..) — Flutter 3.47.3 / Dart 3.13.3, AGP 9.1.0, Kotlin 2.4.0, Java 17, compileSdk 36, minSdk 24 (Flutter default), bare counter template today.

---

## 0. Decisions (answered 2026-10-05)

| # | Topic | Decision |
|---|---|---|
| D1 | Existing "DynaOps tracker" app (`dyngis://`) | **dynaopsapp replaces it and has nothing to do with it.** Session and sign-out reach the shell only through the native bridge (`auth.setSession` / `auth.signOut`, §7). Everything tracker-related (`tracker-link.ts`, `handoff.ts`, `dyngis://`) stays in the Angular project **unchanged** for the browser/PWA. The Flutter shell contains no tracker code, and Angular's new native code sits beside the tracker code and never edits it. |
| D2 | How Angular is loaded | **OPEN.** Working assumption: load the **deployed web URL** (remote). This fits D7 — only tracking works offline, so the UI needs the network anyway. Bundling the build into the APK is **DEFERRED**. *Still needed from you: the web hostname per tenant.* |
| D3 | Background location stack | **Free stack:** `flutter_foreground_task` + `geolocator`, behind an interface so the engine can be swapped later. |
| D4 | WebView plugin | **`flutter_inappwebview`.** |
| D5 | Location upload ("ping") API contract | **Resolved 2026-10-06** from the API contract the old tracker (dyn_gis) already uses: `POST {apiBase}LocationPings/batch` with `{ pings: [{ at: "yyyy-MM-ddTHH:mm:ss" (naive, device-local by default, `PING_TIMESTAMPS=utc` flips it), lat, lng, speedKmh: int, headingDeg: int, source: "Gps" }] }`; bearer token identifies the user. 2xx accepted; 401 token refused; 400/413/422 never accepted; else retry. **No dedupe key** exists, so a retry after an ambiguous timeout can duplicate points. Only the contract is reused; nothing depends on that app. |
| D6 | Token refresh | **No refresh token.** The shell keeps collecting fixes after `expireAt`, pauses uploads, and resumes on the next login. |
| D7 | Offline scope | **Tracking only for now.** Fixes are stored locally when offline and uploaded in batches when online. Offline for other features (sales orders first) is a **planned future phase** — in the plan (§10.2, M4) but not to be implemented in this release. |
| D8 | Who decides when tracking runs | **Confirmed:** tracking **auto-starts whenever the shell has a valid session** (on launch and right after login via `auth.setSession`) and runs in the background until sign-out; the rep never presses Start and cannot switch it off from the app. Rules in §8.1. |
| D9 | Tenant / environment | **Per-tenant builds** (Android product flavors + `--dart-define`). |
| D10 | Local database | **`sqflite`** (no codegen). |
| D11 | Final Android `applicationId`, label, icon, keystore | **OPEN.** Development continues on the template id; must be set before the first release build. |
| D12 | Min Android version & test devices | **Decided here:** minSdk **24** (Flutter default, Android 7.0), targetSdk 36. Test matrix: Android 10, 11, 12, 13, 14, 15 as priority, one Android 8/9 device if the fleet still has any; OEMs Samsung, Xiaomi/Redmi, Huawei/Honor, Oppo/Realme/Vivo, Pixel (reference). |
| D13 | Login surface | **Angular login page stays the only login UI.** |
| D14 | PDF print / share on the phone | **Required** → `files.save / files.share / files.print` bridge actions + a small Angular hook. |
| D15 | Error / crash reporting | **Flutter shell reports its own errors natively** (PostHog Flutter SDK, same PostHog project as the web app); **Angular keeps its existing PostHog** error handling for everything that happens inside the web app. |
| D16 | Google Maps JS key referrer | **Not applicable while D2 = remote URL** — the key already allows the web host. Revisit only if the build is ever bundled and served from `localhost`. |
| D17 | iOS | **Out of scope.** |

### 0.1 Ground rules: the old tracker and the new shell both keep working

| Goal | How the plan guarantees it | Verified by |
|---|---|---|
| **G1 — The old tracker works exactly as today** (browser/PWA → `dyngis://` → tracker app) | Angular tracker code (`tracker-link.ts`, `handoff.ts`, `dyngis://`) is not modified (§18). Every new Angular change runs only when `isNative()` is true, i.e. only inside the shell; in Chrome/PWA `window.DynaOpsNative` does not exist, so behaviour is byte-for-byte the same. The shell does not register `dyngis`, so it never steals the tracker's links (§4). | §17.2 "Old tracker regression" row |
| **G2 — The new shell works on its own** (WebView + tracking + offline queue + bridge features) | The shell needs nothing from the tracker: session via `auth.setSession`, tracking from its own foreground service, uploads from its own queue (§7–§11). | §17.2 rows, M1/M2 exit criteria |

- [ ] **Release order:** deploy the Angular `core/native/` changes to the web host **before** the first shell build goes to reps. They do nothing in the browser (G1), and without them the shell never receives a session, so tracking never starts (G2).
- [ ] **OPEN — both apps on one phone:** a rep who has the old tracker installed *and* uses the shell would run two trackers and upload duplicate points for the same user. Working assumption: rollout replaces the tracker (uninstall it when the shell is installed, via MDM or instructions). Optional: the shell detects the old tracker's package (`<queries>` + `device_info`/package check) and shows a one-time "please uninstall the old tracker" notice. *Needed from you: the old tracker's Android package name, and whether the server de-duplicates points (D5).*

---

## 1. Facts from the two repos that shape the plan

Read these before touching code; several "obvious" designs are wrong because of them.

The next three facts describe how Angular talks to the **old tracker**. They stay in Angular unchanged and the shell does **not** use them (D1, §7). They are listed only so the new native code in Angular branches *around* them (§7, §18).

- [ ] LEGACY: Angular has a **hand-off protocol** built for the old tracker: on boot, before `bootstrapApplication`, [`adoptHandoffSession()`](../../DynaOps365/src/app/core/auth/handoff.ts) reads `#handoff=<base64url JSON>` from the URL fragment, writes it to `localStorage['int-auth_token']`, strips the fragment, and the app starts signed in. `#signout` clears everything except language and the two tracker keys.
- [ ] LEGACY: Angular **sends** `dyngis://signin?handoff=<base64url>` right after a password login ([`AuthService.login`](../../DynaOps365/src/app/core/auth/services/auth.service.ts) → `handOffToTracker`) and `dyngis://signout` on a *deliberate* sign-out. A 401 or token expiry calls `logOut()` **without** notifying the tracker on purpose — tracking must survive those.
- [ ] LEGACY: `canReachTracker()` only fires the scheme when `localStorage['int-dyngis_tracker'] === 'true'` **or** the page is a standalone PWA on Android. Inside a WebView it is normally false; in the shell, `AuthService` takes the native branch before ever reaching these calls (§7), so `tracker-link.ts` needs no edit. The idea worth copying is the *semantics*: deliberate sign-out vs. 401/expiry. The bridge has its own version of it (`auth.signOut{deliberate}`).
- [ ] Token storage: `LocalStorageService` prefixes every key with `int-`; the token key is `auth_token`; the HTTP interceptor sends `Authorization: bearer <jwt>` (lower-case) and `Accept-Language: en|ar` ([`token.interceptor.ts`](../../DynaOps365/src/app/core/interceptors/token.interceptor.ts)).
- [ ] Browser GPS is used **only for one-shot reads**: [`DeviceLocationService.current()`](../../DynaOps365/src/app/shared/services/device-location.service.ts) (`getCurrentPosition`, `maximumAge` 60 s) feeds the check-in geofence in [`VisitExecutionService`](../../DynaOps365/src/app/feature-pages/field-sales/services/visit-execution.service.ts) and the location-request capture screen. There is no `watchPosition` anywhere. One service to re-route through the bridge.
- [ ] `DayStartRequest` in [`day-stamps.service.ts`](../../DynaOps365/src/app/feature-pages/field-sales/services/day-stamps.service.ts) can carry `latitude/longitude/from` but the web app currently sends nothing. The shell can supply the fix.
- [ ] The rep's mobile surface is the **full-screen** `/field-sales/my-journey` route (outside `LayoutComponent`, see [`app.routes.ts`](../../DynaOps365/src/app/app.routes.ts)). It suppresses the app-wide "rotate your tablet" overlay and works in either orientation; the rest of the app prefers landscape on tablets ([`device-orientation.service.ts`](../../DynaOps365/src/app/core/services/orientation/device-orientation.service.ts) tries `screen.orientation.lock('landscape')`, which fails in a WebView and falls back to the overlay).
- [ ] PWA machinery that must be neutralised in the shell: `provideServiceWorker('ngsw-worker.js', { enabled: !isDevMode() })` in [`app.config.ts`](../../DynaOps365/src/app/app.config.ts); [`PwaUpdateService`](../../DynaOps365/src/app/core/services/pwa/pwa-update.service.ts) reloads on every update; [`VersionCheckService`](../../DynaOps365/src/app/core/services/version-check.service.ts) compares `assets/version.json` and reloads; [`PwaInstallService`](../../DynaOps365/src/app/core/services/pwa/pwa-install.service.ts) + install button; `beforeinstallprompt` capture in `index.html`. With remote loading (D2) the update/version reloads are harmless but pointless; the install button must go.
- [ ] SignalR: `hubs/permissions` (whole session) and `hubs/tracking` (supervisor live screen only). WebSockets work in WebView; nothing to do, but the shell must not block them.
- [ ] `RepSyncService` → `DynaMasterDataSync/RunCustomerScreen` is a **server-side** master-data sync to Dynamics, *not* an offline sync. Do not reuse the word "sync" for it in the shell.
- [ ] Browser APIs used by the field-sales screens that need WebView support: `<input type="file">` photo upload (multipart `attachments/files`, field `file`), `URL.createObjectURL` + `<a download>` for PDFs, hidden `<iframe>` + `print()`, `navigator.share`, `navigator.pdfViewerEnabled`, `navigator.geolocation`, `localStorage`, `sessionStorage`, Google Maps JS API, WebSockets.
- [ ] Rep tracking has an admin on/off flag and modes `Continuous | Route | Shift` ([`tracking.model.ts`](../../DynaOps365/src/app/feature-pages/field-sales/models/tracking.model.ts)); the **server rejects** fixes outside a Shift calendar, so the shell does not have to be perfect about windows, only about not wasting battery.
- [ ] Angular conventions to respect for the ANGULAR items ([constitution](../../DynaOps365/.specify/memory/constitution.md), [dynaops-angular skill](../../DynaOps365/.claude/skills/dynaops-angular/SKILL.md)): standalone components, signals, `inject()`, Transloco scopes for every string (en + ar), new code under `core/` for cross-cutting concerns, path aliases `@core/*`, `@shared/*`, HTTP only through `HttpService`, never hand-edit `src/app/api/clients`.
- [ ] Flutter conventions to respect ([CLAUDE.md](../CLAUDE.md) + skills): `API Client → Repository → Cubit → UI`; `flutter_bloc` Cubits with sealed `Equatable` states; `get_it` registered in `lib/core/di/service_locator.dart` (Cubits as factories); `dio` only inside repositories, errors mapped to a sealed `Failure`; secrets only in `flutter_secure_storage`; colours only from the theme; strings only via `AppLocalizations` (ARB under `lib/l10n/`); **no `build_runner` codegen**.
- [ ] Toolchain risk: Flutter 3.47.3 + AGP 9.1.0 + Kotlin 2.4.0 are very new. Every plugin added must be checked to compile against AGP 9 (`android.newDsl=false`, `android.builtInKotlin=false` are set in `gradle.properties`). Budget time for pinning or patching.

---

## 2. Flutter packages

Add each package only when its checklist item is reached (`flutter pub add …`), run `flutter pub get`, and confirm the Android build still passes. Anything marked "new" needs the one-line approval note in the PR per [flutter-package-reference](../.claude/skills/flutter-package-reference/SKILL.md); the decisions in §0 count as that approval.

| Capability | Package | Policy status | Notes |
|---|---|---|---|
| State management | `flutter_bloc` (+ `equatable`) | approved | Cubits for shell, tracking status, sync status, permissions, locale; add `equatable` as a direct dependency because state and model files import it |
| DI | `get_it` | approved | single `service_locator.dart` |
| HTTP (fix uploads, policy read) | `dio` | approved | one instance; bearer interceptor; `Accept-Language` |
| Secure session store | `flutter_secure_storage` | approved | JWT + userId + expireAt + isSuperAdmin + lang |
| Simple flags | `shared_preferences` | approved | "tracking desired", last sync time, walkthrough seen |
| Routing | `go_router` | approved | shell route, permission walkthrough, diagnostics |
| WebView | `flutter_inappwebview` | new — **decided (D4)** | JS handlers, file chooser, downloads, geolocation, `shouldOverrideUrlLoading` |
| Foreground service | `flutter_foreground_task` | new — **decided (D3)** | `foregroundServiceType=location`, `stopWithTask=false`, boot restart, battery-optimisation prompt |
| Location fixes | `geolocator` | new — **decided (D3)** | `getPositionStream` with interval/distance filters |
| Permissions | `permission_handler` | new | fine/coarse, background location, notifications, camera, `openAppSettings` |
| Connectivity | `connectivity_plus` | new | transport changes; paired with a reachability probe |
| Local DB | `sqflite` | new — **decided (D10)** | hand-written SQL, versioned migrations |
| Ids | `uuid` | new | request ids, fix ids, batch ids |
| Paths | `path_provider` + `path` | new | DB file, temp files for `files.*` |
| App/device info | `package_info_plus`, `device_info_plus` | new | `app.info`, OEM-specific battery guidance |
| Share / print / save | `share_plus`, `printing` (or platform channel to `PrintManager`), `open_filex` | new — **required by D14** | Android share sheet, print dialog, open saved PDF |
| Launch external apps | `url_launcher` | new | `tel:`, `mailto:`, maps, external browser |
| Analytics / errors | `posthog_flutter` | new — **decided (D15)** | same PostHog project/host as the web app, key via `--dart-define`; verify the SDK's exception capture, else send a `flutter_error` event with stack |
| Localisation | `flutter_localizations` + `intl` | approved | notification text, walkthrough (en/ar, RTL) |
| Debug logging | `pretty_dio_logger` | approved (debug only) | guard with `kDebugMode` |
| Cubit tests | `bloc_test` (dev) | named in [flutter-cubit-architecture](../.claude/skills/flutter-cubit-architecture/SKILL.md#testing-cubits) | `blocTest` emitted-state sequences |
| Test doubles | `mocktail` (dev) | named in flutter-cubit-architecture | mock repositories/clients; no `mockito` (that one needs `build_runner`) |

- [ ] Confirm each package's latest stable release builds with AGP 9.1.0 / Kotlin 2.4.0 / compileSdk 36 before relying on it; record any pins and the reason. If `pub get` fails to resolve, follow [dart-resolve-package-conflicts](../.claude/skills/dart-resolve-package-conflicts/SKILL.md).
- [ ] Every plugin wrapper/client a new package introduces is registered once in `get_it`, never created ad hoc inside a repository or Cubit.
- [x] Pins and toolchain workarounds recorded during M1 (2026-10-05):
  - `flutter_inappwebview: 6.2.0-beta.3` (exact). The 6.1.x Android plugin uses `proguard-android.txt`, which AGP 9 refuses at configuration time; 1.2.0-beta.3 of the Android plugin switched to `proguard-android-optimize.txt`. Move to the first stable 6.2.x when released.
  - `compileSdk = 37` in `android/app/build.gradle.kts` + `android.suppressUnsupportedCompileSdk=37`: `permission_handler_android` requires compiling against 37. `targetSdk` stays 36 (D12).
  - `kotlin.incremental=false` in `android/gradle.properties`: the project (D:) and pub cache (C:) are on different drives, which breaks Kotlin incremental caches on Windows.
- [ ] Caret constraints in `pubspec.yaml`; commit `pubspec.lock`.
- [ ] Not selected (kept for reference): Transistorsoft `flutter_background_geolocation` — only if OEM field tests fail with the free stack.

---

## 3. Flutter project structure (proposed)

Follows [flutter-cubit-architecture](../.claude/skills/flutter-cubit-architecture/SKILL.md): `API Client → Repository → Cubit → UI`, one folder per feature split into `data/` (models + repositories), `cubit/` (Cubit + sealed state) and `view/` (screens + `widgets/`). Names are proposals; keep them consistent once chosen.

How the shell maps onto the four layers:

| Layer | Where | Rules |
|---|---|---|
| API client / data source | `core/network/dio_client.dart`, `core/database/app_database.dart`, `core/storage/*`, `*_dao.dart`, `*_api.dart`, `*_source.dart` (plugin wrappers) | Raw calls only: HTTP, SQL, plugin method calls. No feature logic. |
| Repository | `features/<f>/data/*_repository.dart` | Turns raw results into `*Model`s, catches every exception and maps it to the sealed `Failure`, and exposes `Stream`s for any status the UI or bridge observes. No `material.dart`. |
| Cubit | `features/<f>/cubit/` | Depends on repositories only (no `dio`, no plugins, no `material.dart`); sealed `Equatable` state; `registerFactory` in `get_it`; provided by `BlocProvider` on its `go_router` route, never at the app root. |
| UI | `features/<f>/view/` | Forwards input to its Cubit; exhaustive `switch` on state; navigation/dialogs only in `BlocListener`. |

Two kinds of non-UI code have no screen, so they cannot be Cubits (Cubits are route-scoped factories and die with their route):

- **Engines** (`features/<f>/engine/`): `TrackingTaskHandler` (runs in the foreground-service isolate) and `SyncManager`. They sit next to the repository layer: they call repositories, never Cubits or widgets, and report progress through repository streams. Registered as singletons in `get_it`. The service isolate builds its own locator without any Cubits.
- **Bridge** (`lib/bridge/`): the native API that Angular calls. Handlers call repositories (plus `SyncManager.trigger()`) only, never Cubits, `dio` or widgets. Outgoing events are built from repository streams, not from Cubit states. `ShellScreen` forwards raw JS messages to `ShellCubit`. `ShellCubit` is the only Cubit that talks to `BridgeController`, and it writes back through a `BridgeTransport` interface that the view implements around the `InAppWebViewController`, so the Cubit never imports the WebView plugin.

```text
lib/
  main.dart                          // ensureInitialized, setupServiceLocator, allReady, runApp
  app.dart                           // MaterialApp.router: theme/darkTheme, AppLocalizations delegates; only LocaleCubit at the root
  core/
    di/service_locator.dart          // setupServiceLocator(): _registerCore() then one _register<Feature>() per feature;
                                     //   clients/repositories registerLazySingleton, SharedPreferences registerSingletonAsync,
                                     //   engines singletons, Cubits registerFactory; swappable contracts (LocationSource,
                                     //   LocationUploader) registered against the abstract type
    di/task_locator.dart             // setupTaskLocator(): the service isolate's own graph, no Cubits, returns TrackingEngine
    config/app_config.dart           // tenant from --dart-define: web URL, API base, PostHog key/host, bridge version, webSource
    router/app_router.dart           // go_router: / (shell), /permissions, /diagnostics, errorBuilder
    theme/app_theme.dart             // AppTheme.light()/dark() from one seed (DynaOps brand primary): the only place for Color literals
    theme/app_colors.dart            // AppColors ThemeExtension: success / warning (tracking status chip, permission steps)
    network/dio_client.dart          // single Dio, AuthInterceptor, Accept-Language
    network/failure.dart             // sealed Failure + mapDioError
    database/app_database.dart       // sqflite open/migrate (schema version table); DAOs live in their feature
    storage/secure_store.dart        // flutter_secure_storage raw wrapper
    storage/prefs_store.dart         // shared_preferences raw wrapper
    analytics/analytics_client.dart  // PostHog wrapper (D15); never receives the token
    logging/app_logger.dart
  bridge/
    bridge_message_model.dart        // envelope models: request, response, event (version, type, id, action/event, payload/data)
    bridge_error_model.dart          // BridgeError + error codes; toBridgeError(Failure) (§15)
    bridge_controller.dart           // parse → validate version → dispatch by action prefix → respond; merges handler event streams
    bridge_handler.dart              // abstract: prefix, handle(request), events
    bridge_script.dart               // the document-start script (§6.1) as a Dart string + event delivery helper
    handlers/                        // each depends on repositories only
      app_handler.dart
      auth_handler.dart              // → SessionRepository
      permissions_handler.dart       // → PermissionsRepository
      tracking_handler.dart          // → TrackingRepository, LocationRepository
      network_handler.dart           // → ConnectivityRepository
      sync_handler.dart              // → SyncRepository, SyncManager
      files_handler.dart             // → FilesRepository (D14)
  features/
    shell/                           // the WebView host
      data/external_link_repository.dart   // url_launcher wrapper (tel:, mailto:, maps, browser)
      data/native_navigation_repository.dart // app.openNativeScreen requests → NativeNavigationCubit → BlocListener
      data/web_cache_repository.dart       // clear WebView cache (diagnostics only, §5.2)
      cubit/native_navigation_cubit.dart
      cubit/shell_cubit.dart         // load webUrl, navigation decisions, bridge in/out, retry on online
      cubit/shell_state.dart         // sealed: ShellLoading / ShellReady / ShellOffline / ShellLoadError
      cubit/url_policy.dart          // pure Dart: Uri → allow / cancel+adopt / external (§5.3), used only by ShellCubit
      view/shell_screen.dart         // InAppWebView, forwards callbacks to ShellCubit, back handling
      cubit/web_view_port.dart       // interface the Cubit uses for evaluate/reload/load/back (no plugin import)
      view/in_app_web_view_port.dart // WebViewPort over InAppWebViewController
      view/widgets/shell_web_view.dart     // InAppWebView, every callback forwarded to ShellCubit
      view/widgets/shell_offline_view.dart // composes shared ErrorView + "tracking keeps running" line
    auth/
      data/session_model.dart        // {token,userId,expireAt,isSuperAdmin,lang} from auth.setSession
      data/session_repository.dart   // secure store; adopt, expiry, user swap, sign-out; Stream<SessionModel?>
    tracking/                              // as built in M2
      data/position_model.dart             // raw provider reading (no geolocator types past the source)
      data/location_fix_model.dart         // stored fix: rows, isolate messages, tracking.location JSON, toWirePing()
      data/tracking_policy_model.dart      // RepDashboard trackingEnabled / trackingMode / shiftWindow
      data/tracking_status_model.dart      // TrackingState stopped/starting/running/stopping/permission_required/permission_denied/error + reason/errorCode
      data/location_source.dart            // LocationSource (swappable, D3) + GeolocatorLocationSource
      data/location_points_dao.dart        // points store SQL; claim-by-batch-id makes it safe across isolates
      data/tracking_api.dart               // dio: GET RepDashboard (policy)
      data/tracking_policy_repository.dart // policy snapshot in sync_meta, refreshed hourly / on demand
      data/location_repository.dart        // store-first writes, counts, latestFix() for tracking.latest
      data/tracking_service_client.dart    // UI isolate's handle on flutter_foreground_task (start/stop/send/messages)
      data/tracking_repository.dart        // UI isolate: start service, status stream, stopAndFlush, Force Stop detection
      engine/task_protocol.dart            // UI ↔ service command / message names
      engine/tracking_engine.dart          // the state machine inside the service (§8.2): policy, permission, stream, watchdog, retention
      engine/fix_filter.dart               // accuracy / duplicate / jump filter + derived speed & heading
      engine/tracking_policy.dart          // pure auto-start rule (D8) incl. midnight-crossing shifts
      engine/foreground_task_port.dart     // TrackingPort: publish to the UI, localised notification, stop service
      engine/tracking_task_handler.dart    // startTrackingTask entry point + TaskHandler (service isolate)
      engine/tracking_coordinator.dart     // UI isolate: §7 session rules (auto-start, user swap, sign-out flush, resume)
      cubit/tracking_cubit.dart, tracking_state.dart  // decides when the walkthrough opens
    sync/
      data/sync_status_model.dart          // SyncStatusModel (sync.status) + SyncCycleResult
      data/sync_meta_dao.dart              // key/value meta shared by both isolates
      data/location_upload_api.dart        // dio: POST LocationPings/batch (D5)
      data/location_uploader.dart          // LocationUploader + ApiLocationUploader (maps to Failure); no stub needed
      data/sync_repository.dart            // UI isolate: status, sync.now, retryFailed, one sync.* event stream
      engine/sync_manager.dart             // mutex, batching, 401 pause, backoff, dead-letter
      engine/backoff.dart                  // 5 s → 15 min with ±20 % jitter
      // No SyncCubit: diagnostics reads SyncRepository directly. No generic SyncItem yet (§10.1 hook deferred to M4).
    connectivity/
      data/network_status_model.dart
      data/connectivity_repository.dart    // connectivity_plus + reachability probe → debounced Stream<NetworkStatusModel>
    permissions/
      data/permission_status_model.dart
      data/permissions_repository.dart     // permission_handler: status/request/openSettings, Android-version aware
      data/oem_brand.dart                  // Samsung / Xiaomi / Huawei / Oppo / Vivo detection for the maker step
      cubit/permissions_cubit.dart, permissions_state.dart
      view/permission_walkthrough_screen.dart
      view/widgets/permission_step_card.dart
    device/
      data/device_repository.dart          // package_info_plus, device_info_plus (feeds app.info)
    files/
      data/files_repository.dart           // save/share/print/open base64 payloads (D14)
    diagnostics/
      cubit/diagnostics_cubit.dart, diagnostics_state.dart
      view/diagnostics_screen.dart         // hidden: state, pending count, last errors, log export
      view/widgets/diagnostics_section.dart
    locale/
      cubit/locale_cubit.dart              // global (root) Cubit: follows SessionRepository.lang (Angular's int-userLang), saved in prefs
  shared/widgets/                    // small, generic, theme-driven, one @Preview each (flutter-build-shared-widgets)
    feedback/loading_overlay.dart    // shell, walkthrough, diagnostics
    feedback/error_view.dart         // message + retry slot; strings passed in, never looked up inside
    buttons/app_button.dart
  l10n/                              // app_en.arb (template, @key descriptions), app_ar.arb
    generated/                       // gen-l10n output (synthetic-package: false)
android/app/src/<flavor>/            // per-tenant icons, labels, google-services if ever needed (D9)
test/                                // mirrors lib/
  bridge/                            // envelope, dispatch, error mapping
  features/<feature>/data/           // repositories (mocked clients), DAOs on a temp DB
  features/<feature>/engine/         // sync state machine, backoff, tracking policy
  features/<feature>/cubit/          // bloc_test + mocktail against mocked repositories
  features/<feature>/view/           // widget tests (en + ar/RTL)
integration_test/
```

- [ ] Create the folder skeleton and `service_locator.dart`: `setupServiceLocator()` (core → clients → repositories → engines as singletons → Cubits as `registerFactory`) and `setupTaskLocator()` for the service isolate (no Cubits).
- [ ] `core/router/app_router.dart`: each feature Cubit is provided on its own route; nothing feature-specific in a root `MultiBlocProvider`.
- [ ] `AppConfig` resolved from `--dart-define` (web URL, API base, tenant name, PostHog key/host) so nothing tenant-specific is hard-coded (D9).
- [ ] Localisation per [flutter-setup-localization](../.claude/skills/flutter-setup-localization/SKILL.md): `flutter_localizations` + `intl: any`, `generate: true`, `l10n.yaml` (`arb-dir: lib/l10n`, `template-arb-file: app_en.arb`, `output-dir: lib/l10n/generated`, `synthetic-package: false`, `nullable-getter: false`); `MaterialApp.router` takes `localizationsDelegates`/`supportedLocales` from `AppLocalizations`; `locale` comes from `LocaleCubit`, so the native screens follow the language the rep picked in Angular, not the OS language.
- [ ] Code that runs without a `BuildContext` (foreground-service notification text, notification channel name) resolves strings with the generated `lookupAppLocalizations(Locale(session.lang))`, never with literals.
- [ ] RTL: native screens use `EdgeInsetsDirectional`/`AlignmentDirectional`; no `left:`/`right:` offsets.
- [ ] Theme per [flutter-use-color-scheme](../.claude/skills/flutter-use-color-scheme/SKILL.md): `AppTheme.light()`/`dark()` + `AppColors`; `theme:` and `darkTheme:` both wired; the review grep `Color(0x|Colors\.` outside `lib/core/theme/` comes back empty.
- [ ] Models (`*_model.dart`) use hand-written `fromJson`/`toJson` (and `fromRow`/`toRow` for sqflite) with a pattern-matching `switch` that throws `FormatException` on a bad shape ([flutter-implement-json-serialization](../.claude/skills/flutter-implement-json-serialization/SKILL.md)); the bridge turns a `FormatException` into `INVALID_ARGUMENT`. Large `files.*` base64 payloads are decoded with `compute()` so the UI isolate doesn't jank.
- [ ] Shared widgets per [flutter-build-shared-widgets](../.claude/skills/flutter-build-shared-widgets/SKILL.md): a widget goes into `shared/widgets/` only once 2+ features use it; each has an `@Preview` ([flutter-add-widget-preview](../.claude/skills/flutter-add-widget-preview/SKILL.md)).
- [ ] Scaffold each feature with the `flutter-feature-scaffolder` agent. Run the `flutter-architecture-reviewer` agent on every PR that touches `lib/`.

### 3.1 File header rule (applies to M2 and every later milestone)

**Every Dart file under `lib/` that you create or edit starts with a short header doc comment.** When you edit a file, update its header if what the file does or its status changed. Files under `lib/l10n/generated/` are generated and excluded.

Format (a library doc comment, so it ends with `library;` before the imports):

```dart
/// `ClassName` (or what the file provides): one to four lines on what it does,
/// naming the plan section it implements (e.g. §8.2).
///
/// Why it exists: the reason this file is separate / which rule or skill it
/// serves (e.g. flutter-cubit-architecture, flutter-use-color-scheme).
/// Status: used — who creates or calls it. | Not used yet — what will use it
/// and in which milestone.
library;

import '...';
```

- **Summary first:** name the main class or function in backticks and say what it does, not how it is built.
- **Why it exists:** one or two lines; the decision or rule behind the file.
- **Status:** either `used — <where it is wired in>` or an honest "not used yet / partial" note with the milestone that completes it (e.g. "`setupTaskLocator()` arrives with M2"). Update it when that changes.
- Keep it short: about 3–10 lines. Details belong in member doc comments, not the header.
- Test files under `test/` follow the same pattern with a shorter body: what the tests cover, then `Status: active — part of \`flutter test\`.`
- [ ] Replace the counter template in `main.dart`; remove the demo widget test.
- [ ] Add a `tool/` or `README` section documenting how to build each tenant (`flutter build apk --flavor <tenant> --dart-define-from-file=env/<tenant>.json`).

---

## 4. Android project changes

- [ ] **D11 OPEN:** set the final `applicationId`, `namespace`, `android:label`, launcher icon, and a release `signingConfig` read from a gitignored `key.properties` before the first release build.
- [ ] Product flavors per tenant (D9): `productFlavors { <tenant> { applicationIdSuffix? resValue "string","app_name" … } }`; one `env/<tenant>.json` for `--dart-define-from-file`; CI builds each flavor.
- [ ] Keep `minSdk = 24`, `targetSdk = 36` (D12); raise minSdk only if a plugin forces it, and record why.
- [ ] `AndroidManifest.xml` permissions:
  - [ ] `INTERNET`, `ACCESS_NETWORK_STATE`
  - [ ] `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`
  - [ ] `ACCESS_BACKGROUND_LOCATION` (Android 10+; requested separately, §13)
  - [ ] `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` (Android 14+ requires the typed permission)
  - [ ] `POST_NOTIFICATIONS` (Android 13+)
  - [ ] `WAKE_LOCK`
  - [ ] `RECEIVE_BOOT_COMPLETED` — tracking should come back after a reboot without the rep opening the app (follows from D8); if Play review objects, drop it and rely on next app open
  - [ ] `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` for the in-app exemption prompt (note Play policy; the prompt is shown once with an explanation)
  - [ ] `CAMERA` so the WebView file chooser can offer the camera for photos
- [ ] Declare the foreground service with `android:foregroundServiceType="location"` and `android:stopWithTask="false"` (plugin manifest snippet).
- [ ] Notification channel for the tracking notification (name/description localised en/ar via `lookupAppLocalizations`, §3).
- [ ] No `dyngis` intent filter: the shell does not register the old tracker's scheme (D1), so the old tracker app, if still installed, keeps receiving its own links.
- [ ] `<queries>` for intents the shell hands off (`geo:`, `google.navigation:`, `tel:`, `mailto:`, `https` browser) so `canLaunchUrl` works on Android 11+.
- [ ] Network security: HTTPS only; no cleartext (remote loading, D2).
- [ ] `android:allowBackup="false"` or `dataExtractionRules` excluding the SQLite DB and secure storage.
- [ ] Keep `android:windowSoftInputMode="adjustResize"` (already set).
- [ ] `MainActivity`: keep `FlutterActivity`; `android:screenOrientation="unspecified"` so Flutter decides orientation at runtime (§5.5).
- [ ] R8/ProGuard: keep plugin rules; verify a release build runs tracking for ≥ 1 h.
- [ ] Verify the whole Android build on AGP 9.1.0 after every plugin addition.

---

## 5. WebView shell

### 5.1 Loading (D2 working assumption: remote URL)
- [ ] Load `AppConfig.webUrl` (per tenant); native splash/progress overlay until `onLoadStop`.
- [ ] If the main-frame load fails (`onReceivedError`): native "No connection" page with Retry and a line saying tracking keeps running; retry automatically when `network.changed → online`.
- [ ] Always load plain `webUrl`; Angular keeps its own session in WebView storage, and native ↔ web session sync happens over the bridge after `ready` (§7).
- [ ] Persist the last in-app route and restore it after a WebView recreation.
- [ ] **DEFERRED:** bundled build served from `localhost` (would need `assets/web/`, a local server, SW exclusion, Maps key referrer D16).

### 5.2 WebView settings
- [ ] `javaScriptEnabled`, `domStorageEnabled`, `databaseEnabled` on (localStorage is the Angular session store).
- [ ] `mixedContentMode` = never allow; `allowFileAccess` / `allowUniversalAccessFromFileURLs` off.
- [ ] `useShouldOverrideUrlLoading = true`; `useOnDownloadStart = true`; `geolocationEnabled = true`.
- [ ] Custom User-Agent suffix `DynaOpsApp/<version> (Android)` for analytics/diagnostics (the injected bridge object is the primary detection).
- [ ] Default cache mode; clear cache only from the diagnostics screen, never on logout.
- [ ] Cookies/`localStorage` persist across restarts (default); verify after a process kill.

### 5.3 Navigation policy (`shouldOverrideUrlLoading`)
- [ ] Any non-`http(s)` scheme not listed below → cancel and log (generic rule, no scheme-specific handling). Session never arrives by URL; it arrives only through the bridge (§7).
- [ ] `tel:`, `mailto:`, `sms:`, `geo:`, `google.navigation:`, `whatsapp:` → `url_launcher` externally.
- [ ] `https://www.google.com/maps…`, `https://maps.app.goo.gl…` → externally (the journey "Navigate" button).
- [ ] Same-origin `webUrl` → allow. Any other `http(s)` origin → system browser (keeps the shell single-origin, which also protects the bridge).
- [ ] `target="_blank"` / `window.open` → `onCreateWindow`: same origin opens in the same WebView, other origins externally.

### 5.4 Browser features that need native plumbing
- [ ] File chooser: gallery + camera for the location-request photo and the visit "Photo" action; request `CAMERA` at that moment.
- [ ] Geolocation prompt (`onGeolocationPermissionsShowPrompt`): auto-grant for the app's own origin once native location permission exists; stays as a fallback after `DeviceLocationService` is bridged.
- [ ] Downloads (`onDownloadStartRequest`): `https` URLs → Android `DownloadManager`; `blob:` URLs never reach this callback → covered by `files.*` (D14).
- [ ] `window.print()` is a no-op in WebView → `files.print` via Android `PrintManager` (D14).
- [ ] `navigator.share` is undefined in WebView → `files.share` (D14).
- [ ] JS `alert/confirm/prompt` → native dialogs (plugin defaults; verify RTL text).
- [ ] Console messages → Flutter logger in debug builds.

### 5.5 Orientation, back button, keyboard
- [ ] Allow all orientations in the shell and never lock (decided 2026-10-06: the `device.*` bridge actions were dropped). Angular does not try to lock inside the shell either. This follows [flutter-build-responsive-layout](../.claude/skills/flutter-build-responsive-layout/SKILL.md) ("do not lock orientation"). The native screens (walkthrough, diagnostics, offline view) adapt with `LayoutBuilder`/`MediaQuery.sizeOf`, not orientation or device type.
- [ ] Hardware back: `canGoBack()` → `goBack()`; on the Angular root → confirm exit (the foreground service keeps running either way).
- [ ] Verify the Angular rotate-device overlay does not appear wrongly on tablets; ANGULAR tweak in §18 if it does.
- [ ] Keyboard: forms on the journey screen scroll into view; `adjustResize` already set.

### 5.6 Lifecycle inside the shell
- [ ] `AppLifecycleState.resumed` → emit `app.resumed { online, trackingState, pendingCount }`; re-check permissions; nudge the sync manager.
- [ ] `paused` → nothing; tracking and sync live outside the WebView.
- [ ] Process death with the service alive → on relaunch restore the last route and re-emit status once the bridge reports `ready`.
- [ ] `onRenderProcessGone` → recreate the WebView.

---

## 6. Angular ↔ Flutter bridge

Protocol is exactly the reference contract: `version` (start at `"1.0"`), `type ∈ {request,response,event}`, `id`, `action`/`event`, `payload`/`data`, `success`, `error{code,message,retryable}`.

### 6.1 JavaScript side (injected by Flutter at document start)
- [ ] Inject `bridge.js` as a user script at **document start** on every main-frame load so `window.DynaOpsNative` exists before Angular bootstraps (`isNativeShell()` checks in `app.config.ts` and the new `core/native/` code run at bootstrap).
- [ ] `window.DynaOpsNative = { version: '1.0', platform: 'android', appVersion, postMessage(json), addListener(fn), removeListener(fn) }`.
- [ ] `postMessage` forwards to the registered JS handler (`callHandler('dynaops', json)`); Flutter answers by evaluating `window.DynaOpsNative._receive(json)`.
- [ ] Fire a DOM event `dynaops-native-ready` after injection so Angular can also wait for it.
- [ ] Only accept messages from the configured web origin — checked on the Flutter side too.
- [ ] Payload size guard (< 1 MB per message); `files.*` payloads are base64 and may be chunked.

### 6.2 Flutter side (`BridgeController`)
- [ ] Parse envelope; malformed JSON → `INVALID_ARGUMENT`.
- [ ] Version negotiation: same major → handle; unknown major → `UNSUPPORTED` naming the supported versions.
- [ ] Dispatch by `action` prefix to a handler registry; unknown action → `UNSUPPORTED`.
- [ ] Exactly one response per request, same `id`, also on exceptions (`NATIVE_ERROR`).
- [ ] `Failure` → bridge error codes (§15).
- [ ] Per-action timeout guard (default 30 s).
- [ ] Events fan out from repository streams (`TrackingRepository`, `LocationRepository`, `SyncRepository`, `ConnectivityRepository`, `PermissionsRepository`, `SessionRepository`), never from Cubits (they only exist while their route is open); dropped while the WebView is not ready — Angular re-reads state via `*.status` on `ready`.
- [ ] Unit tests: envelope round-trip, unknown action, version mismatch, exception path, id echo.

### 6.3 Angular side (`NativeBridgeService`) — ANGULAR
- [ ] New `src/app/core/native/native-bridge.service.ts` (`providedIn: 'root'`, signals, `inject()`): `isNative` (computed from `window.DynaOpsNative`), `request<T>(action, payload?, { timeoutMs })`, `on<T>(event)` as `Observable`, `ready$`.
- [ ] Pending-request map keyed by `id` (`crypto.randomUUID()`); typed `BridgeError` on timeout.
- [ ] Queue requests issued before `dynaops-native-ready`; flush on ready.
- [ ] Typed constants in `native-bridge.contract.ts` mirroring §6.4.
- [ ] `NativeBridgeStub` for unit tests and the browser (`request` rejects `UNSUPPORTED`, `isNative()` false) so web behaviour is unchanged.
- [ ] No feature module references the WebView plugin or anything Flutter-specific — only this service.

### 6.4 Action & event catalogue (v1.0)

Request → response actions:

| Action | Payload → data | Notes |
|---|---|---|
| `app.info` | `{}` → `{ appVersion, bridgeVersion, platform, webOrigin, tenant, deviceModel, androidSdk }` | |
| `app.openSettings` | `{ screen: 'app' \| 'location' \| 'battery' \| 'notifications' }` → `{}` | |
| `app.openNativeScreen` | `{ screen: 'permissions' \| 'diagnostics' }` → `{}` | opens the native walkthrough or the support screen (added in M2) |
| `auth.setSession` | `{ token, userId, expireAt, isSuperAdmin, lang }` → `{ accepted: true }` | **the** way a session reaches the shell (login + boot sync, §7); idempotent; validates `expireAt` |
| `auth.getSession` | `{}` → `{ userId, expireAt } \| null` | never returns the token to JS |
| `auth.signOut` | `{ deliberate }` → `{ flushed: n }` | deliberate sign-out only; 401/expiry never calls it |
| `auth.restoreWebSession` | `{}` → `{ token, userId, expireAt, isSuperAdmin } \| null` | **OPEN** (§7 restore fallback): the only action that returns the token, own origin only, only when Angular has no session |
| `permissions.status` | `{ permissions: [...] }` → `{ location, backgroundLocation, notifications, camera, batteryOptimizationIgnored }` | values `granted \| denied \| permanentlyDenied \| notDetermined \| restricted` |
| `permissions.request` | `{ permissions: [...] }` → same shape | sequential prompts; background location opens settings on Android 11+ |
| `tracking.start` | `{ intervalSeconds?: 5, reason?: 'manual' \| 'retryAfterPermission' }` → `{ state }` | normally unnecessary (auto-start, D8); used by Angular after a permission fix |
| `tracking.stop` | `{ reason }` → `{ state }` | **refused with `UNSUPPORTED` while a session exists** — stopping happens only via sign-out (compliance; see §8.1) |
| `tracking.status` | `{}` → `{ state, reason, errorCode, backgroundService, locationPermission, backgroundPermission, enabled, lastLocationTimestamp, pendingUploads, lastUploadAt }` | `reason`: `signedOut \| disabledByAdmin \| outsideShift \| sessionExpired`; `errorCode`: `LOCATION_DISABLED \| LOCATION_UNAVAILABLE \| FORCE_STOPPED_PREVIOUSLY \| SERVICE_START_FAILED` |
| `tracking.latest` | `{ maxAgeSeconds?: 30, highAccuracy?: true }` → `{ latitude, longitude, accuracy, speed, heading, timestamp, source: 'cache' \| 'fresh' }` | fresh fix limited to 15 s (Angular waits 20 s); replaces browser `getCurrentPosition` for geofence/check-in/day-start/location capture |
| `tracking.refreshPolicy` | `{}` → `{ enabled, mode: Continuous \| Route \| Shift, shiftWindow: { workingDays, availableHoursPerDay, dailyStartTime } \| null }` | re-reads `GET RepDashboard` and tells the service (§8) |
| `network.status` | `{}` → `{ online, connectionType, reachable }` | |
| `sync.status` | `{}` → `{ running, pending, failed, lastSuccessAt, lastError }` | |
| `sync.now` | `{}` → `{ started: bool }` | manual trigger; no-op if running |
| `sync.retryFailed` | `{}` → `{ requeued: n }` | dead-lettered fixes back to pending |
| `files.save` | `{ name, mimeType, base64 }` → `{ uri }` | PDF/XLSX from blobs (D14) |
| `files.share` | `{ name, mimeType, base64 }` → `{}` | Android share sheet (D14) |
| `files.print` | `{ name, base64Pdf }` → `{}` | `PrintManager` (D14) |
| `files.open` | `{ name, mimeType, base64 }` → `{}` | open in an external viewer (D14) |

Events (Flutter → Angular):

| Event | Data |
|---|---|
| `tracking.statusChanged` | `{ state, backgroundService, locationPermission, backgroundPermission, enabled, lastLocationTimestamp, pendingUploads, errorCode? }` |
| `tracking.location` | `{ id, latitude, longitude, accuracy, speed, heading, timestamp, storedLocally: true, synced: false }` — informational; DB is the source of truth |
| `sync.started` / `sync.progress` / `sync.completed` / `sync.failed` | as in the reference (`processed`, `total`, `failed`, `code`, `message`) |
| `network.changed` | `{ online, connectionType, reachable }` |
| `permissions.changed` | same shape as `permissions.status` |
| `auth.sessionChanged` | `{ userId, expireAt }` |
| `auth.sessionExpired` | `{ expireAt }` — uploads paused until a new session arrives |
| `auth.signedOut` | `{}` |
| `auth.required` | `{}` — shell has no session; Angular should show login |
| `app.resumed` | `{ online, trackingState, pendingCount }` |

- [ ] Write the catalogue into `bridge_protocol.dart` (Dart) and `native-bridge.contract.ts` (TS); keep them in lockstep; bump `version` on any breaking change.
- [ ] Document each action's error codes next to its handler.
- [ ] **FUTURE (D7):** `data.*` domain actions and `sync.operationChanged` / `data.changed` events for offline business operations — planned in §10.2, not implemented now. Reserve the `data.*` namespace in the TS contract today.

---

## 7. Auth / session flow (native bridge only, no dependency on the old tracker)

The shell gets its session **only** through the bridge (`auth.setSession` / `auth.signOut`). The Flutter app contains nothing for the old DynaOps tracker: no `dyngis://` handling, no hand-off decoding, no `int-dyngis_tracker` flag. On the Angular side the tracker code (`tracker-link.ts`, `handoff.ts`, the `handOffToTracker`/`notifyTrackerSignOut` calls) stays **exactly as it is** for the browser/PWA. New native code is added next to it and takes its own branch when `isNative()` is true.

- [ ] **Launch:** load plain `webUrl`. Angular's own `localStorage['int-auth_token']` persists in the WebView (§5.2), so a signed-in rep stays signed in without the shell pushing anything. Native tracking starts from the native session in secure storage (D8) and does not wait for the WebView.
- [ ] **Angular → shell sync on boot** (ANGULAR): on `dynaops-native-ready`, if Angular holds a valid token, call `auth.setSession`. The call is idempotent; a different `userId` triggers the user swap (§7.1). This covers a fresh install, a cleared native store, and a session that changed in the web app.
- [ ] **Password login** (ANGULAR): in `AuthService.login`, `if (native) nativeSession.signedIn(res.data) else handOffToTracker(res.data)`. In the shell the tracker call is never reached; in the browser nothing changes.
- [ ] **Deliberate sign-out** (ANGULAR): same pattern. When native, call `nativeSession.signedOut()` (`auth.signOut({ deliberate: true })`, awaited, bounded) instead of `notifyTrackerSignOut()`.
- [ ] ANGULAR: the login page hides "Sign in with DynaOps" when `isNative()` (a check in the login component, not in `tracker-link.ts`).
- [ ] **Restore (WebView storage lost, native session valid)** — **OPEN**: after `ready`, if `auth.getSession` says the shell has a session but Angular has none, Angular calls `auth.restoreWebSession` once and writes the returned token to its own storage (own origin only, §16). Decide in M1 whether to build it or simply let the rep sign in again; the tracker hand-off (`#handoff=`) is **not** used for this.
- [ ] **Shell on `auth.setSession`:** validate shape and expiry; different `userId` than stored → user-swap procedure (§7.1); store; emit `auth.sessionChanged`; start tracking (D8) after `tracking.refreshPolicy`.
- [ ] **Deliberate sign-out** (`auth.signOut{deliberate:true}`): stop tracking, one bounded final flush (≤ 20 s) if online, clear the session, keep unsent fixes tagged with the old `userId` (uploaded next time *that* user signs in, never under another user), emit `auth.signedOut`.
- [ ] **Non-deliberate logout** (Angular 401 / expiry): Angular calls `logOut()` and does **not** call `auth.signOut`; the shell keeps collecting, pauses uploads when `expireAt` passes (D6), emits `auth.sessionExpired`; the notification text changes to "sign in to resume uploads".
- [ ] **Upload 401:** pause uploads, keep data, emit `auth.sessionExpired`; never clear the queue.
  - [ ] `AuthInterceptor` departs from the [flutter-dio-repository-setup](../.claude/skills/flutter-dio-repository-setup/SKILL.md#auth-token-interceptor) example. On 401 it does **not** delete the whole stored session: `userId` must survive so fixes stay attributed and tracking continues (D6, D8). It asks `SessionRepository` to mark the session expired (drop the token, keep `userId`), which publishes on the session stream. It never navigates and never retries.
- [ ] `Accept-Language` from the session's `lang` (Angular stores `int-userLang`) on every shell request.
- [ ] Never log the token; never return it to JavaScript through `auth.getSession`; never send it to PostHog.

### 7.1 User swap
- [ ] Stop tracking for user A; flush A's pending fixes if online (bounded); whatever remains stays attributed to A.
- [ ] Clear A's policy snapshot; start for user B.

---

## 8. Background location tracking

### 8.1 Start/stop policy (D8 — confirmed 2026-10-05)
- [ ] **Auto-start** whenever the shell holds a valid session: on app launch, right after `auth.setSession`, and after a reboot (boot receiver) if a session is stored. No Start button for the rep.
- [ ] **Stops only** on deliberate sign-out, when the admin flag `trackingEnabled` is false, or when the system kills the service.
- [ ] Angular's `tracking.stop` is refused while a session exists; `tracking.start` exists only to retry after a permission fix.
- [x] Policy read: `trackingEnabled`, `trackingMode`, `shiftWindow` from `GET RepDashboard` (top level of the rep's own dashboard; `shiftWindow { workingDays (0 = Sunday), availableHoursPerDay, dailyStartTime "HH:mm" }`, device-local time, no end time, may cross midnight). There is no lighter rep endpoint; the admin `RepTracking` list needs a permission reps lack. Refreshed on service start, on a new session user, on resume (`refreshPolicy`), and hourly; the snapshot lives in `sync_meta` for offline use.
  - [ ] `trackingEnabled = false` → do not collect; state `stopped` with reason `disabledByAdmin`.
  - [ ] `Shift` with a window → collect only inside the window (the server rejects the rest anyway; this saves battery). Window may cross midnight; schedule the next edge with the task timer.
  - [ ] `Continuous` / `Route` / no calendar → collect whenever a session exists (Route-mode gating by day start/end is **DEFERRED**; the server already knows the route state).
- [x] Confirmed by the product owner: tracking runs from the moment the rep is signed in, without a Start button, and the rep cannot switch it off from the app.

### 8.2 Engine
- [ ] `LocationSource` interface over `geolocator` so the engine can be swapped (D3).
- [ ] Collection runs inside the **foreground service isolate** (`flutter_foreground_task` `TaskHandler`), not the UI isolate; persistent notification localised, tap opens the app.
- [ ] Interval: request ~5 s (`intervalDuration`) with `distanceFilter` 0–5 m and `LocationAccuracy.high`; document that Android/OEMs may deliver less often.
- [ ] Store-first: every fix is written to the local DB **before** anything else; then `tracking.location` is emitted (best effort) and the sync manager is nudged.
- [ ] Fix filtering: drop fixes with `accuracy` worse than a configurable threshold, exact duplicates, and impossible jumps; keep a `rejectedReason` counter for diagnostics.
- [ ] Persist "tracking desired" + policy snapshot in prefs so the service can restart itself after process death or reboot.
- [ ] `stopWithTask = false` so swiping the app from Recents keeps the service alive where the OEM allows it.
- [ ] Battery optimisation: detect `isIgnoringBatteryOptimizations`; in-app explanation + system dialog once; OEM-specific guidance (Samsung "Never sleeping apps", Xiaomi "Autostart", Huawei "App launch") chosen by `device_info_plus` manufacturer.
- [ ] Force Stop: detect on next launch (service was running, no clean stop recorded) → `tracking.statusChanged` carries `errorCode: FORCE_STOPPED_PREVIOUSLY`; notification and diagnostics say so. Never promise tracking across Force Stop.
- [ ] State machine `stopped → starting → running → stopping → stopped`, plus `permission_required`, `permission_denied`, `error`; every transition emits `tracking.statusChanged`.
- [ ] Watchdog: no fix for X minutes while `running` → restart the stream once, then `error { LOCATION_UNAVAILABLE }`.
- [ ] Location services off → `LOCATION_DISABLED`, keep service alive, resume when re-enabled (`serviceStatusStream`).
- [ ] Timestamps in UTC ISO-8601 from the fix, not from the upload moment.

---

## 9. Local database (sqflite)

Scope per D7: the only business data stored locally is **location fixes**. Do not copy names from here; design the schema against the real upload contract (D5).

- [ ] One database file in the app's private dir; `PRAGMA journal_mode=WAL`; opened once via `get_it`.
- [ ] Schema version table + ordered migration list; a test that migrates from every past version.
- [ ] **Location points store**: id (uuid), userId, lat, lng, accuracy, speed, heading, capturedAt (UTC), state (`pending|uploading|synced|failed`), attempts, lastError, batchId, createdAt. Index on `(userId, state, capturedAt)`.
- [ ] **Sync meta store**: last successful upload time, policy snapshot, dead-letter count, last probe result.
- [ ] Retention: delete `synced` fixes older than N days (default 7); cap total rows (e.g. 200k) by dropping the oldest `synced`; never auto-delete `pending` or `failed`.
- [ ] Every row carries `userId`; every query filters by the current user (user-swap safety).
- [ ] DAO unit tests with a temporary DB.
- [ ] **FUTURE:** outbox, reference-data cache, queued-files and order-draft stores arrive as later migrations (§10.2).

---

## 10. Offline flow (tracking only, D7)

```text
GPS fix → Location points store (pending) → Sync manager → Location upload API (D5) → synced
                                     ↑
                 offline: rows accumulate; nothing else changes
```

- [ ] Everything **except tracking** stays online through Angular's own `HttpService`; when the network is down the Angular screens fail as they do today in the browser.
- [ ] Optional ANGULAR nicety: a thin "You're offline — tracking continues, N fixes waiting" banner on the journey screen fed by `network.changed` and `sync.status`.
- [ ] Angular never implements a sync engine or its own online detection for the shell.

### 10.1 Design hooks to build **now** so the future phase is cheap
These cost almost nothing today and avoid a rewrite later. They do **not** implement any offline business feature.

- [ ] Sync manager works on a generic `SyncItem` (kind, payload, state, attempts, dependsOn) with one `Uploader` per kind; location fixes are simply the first kind.
- [ ] Bridge handler registry is keyed by action prefix so a future `data.*` handler plugs in without touching `BridgeController`.
- [ ] Bridge responses for writes already use the `{ localId, syncState }` shape where it applies today (none yet), and the TS contract reserves the `data.*` namespace.
- [ ] DB migration framework in place from v1 (schema version table), so new stores are just the next migration.
- [ ] Every local row carries `userId` from day one (user-swap safety is needed for business data too).
- [ ] `AppConfig` has a `webSource: remote | bundled` switch even though only `remote` is implemented, so the bundled path is a feature flag, not a refactor.

### 10.2 FUTURE PHASE — offline business features (planned, **not implemented now**)
The user's stated direction: after tracking, bring offline support to other features, starting with **creating sales orders**. This section is the plan to pick up at that point. Everything here is unchecked on purpose and out of scope for the current release.

**Prerequisites**
- [ ] FUTURE — D2 moves to a bundled build (or a reliable service-worker shell) so the Angular UI opens with no network; the Maps key referrer (D16) is revisited.
- [ ] FUTURE — Backend support for offline sales orders: client-side pricing/discount rules or a "price at sync time" policy (today `calculateSalesLine` and `salesOrderNumber` are server-side), a reserved/temporary order number scheme, and idempotent create/confirm endpoints.
- [ ] FUTURE — Backend accepts an `idempotencyKey` (header or body) on every write the outbox will replay.
- [ ] FUTURE — Decide per feature whether it is "offline read", "offline write", or both.

**Local stores (names to be designed against the real contracts)**
- [ ] FUTURE — Reference cache store: scope key (journey:date, dashboard:date, clients:page/search, catalog:customer/search/page, lookups:set, gpsSettings, customer details/credit for orders), payload JSON, cachedAt, ttl.
- [ ] FUTURE — Outbox store: localId, userId, action, payload JSON, idempotencyKey, dependsOn, state (`pending|uploading|synced|failed`), attempts, lastError, serverId, timestamps.
- [ ] FUTURE — Queued files store for photos taken offline (location requests, visit "Photo" action).
- [ ] FUTURE — Draft store for in-progress sales orders (lines, quantities, prices as known) so a half-built order survives an app kill.

**Bridge additions (bump to protocol `1.1`)**
- [ ] FUTURE — Reads: `data.journey.get`, `data.dashboard.get`, `data.clients.search/get/summary`, `data.catalog.items.search`, `data.visitLookups.get`, `data.settings.gps.get`, `data.refresh` → cached DTO + `{ cachedAt, stale }`; event `data.changed { scope }`.
- [ ] FUTURE — Writes: `data.routes.startDay/endDay`, `data.visits.checkIn/checkOut/skip/reschedule/addAction/setTask/createUnplanned`, `data.locationRequests.create`, `data.payments.post`, `data.orders.create/addLines/updateLines/removeLines/submit` → `{ localId, syncState, result? }`; event `sync.operationChanged { localId, action, syncState, serverId?, error? }`.
- [ ] FUTURE — Online shortcut: when reachable, send synchronously first and only queue on failure, behind one repository method.

**Sync manager additions**
- [ ] FUTURE — Dependency ordering (check-in before actions before check-out; photo upload before the request that references it; order header before lines before confirm).
- [ ] FUTURE — Conflict policy: server authoritative; `409`/validation → `failed` non-retryable with the server's message; Angular shows "needs attention" on the item. Known 409 cases today: duplicate pending location request, check-in before day start, check-in while another visit is open.
- [ ] FUTURE — Local id → server id mapping surfaced to Angular so UI models swap ids without a reload.

**Angular side (additive)**
- [ ] FUTURE — Native branches in `JourneyService`, `RepDashboardService`, `ClientsService`, `FieldSalesCatalogService`, `VisitSetupService`, `VisitSettingsService`, `VisitsService`, `DayStampsService`, `LocationRequestsService`, `FieldSalesPaymentService`, `FieldSalesOrderService` / `SalesOrderPostingService` that call `data.*` when `isNative()`; models and components unchanged.
- [ ] FUTURE — "Saved offline — waiting for synchronisation" and per-item sync badges (Transloco en/ar).
- [ ] FUTURE — Sales order screen tolerates provisional prices/numbers and shows the server-confirmed values after `sync.operationChanged`.

**Testing additions**
- [ ] FUTURE — Airplane-mode scenarios for each offline feature; replay-after-kill; duplicate-prevention with idempotency keys; conflict surfacing.

---

## 11. Sync manager (location batches)

- [ ] Single instance in `get_it`; mutex so only one cycle runs at a time.
- [ ] "One Dio instance" (flutter-dio-repository-setup) means one per isolate: the service isolate's `setupTaskLocator()` builds its own Dio with the same `AuthInterceptor`. Decide which isolate owns sync cycles so two `SyncManager`s never upload the same rows; the DB row state (`uploading`) is the cross-isolate guard.
- [ ] Triggers: connectivity → online (debounced 3–5 s and confirmed by the probe); app resumed; foreground-service tick (e.g. every 60 s while tracking, or when ≥ N pending rows); `sync.now`.
- [x] `LocationUploader` interface + `ApiLocationUploader` (real, D5 resolved) calling `features/sync/data/location_upload_api.dart`; errors mapped to `Failure`.
- [ ] Batching: oldest first, N fixes per request (size from D5; default 100), mark `uploading` → `synced` on 2xx; on transient failure back to `pending` with `attempts++`; on 4xx validation (e.g. out-of-calendar fix rejected) → `failed` with the server's reason.
- [ ] Retry: exponential backoff with jitter (5 s → 10 → 20 → … cap 15 min); after max attempts → dead-letter (`failed`, `retryable:true`); `sync.retryFailed` re-queues.
- [x] `401` → rows back to pending, session marked expired (`auth.sessionExpired`, D6); `403` → `failed` but retryable (`sync.retryFailed` brings them back, e.g. after a permission fix); 400/413/422 → `failed` for good; `5xx`/timeout/network → retry with backoff.
- [ ] Dedupe: **not possible with the current API** (no idempotency field). The local batch id stays local. Ask the backend for an idempotency key (per ping `id` or batch header) before M3; until then a timeout after the server stored a batch can duplicate those points.
- [ ] Progress events per batch; `sync.completed` with totals; `sync.failed` with the first blocking error.
- [ ] Row-by-row state persistence; on start, reset `uploading` → `pending`.
- [ ] Never block fix collection on upload results.
- [ ] Unit tests: state machine, backoff schedule, 401 pause, resume after kill, dedupe.

---

## 12. Connectivity

- [ ] `connectivity_plus` stream for transport changes (wifi/mobile/none) — not trusted alone.
- [ ] Reachability probe: cheap authenticated request to the API (endpoint to confirm with D5; fallback `HEAD` on the API base) with a 5 s timeout; on every transport change, on resume, and before a cycle.
- [ ] `online = transport != none && reachable`; emit `network.changed` only on real changes (debounced).
- [ ] Captive portals handled by the probe.

---

## 13. Permissions & foreground-service requirements

- [x] **Mandatory permissions (decided 2026-10-07):** the app cannot be used until tracking has everything it needs — precise location, location "all the time", notifications and the battery-optimisation exemption (`PermissionStatusModel.trackingReady`). The router's `PermissionGate` sends every route except the walkthrough, diagnostics and the request inspector to `/permissions`, at launch and whenever a permission changes (e.g. revoked in Settings). Required steps cannot be skipped; system back leaves the app; only the maker hint is skippable and shows once per install. This replaces the earlier "prompt once" `TrackingCubit`, which was removed. GPS switched off is not a permission and is not gated (tracking reports `LOCATION_DISABLED`). Angular's journey screen no longer shows a tracking state chip.
- [ ] Permission walkthrough screen (native, localised en/ar) shown on first launch after login and whenever tracking reports `permission_required`:
  1. foreground location (fine); Android 12+ "approximate" → explain and re-request precise;
  2. **background location** — Android 10 shows "Allow all the time" in the dialog; Android 11+ requires app settings with on-screen instructions;
  3. notifications (Android 13+) so the foreground-service notification is visible;
  4. battery optimisation exemption;
  5. OEM autostart hint (Xiaomi/Huawei/Oppo/Vivo).
- [ ] `permissions.status` maps plugin results to `granted | denied | permanentlyDenied | notDetermined | restricted`.
- [ ] `permissions.request` is sequential; never loops on `permanentlyDenied` (offers `app.openSettings`).
- [ ] Re-check on every resume → `permissions.changed`; tracking moves to `permission_required` when revoked and auto-resumes when re-granted (D8).
- [ ] Start the service only after foreground location is granted; Android 14+ needs `FOREGROUND_SERVICE_LOCATION`; starting from the background is restricted on Android 12+ → start from the UI, the boot receiver, or an exempt trigger only.
- [ ] In-app background-location disclosure text (Play Store policy) shown in the walkthrough.

---

## 14. App lifecycle handling

| Situation | Expected behaviour | Checklist |
|---|---|---|
| App in foreground | WebView + service both alive | `[ ]` events flow to Angular |
| Phone locked | Service keeps collecting and uploading | `[ ]` ≥ 1 h locked test, fixes every ~5 s |
| Switch to another app | Same as locked | `[ ]` |
| Swiped from Recents | Service continues (`stopWithTask=false`) where OEM allows | `[ ]` per-OEM result recorded |
| Process killed by OS | Service restarted by Android (`START_STICKY`), reloads policy from prefs/DB | `[ ]` `adb shell am kill` test |
| Reboot | Boot receiver restarts the service when "tracking desired" and a valid session exist | `[ ]` |
| Force Stop | Nothing runs until the user opens the app; next launch reports it | `[ ]` message verified |
| WebView destroyed/recreated | Angular reloads with its own stored session, syncs it via `auth.setSession`, re-reads `tracking.status`/`sync.status` | `[ ]` |
| Token expires while backgrounded | Collection continues, uploads pause, `auth.sessionExpired` on next UI open | `[ ]` |
| Shift window edge | Policy timer re-evaluates | `[ ]` |

- [ ] ANGULAR: on `app.resumed`, refresh journey/dashboard and re-read `tracking.status` and `sync.status`.

---

## 15. Error & retry strategy

| Code | Source in Flutter | `retryable` |
|---|---|---|
| `PERMISSION_DENIED` / `PERMISSION_REQUIRED` | PermissionsRepository | false / false |
| `LOCATION_DISABLED` | location services off | true (after user action) |
| `LOCATION_UNAVAILABLE` | timeout / no fix | true |
| `NETWORK_ERROR` | `NetworkFailure`, `TimeoutFailure`, probe failed | true |
| `UNAUTHORIZED` | `UnauthorizedFailure` (401), expired session | false (needs login) |
| `DATABASE_ERROR` | `DatabaseFailure` (sqflite exceptions caught in the DAO's repository) | false |
| `SYNC_ERROR` | cycle failed (first blocking error) | true |
| `INVALID_ARGUMENT` | payload validation, bad envelope | false |
| `NOT_FOUND` | unknown id/scope | false |
| `UNSUPPORTED` | unknown action, version mismatch, policy refusal (`tracking.stop`) | false |
| `NATIVE_ERROR` | any uncaught exception | false |

- [ ] `mapDioError` → sealed `Failure` (project skill) → one `toBridgeError(Failure)` function; unit-tested.
- [ ] Extend the skill's `Failure` set (`NetworkFailure`, `TimeoutFailure`, `UnauthorizedFailure`, `ServerFailure`) so §11 can tell its cases apart: `ForbiddenFailure` (403, non-retryable), `ValidationFailure` (other 4xx, server message kept), `DatabaseFailure`, `PermissionFailure`, `LocationFailure` (disabled/unavailable). Every repository, not only the Dio-backed ones, throws only `Failure`s.
- [ ] `Failure.message` is for logs and for passing server messages through the bridge. Native screens map the failure **type** to an `AppLocalizations` key and never show the skill's English default messages.
- [ ] Server validation messages passed through verbatim in `error.message` (already localised by `Accept-Language`).
- [ ] Logging: structured logs with action/id/userId (never token); ring buffer exportable from the diagnostics screen.
- [ ] **D15:** `posthog_flutter` initialised with the tenant's key/host from `--dart-define`; `identify(userId)` on session, `reset()` on sign-out; capture `FlutterError.onError` + `PlatformDispatcher.onError` + zone errors; shell events: `tracking_started/stopped`, `sync_batch_uploaded`, `permission_denied`, `force_stop_detected`. Angular keeps its own PostHog (`providePostHogErrorHandler`) untouched.
- [ ] ANGULAR: bridge errors shown through the existing `MessageService` with Transloco keys per code (en/ar).

---

## 16. Security

- [ ] Session only in `flutter_secure_storage`; never in `shared_preferences`, logs, or analytics.
- [ ] The bridge trusts only messages from the configured web origin; all other origins open externally (§5.3).
- [ ] No raw SQL or arbitrary native method exposure; every action is a named handler with a validated payload.
- [ ] Sessions travel only over the origin-checked bridge, never over a URL scheme or intent, so no other app can hand the shell a token.
- [ ] `auth.restoreWebSession` (if chosen, §7) is the one path that hands the token to JS: own origin only, only when Angular reports no session, never logged.
- [ ] WebView: HTTPS only, no file-URL access, no mixed content.
- [ ] DB in app-private storage; excluded from backups. Location history of named employees is personal data — keep retention short (§9) and decide with the business whether SQLCipher is required.
- [ ] Unsent fixes stay attributed to their owner across user swaps (§7.1).
- [ ] Release build: R8 on, debug logging stripped (`kDebugMode` guards), `pretty_dio_logger` absent.
- [ ] No API keys in the Flutter repo; tenant config via `--dart-define-from-file` with the env files gitignored (or CI secrets).
- [ ] Certificate pinning: optional; decide with the backend team.

---

## 17. Testing strategy

### 17.1 Automated
- [ ] Dart unit tests: bridge envelope/dispatch, `Failure` → error code mapping, tracking policy (enabled flag, shift windows crossing midnight, auto-start rule), sync state machine + backoff + dedupe, DAO migrations, connectivity debounce.
- [ ] Cubit tests with `bloc_test` + `mocktail` (mocked repositories only, no Dio/plugins); one `blocTest` per state transition.
- [ ] Model tests: `fromJson`/`toJson` (and `fromRow`/`toRow`) round-trip plus a malformed-shape case for every `*_model.dart`.
- [ ] Any test that touches the locator calls `getIt.reset()` in `setUp` and `tearDown`.
- [ ] Widget tests: permission walkthrough states, diagnostics screen, shell loading/error overlays, each in `en` and `ar` (RTL); every `switch` on a sealed state is exhaustive, with no `default`.
- [ ] Integration tests (`integration_test`): WebView loads a local test page that exercises the bridge end-to-end, file chooser invocation, `auth.setSession`/`auth.signOut` round-trip, unknown-scheme navigation cancelled, `files.share` payload path.
- [ ] Angular: specs for `NativeBridgeService` (stub + timeout + queue-before-ready) and the `DeviceLocationService` bridge path; `npm run build` must pass (the Karma target is known to be broken on `stage`, so do not gate on `npm test`).

### 17.2 Manual device matrix (D12)

Devices: Samsung (Galaxy A/S), Xiaomi/Redmi, Huawei/Honor, Oppo/Realme/Vivo, Pixel (reference). Android 10, 11, 12, 13, 14, 15 as priority; one Android 8/9 device if the fleet still has any.

| Scenario | Steps | Pass criteria |
|---|---|---|
| Online mode | login → journey → check-in → check-out | all calls succeed; fixes upload live |
| Offline tracking | airplane mode → move around 20 min → restore network | fixes queued (`pending` count grows), uploaded in batches on restore, none lost or duplicated |
| Network loss/recovery mid-upload | toggle `svc wifi disable` / `svc data disable` during a batch → restore | batch resumes; no duplicates; `sync.completed` |
| Phone locked | lock 60 min | fixes every ~5 s (± OEM), uploaded when unlocked or live |
| App backgrounded | switch apps 30 min | same as locked |
| Removed from Recents | swipe away → wait 30 min | service alive on stock Android; record per OEM |
| Background tracking accuracy | drive a known route | track matches road, no large gaps |
| Location permission changes | revoke in settings while running | `permission_required`, notification updated, auto-resume after re-grant |
| Location services off/on | toggle GPS | `LOCATION_DISABLED` then auto-resume |
| Android Force Stop | Force Stop → wait → relaunch | nothing uploaded while stopped; launch reports it; tracking resumes |
| Reboot | reboot with a session stored | service back without opening the app |
| Token expiry | short-lived token | uploads pause, `auth.sessionExpired`, resume after login, no lost rows |
| User swap | sign out A, sign in B | A's rows not uploaded under B |
| Battery saver / Doze | `adb shell dumpsys deviceidle force-idle` | FGS keeps running |
| Different Android versions | 8/9, 10, 11, 12, 13, 14, 15 | permission flow correct per version |
| Different OEMs | list above | document autostart/battery steps that were needed |
| WebView features | upload photo (camera + gallery), print/share/save PDF, navigate to client, phone-call link | each opens the right native surface |
| Orientation | journey in portrait, routes in landscape on a tablet | no stray rotate overlay |
| **Old tracker regression (G1)** | with the new Angular build deployed: Chrome/PWA on a phone with the old tracker → log in, sign out, "Sign in with DynaOps" | hand-off to the tracker works as before; tracker tracks and uploads; no shell code involved |
| **Shell without tracker (G2)** | fresh phone, old tracker **not** installed → install shell, log in, lock phone 1 h | tracking starts, points upload, nothing tries to open `dyngis://` |
| Both installed (OPEN, §0.1) | old tracker + shell on one phone | behaviour matches the rollout decision (notice shown / duplicates accepted) |

Useful adb commands to keep in the test doc:

```text
adb shell am force-stop <applicationId>
adb shell am kill <applicationId>
adb shell dumpsys deviceidle force-idle
adb shell cmd appops set <applicationId> RUN_IN_BACKGROUND ignore
adb shell svc wifi disable && adb shell svc data disable
adb shell settings put secure location_mode 0
adb shell dumpsys activity services <applicationId>
```

---

## 18. Angular-side changes (additive only, no rewrite) — ANGULAR

All new code under `src/app/core/native/`; browser/PWA behaviour must be unchanged.

- [ ] `core/native/native-bridge.service.ts`, `native-bridge.contract.ts`, `native-bridge.stub.ts` (§6.3).
- [ ] `core/native/native-session-sync.ts` (new): `syncOnReady()` (on `dynaops-native-ready`, pushes Angular's stored session via `auth.setSession`), `signedIn(data)`, `signedOut()`.
- [ ] `AuthService`: `if (isNative()) → nativeSession.*, else → existing tracker calls` at login and deliberate sign-out; login page hides "Sign in with DynaOps" when native.
- [ ] LEGACY, **not modified**: `core/auth/tracker-link.ts`, `core/auth/handoff.ts`, `dyngis://` scheme, `int-dyngis_tracker`. They keep serving the browser/PWA and the old tracker exactly as today.
- [ ] `shared/services/device-location.service.ts`: when native → `tracking.latest` (fallback to the browser API on `UNSUPPORTED`); keep the `DeviceLocationResult` shape so `VisitExecutionService` and the capture screen need no change.
- [ ] Day start: pass the device fix into `DayStartRequest` when native.
- [ ] `app.component.ts`: skip `pwaInstall.init()` when native; `pwaUpdate.init()` may stay (remote loading) but must not loop; `DeviceOrientationService` never locks when native (no bridge call, `canRequestLandscape` false, `requestLandscape()` returns false).
- [ ] `app.config.ts`: `provideServiceWorker(..., { enabled: !isDevMode() && !isNativeShell() })` where `isNativeShell()` checks `window.DynaOpsNative` (safe at bootstrap because the script is injected at document start).
- [ ] `pwa-install-button`: hidden when native.
- [ ] Journey screen: tracking status chip (`tracking.statusChanged`), pending-upload badge (`sync.status` / `sync.*`), "Fix tracking permissions" → `permissions.request` / `app.openSettings`; optional offline banner (§10).
- [ ] `print-pdf.ts`, `order-report.service.ts`, `field-sales-payment.service.ts` (`journalReport`), and the Excel exporters used on the rep device: when native → Blob → base64 → `files.share` / `files.print` / `files.save` / `files.open` (D14).
- [ ] Transloco keys (en + ar): tracking states, offline banner, permission prompts, bridge error codes, "sign in to resume uploads".
- [ ] `npm run build` green; list touched specs for the owner.
- [ ] **FUTURE (D7):** native branches in the field-sales feature services for `data.*` — see §10.2.

---

## 19. Delivery phases

- [ ] **M0 — Remaining decisions**: D2 hostname(s) per tenant, D11 app identity + keystore, both-apps-on-one-phone rollout (§0.1); location upload contract (D5) can land during M2.
- [~] **M1 — Shell** — *code complete 2026-10-05, not yet run on a device.* Flutter: branch `m1-shell` (analyze clean, 49 unit tests, debug APK builds). Angular: branch `flutter-shell` (`npm run build` green, tracker files unchanged). Remaining: real tenant `env/<tenant>.json` (D2), device run of the exit criteria and the G1 regression, the §7 restore decision, and Excel/`FileSaver.saveAs` exports outside the rep screens (blob downloads do nothing in a WebView until they go through `files.save`). Original scope: WebView loads the remote app, navigation policy, file chooser, geolocation prompt, bridge v1.0 with `app.*`, `auth.*`, `permissions.*`, `network.*`, `files.*`; Angular `NativeBridgeService` + native session sync (tracker code untouched) + PWA no-ops + files hook; decide the §7 restore fallback; PostHog Flutter wired. Angular changes deployed first (§0.1). Exit: rep logs in, works online, uploads a photo, shares an order PDF; **old tracker regression (G1) passes** in Chrome/PWA.
- [~] **M2 — Tracking** — *code complete 2026-10-06, field test pending.* Flutter: tracking service (`flutter_foreground_task` 11, `geolocator` 14, `sqflite`), engine + coordinator, real uploader to `LocationPings/batch` (D5), `tracking.*`/`sync.*`/`app.openNativeScreen`, walkthrough + OEM guidance, diagnostics; 112 unit tests, debug APK builds. Angular: `NativeTrackingService`, journey status strip / pending badge / offline banner / "Fix tracking permissions", `DeviceLocationService` → `tracking.latest`, day-start fix (`latitude`/`longitude` only; `from` left empty because it is a place name), resume refresh; `npm run build` green. Remaining: the field test below, Play-Store disclosure review, and an idempotency key from the backend (§11 dedupe). Original scope: foreground service, auto-start policy, local points store, `LocationUploader` (stub → real once D5 arrives), `tracking.*`/`sync.*` actions and events, `DeviceLocationService` bridged, permission walkthrough, battery/OEM guidance, diagnostics screen. Exit: 8-hour field test on two OEMs with locked phone and Recents swipe; airplane-mode queue drains correctly.
- [ ] **M3 — Hardening & release**: full device matrix (§17.2), Force Stop/reboot behaviour, security review (§16), per-tenant release builds (D9/D11), Play Store background-location disclosure.
- [ ] **M4 — FUTURE: offline business features** (planned, not implemented now): bundled web assets (D2), offline reads, then offline writes starting with sales orders — full plan in §10.2. Also Route-mode day-start/day-end gating.

---

## 20. Decision log

| # | Question | Decision | Date |
|---|---|---|---|
| D1 | Replace the existing tracker? | Yes, dynaopsapp replaces it with no tracker code in Flutter; session via bridge only; Angular tracker code kept unchanged | 2026-10-05 |
| D2 | How Angular is loaded | **OPEN** — working assumption: remote URL; hostname per tenant still needed | — |
| D3 | Tracking stack | Free: `flutter_foreground_task` + `geolocator` | 2026-10-05 |
| D4 | WebView plugin | `flutter_inappwebview` | 2026-10-05 |
| D5 | Location upload API | `POST LocationPings/batch` (contract read from the old tracker's code); real uploader, no stub; no dedupe key | 2026-10-06 |
| D6 | Token refresh | None; pause uploads at expiry, resume after login | 2026-10-05 |
| D7 | Offline scope | Tracking only; batch upload when online | 2026-10-05 |
| D8 | When tracking runs | Auto-start on app use with a valid session; no Start button; rep cannot stop it (§8.1) — confirmed | 2026-10-05 |
| D9 | Tenant config | Per-tenant builds (flavors + `--dart-define`) | 2026-10-05 |
| D10 | Local DB | `sqflite` | 2026-10-05 |
| D11 | App id / label / icon / keystore | **OPEN** — needed before first release build | — |
| D12 | Min Android / devices | minSdk 24, targetSdk 36; matrix in §17.2 | 2026-10-05 |
| D13 | Login surface | Angular login page only | 2026-10-05 |
| D14 | PDF print/share on phone | Required (`files.*`) | 2026-10-05 |
| D15 | Error reporting | Flutter shell: PostHog Flutter; Angular keeps its PostHog | 2026-10-05 |
| D16 | Maps key referrer | N/A while remote-loaded | 2026-10-05 |
| D17 | iOS | Out of scope | 2026-10-05 |
