#!/bin/zsh

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Echo Labs
# @raycast.mode fullOutput
# @raycast.packageName Echo
# @raycast.icon 🧪

# Documentation:
# @raycast.description Build and open Echo Labs

# Builds Echo Labs, wraps it in an app bundle and (re)launches it. Fast: an incremental build
# takes a few seconds. Also a Raycast script command (the headers above); Raycast only finds
# scripts directly inside a configured folder, so this file stays in EchoLab/Scripts.
#
# While it builds it shows live progress (in Raycast's output window, or the terminal) and posts
# a notification when the build starts and when Echo Labs is ready. `--no-launch` builds only.
# Echo Labs runs this itself for Rebuild and Relaunch (⌘⇧B), with ECHOLAB_QUIET=1.
set -e
cd "${0:A:h}/.."                      # EchoLab/

# Notifications carry the Echo Labs icon when the built app can post them itself (`--notify`);
# before the first build with that support, fall back to a plain notification.
bundle_dir=$(swift build --show-bin-path 2>/dev/null)
notify() {
  [[ -n "$ECHOLAB_QUIET" ]] && return 0   # set by the app's own Rebuild command, which shows progress itself
  local app="$bundle_dir/Echo Labs.app"
  if [[ -x "$app/Contents/MacOS/EchoLab" ]] && /usr/libexec/PlistBuddy -c "Print :EchoLabNotify" "$app/Contents/Info.plist" >/dev/null 2>&1; then
    "$app/Contents/MacOS/EchoLab" --notify "$1" >/dev/null 2>&1 || true
  else
    osascript -e "display notification \"$1\" with title \"Echo Labs\"" >/dev/null 2>&1 || true
  fi
}

started=$SECONDS
echo "Building Echo Labs…"
notify "Building…"

# swift build prints "[done/total] Compiling …"; turn that into a percentage every few percent.
last=-10
log=$(mktemp)
swift build 2>&1 | tee "$log" | while IFS= read -r line; do
  if [[ $line =~ '^\[([0-9]+) ?/ ?([0-9]+)\]' ]]; then
    step=${match[1]}; total=${match[2]}
    pct=$(( total > 0 ? step * 100 / total : 100 ))
    if (( pct - last >= 10 || pct == 100 )); then
      last=$pct
      bar=$(printf '%*s' $(( pct / 5 )) '' | tr ' ' '█')
      printf '%3d%%  %s  (%s of %s steps)\n' "$pct" "$bar" "$step" "$total"
    fi
  elif [[ $line == *"error:"* || $line == *"Fetching"* || $line == *"Resolving"* ]]; then
    echo "$line"
  fi
done
if ! grep -q "Build complete" "$log"; then
  echo "Build failed:"; grep -E "error:" "$log" | head -10
  notify "Build failed. See the output for the errors."
  rm -f "$log"; exit 1
fi
rm -f "$log"
echo "Built in $(( SECONDS - started )) s."
bin=$(swift build --show-bin-path)
app="$bin/Echo Labs.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Resources/EchoLab.icns "$app/Contents/Resources/EchoLab.icns"
cp "$bin/EchoLab" "$app/Contents/MacOS/EchoLab"
# SwiftPM resource bundles (server-lab recipes, scenarios, ...): Bundle.module aborts when they are missing.
for resources in "$bin"/*.bundle(N); do cp -R "$resources" "$app/Contents/Resources/"; done
# Binary frameworks the drivers link (EchoLibpq, EchoMariaDB, OpenSSL, ...): dyld aborts at launch without them.
frameworks=("$bin"/*.framework(N))
if (( ${#frameworks} )); then
  mkdir -p "$app/Contents/Frameworks"
  for framework in $frameworks; do cp -R "$framework" "$app/Contents/Frameworks/"; done
  install_name_tool -add_rpath @executable_path/../Frameworks "$app/Contents/MacOS/EchoLab" 2>/dev/null || true
fi
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>dev.echodb.echolab</string>
<key>CFBundleName</key><string>Echo Labs</string>
<key>EchoLabNotify</key><true/>
<key>CFBundleIconFile</key><string>EchoLab</string>
<key>CFBundleExecutable</key><string>EchoLab</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Sign ad hoc so macOS lets the bundle post notifications.
codesign --force --deep --sign - "$app" >/dev/null 2>&1 || true

[[ "$1" == "--no-launch" ]] && { echo "Built (not launched)."; exit 0; }

# Quit a running copy so the new build is the one you see.
osascript -e 'tell application id "dev.echodb.echolab" to quit' >/dev/null 2>&1 || true
sleep 0.5
open "$app"
echo "Echo Labs is open."
if (( SECONDS - started > 3 )); then notify "Ready."; fi
