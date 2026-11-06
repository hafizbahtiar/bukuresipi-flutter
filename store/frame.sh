#!/usr/bin/env bash
# Phone screenshots -> Play's 9:16 (1080 x 1920). Put raw screenshots in store/screens/raw/, run ./store/frame.sh;
# each is scaled to 1920 tall and centred on the brand green (a 1080 x 2400 phone shot is 9:20, which Play refuses).
set -euo pipefail
cd "$(dirname "$0")/screens"
shopt -s nullglob
for f in raw/*.png raw/*.jpg raw/*.jpeg; do
  out="$(basename "${f%.*}").png"
  sips -s format png --resampleHeight 1920 "$f" --out "$out" >/dev/null
  [ "$(sips -g pixelWidth "$out" | awk '/pixelWidth/{print $2}')" -le 1080 ] || sips --resampleWidth 1080 "$out" >/dev/null
  sips --padToHeightWidth 1920 1080 --padColor 1F4A29 "$out" >/dev/null 2>&1
  echo "screens/$out"
done
