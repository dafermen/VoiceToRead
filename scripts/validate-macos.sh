#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This validation requires macOS with Xcode 15.2 or later." >&2
  exit 1
fi
xcodebuild -version
version="$(xcodebuild -version | awk '/Xcode/{print $2}')"
major="${version%%.*}"
minor="${version#*.}"
minor="${minor%%.*}"
if (( major < 15 || (major == 15 && minor < 2) )); then
  echo "Xcode 15.2+ is required." >&2
  exit 1
fi
run_dir="$project_root/build/validation-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$run_dir"
xcrun simctl list devices available -j > "$run_dir/simulators.json"
simulator_id="${VOICETOREAD_SIMULATOR_ID:-}"
if [[ -z "$simulator_id" ]]; then
  simulator_id="$(python3 - "$run_dir/simulators.json" <<'PY'
import json, re, sys
data = json.load(open(sys.argv[1]))
for runtime, devices in data["devices"].items():
    version = re.search(r"iOS-(\d+)", runtime)
    if version and int(version.group(1)) >= 17:
        for device in devices:
            if device.get("isAvailable") and "iPhone" in device["name"]:
                print(device["udid"])
                raise SystemExit(0)
raise SystemExit("Install an iOS 17+ iPhone simulator runtime.")
PY
)"
fi
derived="$run_dir/DerivedData"
xcodebuild -project VoiceToRead.xcodeproj -scheme VoiceToRead -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$derived" \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tee "$run_dir/debug-build.log"
xcodebuild -project VoiceToRead.xcodeproj -scheme VoiceToRead -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath "$derived" \
  -parallel-testing-enabled NO -resultBundlePath "$run_dir/Tests.xcresult" CODE_SIGNING_ALLOWED=NO test 2>&1 | tee "$run_dir/tests.log"
xcodebuild -project VoiceToRead.xcodeproj -scheme VoiceToRead -configuration Release \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$derived" \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tee "$run_dir/release-build.log"
app="$derived/Build/Products/Release-iphonesimulator/VoiceToRead.app"
plutil -lint "$app/Info.plist" "$app/PrivacyInfo.xcprivacy"
python3 - "$app" <<'PY'
import pathlib, plistlib, sys
app = pathlib.Path(sys.argv[1])
with (app / "Info.plist").open("rb") as f:
    info = plistlib.load(f)
assert info.get("NSMicrophoneUsageDescription"), "Missing microphone purpose"
assert info.get("NSSpeechRecognitionUsageDescription"), "Missing speech recognition purpose"
assert info.get("MinimumOSVersion") == "17.0", "Unexpected minimum iOS version"
assert info.get("CFBundleDisplayName") == "VoiceToRead", "Unexpected app name"
assert info.get("CFBundleIdentifier") == "com.innovalogic.voicetoread", "App identity changed"
assert info.get("CFBundleExecutable") == "VoiceToRead", "Unexpected executable name"
assert {"UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"}.issubset(set(info.get("UISupportedInterfaceOrientations", []))), "Missing reading orientations"
assert set(info.get("UIDeviceFamily", [])) == {1, 2}, "iPhone/iPad support missing"
assert {"UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown", "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"} == set(info.get("UISupportedInterfaceOrientations~ipad", [])), "Missing iPad orientations"
assert info.get("UIBackgroundModes") == ["audio"], "Missing or unexpected background modes"
assert (app / "Assets.car").exists(), "Missing compiled assets"
with (app / "PrivacyInfo.xcprivacy").open("rb") as f:
    privacy = plistlib.load(f)
assert privacy.get("NSPrivacyTracking") is False, "Unexpected tracking"
print("Release simulator bundle checks passed.")
PY
echo "Validation artifacts: $run_dir"
echo "Physical iPhone/iPad, Airplane Mode, accessibility, privacy and extended-session gates still require manual checks."
