# Finder Address Bar

Native AppKit address field for Apple Silicon Macs running macOS 13 or newer. The field overlays Finder’s folder-title area, between the navigation buttons and the next toolbar control. It is a companion window, not a Finder toolbar extension.

## Current behavior

- Pill-shaped field matching the navigation-button height (36–40 points); no pencil button. Click the current folder name or blank space to select and edit the full path. Click an ancestor to navigate there.
- Click a breadcrumb’s arrow to browse its subfolders. Long paths collapse earlier ancestors into an ellipsis menu while keeping the current folder visible.
- Type or paste an absolute/relative path, `~`, `..`, a quoted path, or a local `file://` URL, then press Return. Files and `.app` bundles open with macOS; folders navigate Finder.
- The editor has no separate box or bezel. Completion suggestions appear with Down Arrow while editing. Tab accepts the first suggestion. Escape cancels editing. Normal select/copy/cut/paste/undo operations work in the field.
- F4 opens a menu listing up to 30 distinct recently opened paths and provides Clear recent locations. History is stored locally in app preferences.
- Right-click for Copy address as text, Copy file URL, Paste and go, parent navigation, and Open in new Finder window.
- Type `terminal` or `cmd`, or press the Terminal button, to open a Terminal session in Finder’s current folder. No Windows shell is installed or emulated.
- Refresh is available with F5 while the bar is focused. The refresh and recent-locations toolbar buttons were removed in 1.2.0; the Terminal button remains.
- Supports `http://`, `https://`, `smb://`, `afp://`, and `ftp://` addresses through macOS. Windows UNC addresses such as `\\server\share` map to `smb://server/share`; mounting/authentication is handled by macOS.
- Location aliases: `home`, `desktop`, `documents`, `downloads`, `applications`, and `computer` (mounted volumes).
- Leading `$HOME`, `${HOME}`, `%HOME%`, `%USERPROFILE%`, `$TMPDIR`, and `%TEMP%` expand to their macOS equivalents. Literal dollar signs elsewhere in filenames are preserved.
- Installed apps can be opened by name when their bundle is in Applications, System Applications/Utilities, or the user’s Applications folder.
- Dropping files onto a named breadcrumb asks Finder to move them there; hold Option to copy. Finder handles collisions; the utility does not request replacement. Dropping a file/folder onto the blank field opens that location/item instead.

The interior fill stays consistent between viewing and editing in each theme. Editing adds a 3-point focus border using colors based on Finder search-field references. The bar has no drop shadow; its position and spacing remain unchanged. Exact visual matching can vary with macOS appearance and display settings.

## Keyboard shortcuts

These shortcuts apply while the address bar has focus, not globally while Finder owns keyboard focus:

| Shortcut | Action |
| --- | --- |
| Command-L / Control-L / Option-D | Select the editable address |
| F4 | Recent locations |
| F5 | Refresh Finder |
| Option-Up | Parent folder |
| Return | Open typed address |
| Escape | Cancel editing |
| Tab in editor | Accept first completion |
| Command-A/C/X/V/Z | Select/copy/cut/paste/undo |

On keyboards configured for media keys, hold Fn to send F4/F5.

## Position and permissions

Exact adaptive placement requires **System Settings → Privacy & Security → Accessibility → Finder Address Bar**. It reads the real navigation-button position and the first toolbar control to its right; the field fills that gap without a fixed width cap. The next control can change as you customize or resize the toolbar. The bar stays vertically centered on the navigation buttons.

Without working Accessibility approval, the overlay stays hidden rather than guessing and covering customized toolbar buttons. The menu icon remains available. The tooltip and status.txt identify the missing placement information. Placement follows Finder’s measured toolbar geometry.

Local ad-hoc signing changes the app’s identity when it is rebuilt. macOS may show an enabled Accessibility switch for a previously approved build while denying the current executable. After the final update, remove that entry, then add this exact app again and enable it. Do not rebuild again after approving it. A stable Developer ID signing setup would be needed to avoid this local-development issue reliably across updates.

Finder Automation is used to read the current folder, navigate, refresh, and perform explicitly requested drag/drop transfers. Terminal Automation is requested on first Terminal use. No Screen Recording or Full Disk Access permission is requested. The app does not access the network itself; web/network addresses are handed to macOS only when submitted.

The menu includes Show Address Bar / Retry Finder, permission/settings links, Launch at Login, and Quit. The bar hides while another app is active, when no Finder window is open, or when Finder’s toolbar is hidden. It supports joining other apps’ full-screen spaces.

## Startup and removal

Keep Finder Address Bar.app in a permanent location. The app requests login registration on first launch using SMAppService. A checkmark beside Launch at Login indicates it is enabled; use Open Login Items Settings if macOS requires approval.

Before moving the app, disable Launch at Login, quit, move it, reopen it, and enable login startup again. To remove it, disable login startup, quit, then move the app to Trash.

## Build and validation

Run `./build.sh`, then `./test.sh`. There are no third-party dependencies. Local ad-hoc signing is used; this is not a notarized distribution build.

57 automated checks cover path/command handling, special-character quoting, file/network addresses, aliases, suggestions, recent-path limits, and toolbar geometry. Geometry checks include dynamic expansion, customized controls, lack of room, full-screen top alignment, and negative coordinates on secondary displays. Bundle property lists and signature verification pass.

Live checks have confirmed the current folder breadcrumbs, the absence of the pencil, and clicking the current folder entering editing with the full path selected. Exact adaptive layout requires acceptance of the final build’s Accessibility identity. Treat full-screen/custom-toolbar alignment as pending until checked in automatic-fit mode. Terminal’s live session directory, actual drag/drop transfers, and login startup have not been end-to-end verified in this revision.

## Differences from Windows

Windows drive letters, `shell:` GUID namespaces, Control Panel paths, Windows executable commands/arguments, and Windows-specific environment directories have no direct macOS equivalent. The app does not run arbitrary typed shell expressions. Editing uses a transparent text field across the available bar area, with no separate rectangular input box. Finder’s own Back/Forward controls retain its navigation history. This overlay cannot insert a real toolbar item into Finder, reserve layout space, or provide native Finder tabs. New-window opening is supported. Completion/folder menus are capped to keep the UI manageable (100 suggestions / 200 subfolders per menu).

Research references:

- [Microsoft: keyboard shortcuts, including address selection and F4 history](https://support.microsoft.com/en-us/windows/keyboard-shortcuts-in-windows-dcc61a57-8ff0-cffe-9796-cb9706c75eec)
- [Microsoft: breadcrumb navigation](https://learn.microsoft.com/en-us/windows/apps/develop/ui/controls/breadcrumbbar)
- [Microsoft: selecting the address bar to display/copy the full path](https://support.microsoft.com/en-US/onedrive/what-are-file-path-length-limits)
- [Apple: NSComboBox](https://developer.apple.com/documentation/appkit/nscombobox)
- [Apple: login registration](https://developer.apple.com/documentation/servicemanagement/smappservice/register())
