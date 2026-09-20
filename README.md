# Finder Address Bar

A lightweight native macOS utility that adds a Windows-style address field over Finder’s folder-title area.

Click the current folder to edit its path, navigate through clickable breadcrumbs, or open Terminal in the current folder. The field uses Finder’s toolbar positions to fit between its navigation buttons and other controls.

## See it in action

https://github.com/user-attachments/assets/cd8eb267-39d4-40e5-b450-a1c2fd3660e1

Play the demo directly above, or [watch on YouTube](https://www.youtube.com/watch?v=-PFp8Z7WMU0).

> **Development preview:** this is a separate overlay, not an embedded Finder toolbar extension. It requires Accessibility and Automation permissions. Custom toolbar layouts and full-screen transitions may need further testing.

## Features

- Click-to-edit paths with a transparent, rounded input field—no pencil button.
- Clickable parent folders and subfolder menus.
- Folder suggestions, recent locations, and copy-path actions.
- Absolute and relative paths, `~`, `..`, quoted paths, and local file URLs.
- `terminal` / `cmd` commands and a dedicated Terminal button.
- File and application opening, web addresses, and SMB network addresses.
- Parent navigation, refresh, and opening a folder in a new Finder window.
- Drag files onto a breadcrumb to move them; hold Option to copy.
- Toolbar-aware sizing, menu-bar controls, and optional launch at login.

See the [usage guide](docs/USAGE.md) for shortcuts, aliases, behavior, and limitations.

## Requirements

- An Apple Silicon Mac (M1 or newer).
- macOS 13 Ventura or newer.
- Apple’s Command Line Tools or Xcode, with the Swift compiler.

The project uses AppKit, SwiftUI/Combine support, ServiceManagement, and macOS system APIs. It has no third-party package dependencies. It does not require an Xcode project or Swift package to build.

## Build and run

Clone this repository and enter its folder:

```sh
git clone https://github.com/sirnaeemasghar/macOS-finder-address-bar.git
cd macOS-finder-address-bar
```

Then run:

```sh
# Install Apple's development tools if they are not already installed:
xcode-select --install

# Build the locally signed Apple Silicon app:
./build.sh

# Run the checks:
./test.sh

# Launch:
open "Finder Address Bar.app"
```

Skip `xcode-select --install` if the tools are already installed. The generated app stays in the project folder and is excluded from Git. Keep it at a permanent location before enabling launch at login.

## First-run permissions

1. Open **System Settings → Privacy & Security → Accessibility**, add **Finder Address Bar.app**, and enable it. The app reads Finder’s toolbar geometry to avoid covering controls.
2. Allow **Finder Automation** when asked. This enables folder tracking and navigation.
3. Allow **Terminal Automation** when first using the Terminal button or `terminal` / `cmd`.
4. Open a normal folder in Finder. The bar hides if there is no Finder window, Finder’s toolbar is hidden, or accurate placement is unavailable.

The utility does not request Screen Recording or Full Disk Access. Recent paths stay in local app preferences. Submitted web/network addresses are handed to macOS; the app has no telemetry or network service.

### After rebuilding

The build script uses ad-hoc signing for local development. Rebuilding can invalidate Accessibility approval even if its switch still appears enabled. Remove the old entry and add the newly built app again **after the final build**. The menu icon’s tooltip and local `status.txt` help diagnose placement problems.

This repository does not provide a Developer ID-signed or notarized release. Do not treat the local build as a ready-to-distribute installer.

## Launch at login

Use **Launch at Login** in the menu-bar icon’s menu. The first run attempts registration with macOS; approval may be required in **General → Login Items & Extensions**. Before moving or deleting the app, disable its login item and quit it.

## Project layout

```text
Sources/                 Native application and path/layout logic
Tests/main.swift         Automated checks
Info.plist               Application metadata and permission explanation
entitlements.plist       Apple Events entitlement
build.sh                 Compile and locally sign the app
test.sh                 Run checks and validate the app bundle
docs/USAGE.md            Detailed usage and troubleshooting
docs/PUBLISHING.md       Create and publish your GitHub repository
CONTRIBUTING.md           Development and testing notes
CHANGELOG.md              Development-preview changes
```

## Validation and limitations

The current test suite has 39 checks for paths, quoting, suggestions, history, URL handling, and layout calculations. The test script also verifies the signature and property lists. Finder/Terminal permissions, actual file transfers, customized toolbar layouts, multi-display positioning, full-screen transitions, and login startup require manual testing.

Live testing confirmed folder tracking and automatic toolbar-fit mode after approving the app. This does not guarantee compatibility with every Finder layout. Keyboard shortcuts apply while the bar has focus; they are not global Finder shortcuts. Windows drive letters, `shell:` locations, Windows executables, and arbitrary shell-command execution are not supported.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Please include your macOS version, Mac model, reproduction steps, and whether the menu tooltip reports automatic toolbar fit. Remove personal paths from screenshots or logs before sharing them.

## License

Licensed under the [MIT License](LICENSE).
