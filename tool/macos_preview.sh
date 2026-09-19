#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

surface="${1:-fluent}"
mode="${2:-debug}"
case "$surface" in
  fluent) preview_args=(--dart-define=MACOS_FLUENT_PREVIEW=true) ;;
  material) preview_args=(--dart-define=DESKTOP_PREVIEW=true) ;;
  legacy) preview_args=() ;;
  *) echo 'Usage: tool/macos_preview.sh [fluent|material|legacy] [debug|release]' >&2; exit 2 ;;
esac
case "$mode" in debug|release) ;; *) echo 'Mode must be debug or release.' >&2; exit 2 ;; esac

flutter_bin="${FLUTTER_BIN:-}"
if [[ -z "$flutter_bin" ]]; then
  pinned_version="$(sed -n 's/.*"flutter": "\([^"]*\)".*/\1/p' .fvmrc)"
  if [[ -x ".fvm/flutter_sdk/bin/flutter" ]]; then
    flutter_bin="$repo_root/.fvm/flutter_sdk/bin/flutter"
  elif [[ -x "$HOME/.local/share/flutter/$pinned_version/bin/flutter" ]]; then
    flutter_bin="$HOME/.local/share/flutter/$pinned_version/bin/flutter"
  else
    flutter_bin="$(command -v flutter || true)"
  fi
fi
if [[ -z "$flutter_bin" || ! -x "$flutter_bin" ]]; then
  echo 'Set FLUTTER_BIN to the Flutter executable matching .fvmrc.' >&2
  exit 1
fi

# Local ad-hoc signing, not a distributable Developer ID build.
export FLUTTER_XCODE_CODE_SIGN_IDENTITY="${FLUTTER_XCODE_CODE_SIGN_IDENTITY:--}"
export FLUTTER_XCODE_DEVELOPMENT_TEAM="${FLUTTER_XCODE_DEVELOPMENT_TEAM-}"
export FLUTTER_XCODE_CODE_SIGN_STYLE="${FLUTTER_XCODE_CODE_SIGN_STYLE:-Manual}"
if [[ "$(uname -m)" == arm64 ]]; then
  export FLUTTER_MACOS_ARM64_ONLY=true
fi
# Local macOS 27 / Rust strip workaround recorded in history/stage-a.md.
export CARGO_PROFILE_RELEASE_STRIP="${CARGO_PROFILE_RELEASE_STRIP:-none}"
exec "$flutter_bin" run -d macos "--$mode" --no-pub "${preview_args[@]}"
