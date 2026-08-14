#!/bin/bash

set -euo pipefail

task_project_dir="$(cd "$(dirname "$0")/.." && pwd)"
task_app_dir="$task_project_dir/dist/GenLivePhoto.app"
task_codesign_identity="${GENLIVEPHOTO_CODESIGN_IDENTITY:--}"
task_architectures="${GENLIVEPHOTO_ARCHS:-arm64 x86_64}"
task_build_arguments=(-c release --package-path "$task_project_dir")
task_staging_dir="$(mktemp -d)"
task_staged_app_dir="$task_staging_dir/GenLivePhoto.app"

cleanup() {
    rm -rf "$task_staging_dir"
}
trap cleanup EXIT

for task_architecture in $task_architectures; do
    task_build_arguments+=(--arch "$task_architecture")
done

swift build "${task_build_arguments[@]}"
task_bin_dir="$(swift build "${task_build_arguments[@]}" --show-bin-path)"

"$task_project_dir/scripts/generate-app-icon.sh" "$task_project_dir/Supporting/AppIcon.icns"

rm -rf "$task_app_dir"
mkdir -p "$task_staged_app_dir/Contents/MacOS" "$task_staged_app_dir/Contents/Resources"
cp -X "$task_bin_dir/GenLivePhoto" "$task_staged_app_dir/Contents/MacOS/GenLivePhoto"
cp -X "$task_project_dir/Supporting/Info.plist" "$task_staged_app_dir/Contents/Info.plist"
cp -X "$task_project_dir/Supporting/AppIcon.icns" "$task_staged_app_dir/Contents/Resources/AppIcon.icns"
xattr -cr "$task_staged_app_dir"

if [[ "$task_codesign_identity" == "-" ]]; then
    codesign --force --deep --sign - "$task_staged_app_dir"
else
    codesign --force --deep --options runtime --timestamp \
        --sign "$task_codesign_identity" "$task_staged_app_dir"
fi

codesign --verify --deep --strict "$task_staged_app_dir"
mkdir -p "$(dirname "$task_app_dir")"
ditto --norsrc "$task_staged_app_dir" "$task_app_dir"

echo "$task_app_dir"
