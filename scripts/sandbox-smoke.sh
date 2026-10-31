#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
fixture=$(mktemp "$PWD/.build/sandbox-denied.XXXXXX")
trap 'rm -f "$fixture"' EXIT
printf 'non-sensitive sandbox test fixture\n' > "$fixture"
[[ -r "$fixture" ]] || exit 1
arguments=(--security-smoke-test --deny-read "$fixture")
if [[ "${BARLUMA_REQUIRE_NETWORK:-0}" == 1 ]]; then arguments+=(--require-network); fi
"$PWD/dist/BarLuma.app/Contents/MacOS/TopBar" "${arguments[@]}"
