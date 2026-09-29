#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p .build-cache
xcrun swiftc -swift-version 5 -module-cache-path "$PWD/.build-cache" Sources/BarModel.swift Sources/PathLogic.swift Sources/BarGeometry.swift Sources/AddressFeatures.swift Tests/main.swift -o .build-cache/PathTests
.build-cache/PathTests
codesign --verify --deep --strict 'Finder Address Bar.app'
plutil -lint Info.plist entitlements.plist
