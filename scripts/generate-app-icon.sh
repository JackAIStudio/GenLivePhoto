#!/bin/bash

set -euo pipefail

task_project_dir="$(cd "$(dirname "$0")/.." && pwd)"
task_output_path="${1:-$task_project_dir/Supporting/AppIcon.icns}"
task_icon_work_dir="$(mktemp -d)"
task_iconset_dir="$task_icon_work_dir/AppIcon.iconset"
task_master_png="$task_icon_work_dir/AppIcon-1024.png"

cleanup() {
  rm -rf "$task_icon_work_dir"
}
trap cleanup EXIT

mkdir -p "$task_iconset_dir" "$(dirname "$task_output_path")"
xcrun swift "$task_project_dir/scripts/generate-app-icon.swift" "$task_master_png"

while read -r task_pixels task_filename; do
  sips -z "$task_pixels" "$task_pixels" "$task_master_png" \
    --out "$task_iconset_dir/$task_filename" >/dev/null
done <<'SIZES'
16 icon_16x16.png
32 icon_16x16@2x.png
32 icon_32x32.png
64 icon_32x32@2x.png
128 icon_128x128.png
256 icon_128x128@2x.png
256 icon_256x256.png
512 icon_256x256@2x.png
512 icon_512x512.png
1024 icon_512x512@2x.png
SIZES

iconutil -c icns "$task_iconset_dir" -o "$task_output_path"
echo "$task_output_path"
