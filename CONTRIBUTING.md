# Contributing

This project is a development preview. Discuss larger changes in an issue before implementing them. Review the repository's licensing status before redistributing code.

## Develop

1. Use an Apple Silicon Mac with macOS 13+ and Apple's development tools.
2. Read `Sources/main.swift` for application behavior, `AddressView.swift` for the UI, and `ToolbarPlacement.swift` / `BarGeometry.swift` for placement.
3. Run `./build.sh`, then `./test.sh`.
4. Quit any old instance before launching the rebuilt app. Refresh Accessibility approval if macOS no longer trusts the new build.

Do not change the running app's signing identity or rebuild it merely to edit documentation. This can invalidate its existing permissions. Do not commit generated apps, build caches, local logs, signing certificates, or screenshots containing personal information.

## Manual checks

- Tracking works when Finder changes folders or front windows.
- Clicking the current folder or empty space selects the editable path.
- Return navigates and Escape cancels; quoted paths and names with spaces work.
- Parent breadcrumbs, subfolder menus, suggestions, history, and copy-path actions work.
- The bar does not overlap customized toolbar controls at narrow or wide window sizes.
- Normal, maximized, full-screen, and multi-display placement remain aligned.
- `terminal` / `cmd` opens Terminal in the expected folder; check `pwd` manually.
- Test drag/drop with disposable files only, including a name collision; existing data must not be silently overwritten.
- Login registration and disabling the login item behave correctly.

Keep changes focused, add meaningful tests for path/layout behavior, and describe validation in the pull request. Never commit a workaround that bypasses macOS privacy permissions.
