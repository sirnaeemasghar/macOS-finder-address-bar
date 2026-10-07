# Finder Address Bar 1.2.0

Development preview for Apple Silicon Macs running macOS 13 or newer.

## What changed

- Removed the refresh and recent-locations toolbar buttons, keeping their spacing and the Terminal button in its original position.
- Fixed the white editing background in dark mode by resolving layer colors using the view’s effective appearance.
- Added light/dark fills and a softer, 3-point focus border based on Finder search-field reference screenshots.
- Kept the same interior color when viewing and editing a path.
- Removed the drop shadow so the bar looks flatter within Finder’s toolbar.

Toolbar alignment, width and height calculations, folder tracking, navigation, and Terminal behavior are unchanged. F4 still opens recent locations, F5 refreshes Finder, and Down Arrow opens suggestions while editing. Use Fn with F4/F5 if your keyboard uses media keys.

## Install or upgrade

Follow the [README](../README.md#build-and-run) for a first installation. For an existing clone, quit the running app, pull the latest main branch, run `./build.sh` and `./test.sh`, then open `Finder Address Bar.app`. Keep the app at its existing permanent location. If Accessibility approval stops working, remove and re-add the rebuilt app after the final build. Saved recent paths and preferences are retained.

## Validation

- The app builds successfully; all 57 existing automated checks pass.
- App signature and property-list validation pass.
- User feedback confirmed readable dark-mode editing and the focus-border styling on the development Mac.
- The final fill and shadow refinements still need broader visual testing. Automated checks do not verify rendered appearance.
- Custom toolbar layouts, multiple displays, and full-screen transitions require manual testing.

This is a locally ad-hoc-signed source release, not a notarized installer. The reference palette does not guarantee pixel-identical appearance across macOS versions or display settings.
