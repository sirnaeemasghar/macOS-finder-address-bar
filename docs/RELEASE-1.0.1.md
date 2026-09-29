# Finder Address Bar 1.0.1

Development preview for Apple Silicon Macs running macOS 13 or newer.

## What changed

- Fixed the downward shift in full screen by allowing the overlay to use Finder’s measured toolbar position.
- Refined the bar height and soft shadow to better match neighboring toolbar controls.
- Added a frosted, tinted background that obscures Finder’s folder title.
- Updated breadcrumb typography and vertically centered the editable path field.
- Improved folder tracking and draft handling when changing Finder windows.

## Build and upgrade

Build with `./build.sh`, validate with `./test.sh`, then open `Finder Address Bar.app`. Quit any running copy before launching the new build. If the bar does not appear, remove and re-add the rebuilt app under System Settings → Privacy & Security → Accessibility.

## Validation

- 57 automated checks passed.
- App signature and property-list validation passed.
- Full-screen position, background, and sizing were confirmed through user testing on the development Mac.
- Multi-display layouts and customized Finder toolbars still need broader manual testing.

This is an ad-hoc-signed development preview, not a notarized installer. Source builds require Apple’s Command Line Tools or Xcode.
