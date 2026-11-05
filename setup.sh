#!/usr/bin/env bash
# Build an Android APK or AAB and copy it to apk/ or aab/ as bukuresipi-v<name>(<code>)[-dev].<ext>.
# Asks everything first, then runs unattended: clean, pub get, pod install, build, copy.
#   dev  = debug build (debug key, debuggable)
#   prod = release build (upload key from android/key.properties)
# Both use the same API: the app has one .env (production).
set -euo pipefail
cd "$(dirname "$0")"

ask() { # ask <prompt> <option1> <option2> -> echoes the chosen option
  local answer
  while true; do
    read -rp "$1 [$2/$3]: " answer
    case "$answer" in "$2" | "$3") echo "$answer"; return ;; esac
    echo "Type $2 or $3." >&2
  done
}

type=$(ask "Build" apk aab)
env=$(ask "Environment" dev prod)

version=$(sed -n 's/^version: *//p' pubspec.yaml) # e.g. 1.0.0+1
name=${version%%+*}
code=${version##*+}
suffix=$([ "$env" = dev ] && echo "-dev" || true)
out="$type/bukuresipi-v$name($code)$suffix.$type"

if [ "$env" = prod ] && [ ! -f android/key.properties ]; then
  echo "android/key.properties is missing: a prod build needs the upload key." >&2
  exit 1
fi

echo
echo "Will run: flutter clean, flutter pub get, pod install, then build $type ($env) -> $out"
[ "$(ask "Proceed?" y n)" = y ] || { echo "Stopped."; exit 0; }

flutter clean
flutter pub get
if command -v pod >/dev/null; then
  (cd ios && pod install)
else
  echo "pod not found: skipping pod install"
fi

mode=$([ "$env" = dev ] && echo debug || echo release)
if [ "$type" = apk ]; then
  flutter build apk "--$mode"
  built="build/app/outputs/flutter-apk/app-$mode.apk"
else
  flutter build appbundle "--$mode"
  built="build/app/outputs/bundle/$mode/app-$mode.aab"
fi

mkdir -p "$type"
cp "$built" "$out"
echo
echo "Done: $out"
