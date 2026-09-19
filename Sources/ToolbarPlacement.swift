import AppKit
import ApplicationServices

// Read only Finder's toolbar geometry. Never change Finder's accessibility tree.
enum ToolbarPlacement {
    static func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
        return value
    }
    static func children(_ element: AXUIElement) -> [AXUIElement] {
        attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }
    static func string(_ element: AXUIElement, _ key: String) -> String {
        attribute(element, key) as? String ?? ""
    }
    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let p = attribute(element, kAXPositionAttribute), let s = attribute(element, kAXSizeAttribute),
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }
    static func descendants(_ element: AXUIElement, depth: Int = 0) -> [AXUIElement] {
        guard depth < 5 else { return [] }
        return children(element).flatMap { [$0] + descendants($0, depth: depth + 1) }
    }
    // WindowServer bounds remain correct when Finder's AppleScript bounds include
    // an obsolete menu-bar offset during entry to full-screen.
    static func visibleWindowBounds() -> CGRect? {
        guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        for window in windows {
            guard (window[kCGWindowOwnerPID as String] as? Int) == Int(finder.processIdentifier),
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let dictionary = window[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: dictionary as CFDictionary), rect.width > 200, rect.height > 100 else { continue }
            return rect
        }
        return nil
    }
    static var reason = "Waiting for Finder"
    static func current() -> CGRect? {
        reason = "Accessibility permission is missing"
        guard AXIsProcessTrusted(), let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first else { return nil }
        reason = "Finder window is unavailable"
        let app = AXUIElementCreateApplication(finder.processIdentifier)
        guard let raw = attribute(app, kAXMainWindowAttribute) ?? attribute(app, kAXFocusedWindowAttribute) ?? (attribute(app, kAXWindowsAttribute) as? [AXUIElement])?.first,
              CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        let window = raw as! AXUIElement
        reason = "Finder toolbar is unavailable"
        guard let toolbar = descendants(window).first(where: { string($0, kAXRoleAttribute) == kAXToolbarRole }) else { return nil }
        let elements = descendants(toolbar)
        reason = "Finder navigation buttons are unavailable"
        let back = elements.filter {
            let names = [string($0, kAXDescriptionAttribute), string($0, kAXTitleAttribute)].map { $0.lowercased() }
            return names.contains { ["back", "forward", "back/forward"].contains($0) }
        }.compactMap(frame)
        guard let end = back.map(\.maxX).max(), let anchor = back.first else { return nil }
        let navigation = CGRect(x: back.map(\.minX).min() ?? anchor.minX, y: anchor.minY, width: end - (back.map(\.minX).min() ?? anchor.minX), height: anchor.height)
        let controls = elements.filter {
            [kAXButtonRole, kAXMenuButtonRole, kAXPopUpButtonRole, kAXRadioButtonRole, kAXTextFieldRole, kAXCheckBoxRole].contains(string($0, kAXRoleAttribute))
        }.compactMap(frame)
        reason = "Not enough space in Finder toolbar"
        guard let toolbarFrame = frame(toolbar), let slot = BarGeometry.slot(navigation: navigation, controls: controls, toolbar: toolbarFrame) else { return nil }
        reason = "Visible"
        return slot
    }
}
