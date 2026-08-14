#!/bin/bash

set -euo pipefail

if command -v makelive >/dev/null 2>&1; then
    makelive --version
    exit 0
fi

if ! command -v uv >/dev/null 2>&1; then
    echo "未找到 uv。请先安装 uv：https://docs.astral.sh/uv/" >&2
    exit 1
fi

uv tool install makelive
makelive --version
