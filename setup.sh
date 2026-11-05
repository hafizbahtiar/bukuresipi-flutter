#!/usr/bin/env bash
# Clean, pub get, pod install, then (optional) build an Android APK or AAB and copy it to apk/ or aab/ as
# bukuresipi-v<name>(<code>)[-dev].<ext>. Asks everything first, then runs unattended. "none" = only the first three.
#   dev  = debug build (debug key, debuggable)
#   prod = release build (upload key from android/key.properties)
# Both use the same API: the app has one .env (production).
set -euo pipefail
cd "$(dirname "$0")"

# Colours only on a terminal (none when piped or logged).
if [ -t 1 ]; then
  B=$'\e[1m' DIM=$'\e[2m' RED=$'\e[31m' GREEN=$'\e[32m' YELLOW=$'\e[33m' CYAN=$'\e[36m' R=$'\e[0m'
else
  B='' DIM='' RED='' GREEN='' YELLOW='' CYAN='' R=''
fi
step() { echo; echo "${CYAN}${B}==> $*${R}"; }
fail() { echo "${RED}${B}✗ $*${R}" >&2; exit 1; }

ask() { # ask <prompt> <option>... -> echoes the chosen option
  local prompt=$1 answer o
  shift
  local IFS=/
  while true; do
    read -rp "${B}$prompt${R} ${DIM}[$*]${R}: " answer
    for o in "$@"; do [ "$answer" = "$o" ] && { echo "$answer"; return; }; done
    echo "${YELLOW}Type one of: $*${R}" >&2
  done
}

type=$(ask "Build" apk aab none)
echo
if [ "$type" = none ]; then
  echo "${B}Will run:${R} flutter clean, flutter pub get, pod install ${DIM}(no build)${R}"
else
  env=$(ask "Environment" dev prod)
  version=$(sed -n 's/^version: *//p' pubspec.yaml) # e.g. 1.0.0+1
  name=${version%%+*}
  code=${version##*+}
  suffix=$([ "$env" = dev ] && echo "-dev" || true)
  out="$type/bukuresipi-v$name($code)$suffix.$type"
  if [ "$env" = prod ] && [ ! -f android/key.properties ]; then
    fail "android/key.properties is missing: a prod build needs the upload key."
  fi
  echo
  echo "${B}Will run:${R} flutter clean, flutter pub get, pod install, then build ${B}$type${R} (${B}$env${R})"
  echo "${B}Output:${R}   ${GREEN}$out${R}"
fi
[ "$(ask "Proceed?" y n)" = y ] || { echo "${YELLOW}Stopped.${R}"; exit 0; }

step "flutter clean"
flutter clean
step "flutter pub get"
flutter pub get
step "pod install"
if command -v pod >/dev/null; then
  (cd ios && pod install)
else
  echo "${YELLOW}pod not found: skipping pod install${R}"
fi

if [ "$type" = none ]; then
  echo
  echo "${GREEN}${B}✓ Done:${R} cleaned, packages and pods installed"
  exit 0
fi

mode=$([ "$env" = dev ] && echo debug || echo release)
step "flutter build $type --$mode"
if [ "$type" = apk ]; then
  flutter build apk "--$mode"
  built="build/app/outputs/flutter-apk/app-$mode.apk"
else
  flutter build appbundle "--$mode"
  built="build/app/outputs/bundle/$mode/app-$mode.aab"
fi

mkdir -p "$type"
cp "$built" "$out" || fail "build output not found: $built"
echo
echo "${GREEN}${B}✓ Done:${R} ${GREEN}$out${R} ${DIM}($(du -h "$out" | cut -f1))${R}"
