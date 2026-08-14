#!/bin/bash

set -euo pipefail

task_project_dir="$(cd "$(dirname "$0")/.." && pwd)"
swift build -c release --package-path "$task_project_dir"
task_bin_dir="$(swift build -c release --package-path "$task_project_dir" --show-bin-path)"
task_app_dir="$task_project_dir/dist/GenLivePhoto.app"

"$task_project_dir/scripts/generate-app-icon.sh" "$task_project_dir/Supporting/AppIcon.icns"

rm -rf "$task_app_dir"
mkdir -p "$task_app_dir/Contents/MacOS" "$task_app_dir/Contents/Resources"
cp "$task_bin_dir/GenLivePhoto" "$task_app_dir/Contents/MacOS/GenLivePhoto"
cp "$task_project_dir/Supporting/Info.plist" "$task_app_dir/Contents/Info.plist"
cp "$task_project_dir/Supporting/AppIcon.icns" "$task_app_dir/Contents/Resources/AppIcon.icns"
xattr -cr "$task_app_dir"
codesign --force --deep --sign - "$task_app_dir"

echo "$task_app_dir"
