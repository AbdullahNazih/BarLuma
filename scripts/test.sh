#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
swiftc -O -module-cache-path "$PWD/.build/clang-cache" \
    Sources/TopBar/Metrics.swift Sources/TopBar/Weather.swift \
    Sources/TopBar/SecureWeatherTransport.swift Sources/TopBar/Preferences.swift \
    Sources/TopBar/WeatherAppearance.swift \
    Sources/TopBar/WindowPlacement.swift Sources/TopBar/ApplicationRemovalPlan.swift \
    Tests/TopBarTests/TopBarTests.swift -o .build/TopBarChecks
.build/TopBarChecks "$@"
