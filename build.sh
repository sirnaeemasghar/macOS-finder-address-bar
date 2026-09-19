#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP="$PWD/Finder Address Bar.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$PWD/.build-cache"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx13.0 -module-cache-path "$PWD/.build-cache" Sources/PathLogic.swift Sources/BarGeometry.swift Sources/AddressFeatures.swift Sources/AddressView.swift Sources/ToolbarPlacement.swift Sources/main.swift -o "$APP/Contents/MacOS/FinderAddressBar" -framework AppKit -framework SwiftUI -framework ServiceManagement
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - --options runtime --entitlements entitlements.plist "$APP"
echo "Built: $APP"
