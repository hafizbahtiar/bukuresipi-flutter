#!/usr/bin/env bash
# Renders the six Play screenshot banners (screen.html) to screens/ms/ and screens/en/, 1080 x 1920 PNG.
# Needs screens/raw/1-book.jpeg ... 6-shopping.jpeg (see README.md) and a Chromium browser (BROWSER, default Brave).
set -euo pipefail
cd "$(dirname "$0")"
browser=${BROWSER:-/Applications/Brave Browser.app/Contents/MacOS/Brave Browser}
for lang in ms en; do
  mkdir -p "screens/$lang"
  for n in 1 2 3 4 5 6; do
    "$browser" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files --window-size=1080,1920 \
      --virtual-time-budget=4000 --screenshot="$PWD/screens/$lang/$n.png" "file://$PWD/screen.html?lang=$lang&n=$n" 2>/dev/null
    echo "screens/$lang/$n.png"
  done
done
