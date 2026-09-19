# Desktop preview

Status: retained interaction prototype; active macOS validation now targets the shared Fluent UI.

Original status: local preview on `desktop-preview`; release packaging is blocked by a Flutter AOT compiler crash. This is an opt-in desktop browsing surface for Windows and macOS, built with Flutter's Material widgets. It reuses the existing API clients, account storage, illustration models, image cache and local mute rules. Default mobile and Windows Fluent entry points remain available.

## Scope

- Recommendations and keyword search, with pagination and stale-response protection.
- A persistent browse grid with an illustration detail pane and full-image viewer.
- Mouse, keyboard and explicit save actions.
- Save the current original image through the OS save dialog. Cancellation is not success; writing errors are returned to the UI.
- Reuse the current account, or authorize through an external browser.

This iteration does not replace the full existing app: ranking, collection management, persistent download directories, a background download manager and animated-image export are outside its scope. The original Photos save path is unchanged. The preview saves images through the existing `file_picker` dependency instead.

## Run

Use the repository's pinned Flutter version, restore locked dependencies and generate code as described in [Stage A](history/stage-a.md). Add `--dart-define=DESKTOP_PREVIEW=true` to the normal platform build/run command. Without the define, the original entry point is selected. The flag is ignored on mobile platforms.

On the local Mac used for Stage A, ad-hoc signing and the macOS 27 Rust strip workaround are still required:

```sh
export PATH=/Users/kzime/.local/share/flutter/3.47.3/bin:$PATH
export FLUTTER_XCODE_CODE_SIGN_IDENTITY=-
export FLUTTER_XCODE_DEVELOPMENT_TEAM=''
export FLUTTER_XCODE_CODE_SIGN_STYLE=Manual
export FLUTTER_MACOS_ARM64_ONLY=true
export CARGO_PROFILE_RELEASE_STRIP=none
flutter build macos --debug --no-pub --dart-define=DESKTOP_PREVIEW=true
```

Windows uses `flutter build windows --release --dart-define=DESKTOP_PREVIEW=true`; it needs a Windows build environment. Windows runtime compatibility must not be inferred from macOS results.

macOS receives only user-selected file read/write access for the save dialog; this does not grant blanket filesystem or Photos access. The existing bundle identifier and database location are retained. If another installed PixEz owns `pixiv://`, a browser callback can open that app instead; see the Stage A handler verification procedure.

## Maintenance boundaries

- `lib/desktop/desktop_browse_controller.dart`: request/selection state, independent of platform UI.
- `lib/desktop/desktop_preview_page.dart` and `desktop_image_viewer.dart`: shared Windows/macOS desktop interaction.
- `lib/desktop/desktop_file_save.dart`: image cache plus the existing cross-platform native picker.
- `lib/network/auth_session.dart`: account exchange/persistence used by existing and preview entry points.
- `desktop_preview_app.dart`: opt-in initialization, theme, account binding and native URL events.
- `MainFlutterWindow.swift`: macOS native Find-menu dispatch and pending URL delivery. Windows uses normal Flutter Ctrl+F handling and the existing single-instance URI pipe.

Extra preview copy currently provides Chinese and English fallback in a small local strings class. Before broader upstream integration, move new copy into the repository's translation workflow and cover other locales.

## Validation

- Targeted `flutter analyze`: no issues found.
- 14 tests pass: request ordering, pagination overlap/retry/disposal, save completion/cancellation/errors, URI dispatch and repeated Cmd/Ctrl+F → Enter → Escape, plus native macOS Find-menu dispatch.
- Release: both the initial and final source builds failed in Dart `gen_snapshot`, with `Class with illegal cid, full-aot` for Flutter's `_window_macos.dart::_Rect`. This matches [Flutter issue #191575](https://github.com/flutter/flutter/issues/191575); the report is evidence of a matching known failure, not proof of the precise compiler root cause in this application. No SDK source patch has been applied.
- Debug arm64 build succeeds; `codesign --verify --deep --strict` succeeds.
- Real macOS runtime: existing account reused after restart; recommendations load; tag search `landscape` returns 28 works and scrolling adds results to 57; wide side-by-side details and narrow overlay both work; Escape returns to the same narrow-list position; full image renders; context menu offers explicit details/save actions.
- Actual Cmd+F after startup and again after search selects the search field. The macOS Find menu is explicitly connected only while the preview is mounted.
- Native Save As: cancellation shows no success. A completed save produced a 1920×1080 RGB PNG, 3,790,653 bytes; the success path was visible in the UI after the file existed. SHA-256: `d7b4134f58da0f3e3244e0057b2e4a78e359f991fbd02c58822e57f9af5bf8bd`.
- Windows build/runtime and a fresh browser authorization were not exercised in this iteration. Existing-account persistence was exercised. Default mobile/Fluent UI regression testing remains a prerequisite for a broader merge.
- Flutter's macOS accessibility bridge intermittently reported stale AX-tree updates during UI automation; screenshots and native dialogs were used to verify the actual UI state. Accessibility needs additional acceptance before a public release.

Local evidence is stored outside the repository in `/Users/kzime/Projects/pixez-stage-a-evidence/desktop-*.log`. Do not submit local account data, caches or runtime images with the contribution.

## Proposed contribution split

1. Existing macOS build prerequisites and local verification instructions.
2. Shared sign-in completion and platform URL delivery fixes, with sensitive callback logging removed.
3. The opt-in desktop preview, native save-dialog entitlement and behavioral tests.

These changes are local; no public pull request or release has been published from this task.
