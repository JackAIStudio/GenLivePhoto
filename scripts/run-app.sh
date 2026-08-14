#!/bin/bash

set -euo pipefail

task_project_dir="$(cd "$(dirname "$0")/.." && pwd)"
task_app_dir="$task_project_dir/dist/GenLivePhoto.app"
task_app_executable="$task_app_dir/Contents/MacOS/GenLivePhoto"

# 与 Xcode 的 Run 行为一致：先结束这个项目上一次启动的 App，再运行新构建。
task_running_pids="$(pgrep -x GenLivePhoto || true)"
for task_pid in $task_running_pids; do
    task_command="$(ps -p "$task_pid" -o command= || true)"
    if [[ "$task_command" == "$task_app_executable" ]]; then
        kill -TERM "$task_pid"
        for _ in {1..20}; do
            if ! kill -0 "$task_pid" 2>/dev/null; then
                break
            fi
            sleep 0.1
        done
        if kill -0 "$task_pid" 2>/dev/null; then
            echo "无法结束上一次运行的 GenLivePhoto，请先手动退出应用。" >&2
            exit 1
        fi
    fi
done

"$task_project_dir/scripts/build-app.sh"
open "$task_app_dir"
osascript -e 'tell application id "cn.followjack.genlivephoto" to activate'
