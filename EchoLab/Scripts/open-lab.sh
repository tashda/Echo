#!/bin/zsh
# Builds Echo Lab, wraps it in an app bundle and (re)launches it. Fast: an incremental build
# takes a few seconds. Usage: EchoLab/Scripts/open-lab.sh
set -e
cd "${0:A:h}/.."                      # EchoLab/
swift build 2>&1 | grep -E "error|warning: unre|Compiling|Build" | tail -5
bin=$(swift build --show-bin-path)
app="$bin/Echo Lab.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$bin/EchoLab" "$app/Contents/MacOS/EchoLab"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>dev.echodb.echolab</string>
<key>CFBundleName</key><string>Echo Lab</string>
<key>CFBundleExecutable</key><string>EchoLab</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Quit a running copy so the new build is the one you see.
osascript -e 'tell application id "dev.echodb.echolab" to quit' >/dev/null 2>&1 || true
sleep 0.5
open "$app"
