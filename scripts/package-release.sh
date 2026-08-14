#!/bin/bash

set -euo pipefail

task_project_dir="$(cd "$(dirname "$0")/.." && pwd)"
task_info_plist="$task_project_dir/Supporting/Info.plist"
task_default_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$task_info_plist")"
task_version="${1:-$task_default_version}"

if [[ ! "$task_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
    echo "版本号格式无效：$task_version" >&2
    exit 2
fi

task_app_dir="$task_project_dir/dist/GenLivePhoto.app"
task_archive_name="GenLivePhoto-v${task_version}-macos-universal.zip"
task_archive_path="$task_project_dir/dist/$task_archive_name"
task_checksum_path="$task_archive_path.sha256"
task_verification_dir="$(mktemp -d)"

cleanup() {
    rm -rf "$task_verification_dir"
}
trap cleanup EXIT

"$task_project_dir/scripts/build-app.sh"

rm -f "$task_archive_path" "$task_checksum_path"
ditto -c -k --norsrc --keepParent "$task_app_dir" "$task_archive_path"
ditto -x -k "$task_archive_path" "$task_verification_dir"
codesign --verify --deep --strict "$task_verification_dir/GenLivePhoto.app"

task_binary_architectures="$(lipo -archs "$task_verification_dir/GenLivePhoto.app/Contents/MacOS/GenLivePhoto")"
if [[ "$task_binary_architectures" != *arm64* || "$task_binary_architectures" != *x86_64* ]]; then
    echo "发布包不是 Intel 与 Apple 芯片通用版本：$task_binary_architectures" >&2
    exit 1
fi

task_checksum="$(shasum -a 256 "$task_archive_path" | awk '{print $1}')"
printf '%s  %s\n' "$task_checksum" "$task_archive_name" > "$task_checksum_path"

echo "$task_archive_path"
echo "$task_checksum_path"
