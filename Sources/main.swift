import AppKit
import SwiftUI
import ServiceManagement
import ApplicationServices
import Combine

final class Panel: NSPanel {
    var shortcut: ((NSEvent) -> Bool)?
    // Finder supplies the position, including the hidden menu-bar area in full screen.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
    override var canBecomeKey: Bool { true }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if shortcut?(event) == true { return true }
        if event.modifierFlags.contains(.command), let editor = firstResponder as? NSTextView {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "a": editor.selectAll(nil); return true
            case "c": editor.copy(nil); return true
            case "x": editor.cut(nil); return true
            case "v": editor.paste(nil); return true
            case "z": if event.modifierFlags.contains(.shift) { editor.undoManager?.redo() } else { editor.undoManager?.undo() }; return true
            default: break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = BarModel()
    var panel: Panel!
    var status: NSStatusItem!
    var timer: Timer?
    var placementTimer: Timer?
    var observation: AnyCancellable?
    let queue = DispatchQueue(label: "FinderAddressBar.automation")
    var pendingScripts = 0
    var busy: Bool { pendingScripts > 0 }
    var denied = false
    var finderToolbarVisible = false
    var loginItem: NSMenuItem!
    var lastDiagnostic = ""
    func diagnostic(_ text: String) {
        guard text != lastDiagnostic else { return }
        lastDiagnostic = text
        let url = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("status.txt")
        var lines = ((try? String(contentsOf: url, encoding: .utf8)) ?? "").split(separator: "\n").suffix(19).map(String.init)
        lines.append("\(Date()) \(text)")
        try? (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        status.button?.toolTip = text
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = Panel(contentRect: NSRect(x: 200, y: 400, width: 720, height: 32), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.delegate = self
        panel.animationBehavior = .none
        panel.title = "Finder Address Bar"
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.hasShadow = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle, .canJoinAllApplications]
        let addressView = AddressView(model: model)
        panel.contentView = addressView
        panel.shortcut = { [weak addressView] event in addressView?.handleShortcut(event) ?? false }
        observation = model.objectWillChange.sink { [weak addressView] in
            DispatchQueue.main.async { addressView?.update() }
        }
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.image = NSImage(systemSymbolName: "folder.badge.gearshape", accessibilityDescription: "Finder Address Bar")
        let menu = NSMenu()
        add(menu, "Show Address Bar / Retry Finder", #selector(show))
        loginItem = add(menu, "Launch at Login", #selector(toggleLogin))
        add(menu, "Open Login Items Settings", #selector(loginSettings))
        add(menu, "Open Automation Settings", #selector(automationSettings))
        add(menu, "Enable Precise Toolbar Position", #selector(enablePlacement))
        menu.addItem(.separator())
        add(menu, "Quit Finder Address Bar", #selector(quit))
        status.menu = menu
        model.navigate = { [weak self] url in self?.navigate(url) }
        model.openTerminal = { [weak self] in self?.openTerminal() }
        model.refreshFolder = { [weak self] in self?.refreshFinder() }
        model.newWindow = { [weak self] url in self?.newFinderWindow(url) }
        model.transfer = { [weak self] urls, destination, copy in self?.transfer(urls, to: destination, copy: copy) }
        if !UserDefaults.standard.bool(forKey: "loginConfigured") {
            do { try SMAppService.mainApp.register(); UserDefaults.standard.set(true, forKey: "loginConfigured") }
            catch { model.message = "Enable Launch at Login from the menu after moving the app to a permanent location." }
        }
        updateLogin()
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer!, forMode: .common)
        placementTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.positionPanel() }
        RunLoop.main.add(placementTimer!, forMode: .common)
        refresh()
    }
    func windowDidResignKey(_ notification: Notification) { model.endEditing(); refresh() }
    func positionPanel() {
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard front == "com.apple.finder" || front == Bundle.main.bundleIdentifier else {
            model.endEditing(); panel.orderOut(nil); return
        }
        guard finderToolbarVisible else { panel.orderOut(nil); return }
        guard let primary = NSScreen.screens.first, let slot = ToolbarPlacement.current() else {
            panel.orderOut(nil); diagnostic("Toolbar placement unavailable: " + ToolbarPlacement.reason); return
        }

        let pad = AddressView.shadowPadding
        let frame = NSRect(
            x: slot.minX - pad,
            y: (primary.frame.maxY - slot.maxY) - pad,
            width: slot.width + pad * 2,
            height: slot.height + pad * 2
        )
        if panel.frame != frame { panel.setFrame(frame, display: true, animate: false) }
        if !panel.isVisible { panel.orderFrontRegardless() }
        diagnostic("Visible: \(ToolbarPlacement.debugInfo) requestedY:\(Int(frame.minY)) actualY:\(Int(panel.frame.minY))")
    }
    @discardableResult func add(_ menu: NSMenu, _ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self; menu.addItem(item); return item
    }
    func updateLogin() {
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        loginItem.title = SMAppService.mainApp.status == .requiresApproval ? "Launch at Login (approval needed)" : "Launch at Login"
    }
    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
            UserDefaults.standard.set(true, forKey: "loginConfigured")
            if SMAppService.mainApp.status == .requiresApproval { loginSettings() }
        } catch { model.message = "Login setting: \(error.localizedDescription)"; panel.orderFrontRegardless() }
        updateLogin()
    }
    @objc func loginSettings() { SMAppService.openSystemSettingsLoginItems() }
    @objc func automationSettings() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!) }
    @objc func enablePlacement() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func show() { denied = false; panel.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); refresh() }
    func script(_ source: String, timeout: Int = 3, completion: @escaping (NSAppleEventDescriptor?, NSDictionary?) -> Void) {
        pendingScripts += 1
        queue.async {
            var error: NSDictionary?
            let value = NSAppleScript(source: "with timeout of \(timeout) seconds\n" + source + "\nend timeout")?.executeAndReturnError(&error)
            DispatchQueue.main.async { self.pendingScripts -= 1; completion(value, error) }
        }
    }
    func navigate(_ url: URL) {
        model.endEditing()
        model.feedback = ""
        script("tell application \"Finder\"\nset destination to POSIX file \(PathLogic.appleString(url.path)) as alias\nif (count of Finder windows) is 0 then\nmake new Finder window to destination\nelse\nset target of front Finder window to destination\nend if\nactivate\nend tell") { _, error in
            if let error { self.model.feedback = self.errorText(error) }
            else { self.model.remember(url); self.refresh() }
        }
    }
    func refreshFinder() {
        script("tell application \"Finder\"\nif (count of Finder windows) > 0 then\nupdate (target of front Finder window)\nend if\nend tell") { _, error in
            if let error { self.model.feedback = self.errorText(error) }
            else { self.model.feedback = ""; self.refresh() }
        }
    }
    func newFinderWindow(_ url: URL) {
        script("tell application \"Finder\"\nmake new Finder window to (POSIX file \(PathLogic.appleString(url.path)) as alias)\nactivate\nend tell") { _, error in
            if let error { self.model.feedback = self.errorText(error) }
        }
    }
    func transfer(_ urls: [URL], to destination: URL, copy: Bool) {
        let operation = copy ? "duplicate" : "move"
        // Finder handles collision dialogs; never request replacement or delete originals ourselves.
        let items = urls.map { "(POSIX file " + PathLogic.appleString($0.path) + " as alias)" }.joined(separator: ", ")
        script("tell application \"Finder\"\n\(operation) {\(items)} to (POSIX file \(PathLogic.appleString(destination.path)) as alias)\nend tell", timeout: 120) { _, error in
            if let error { self.model.feedback = self.errorText(error) }
            else { self.model.feedback = "" }
        }
    }
    func openTerminal() {
        model.feedback = ""
        // Read Finder again at invocation so the command uses the current tab.
        script("""
        tell application "Finder"
            if (count of Finder windows) is 0 then error "Open a Finder folder first."
            set folderPath to POSIX path of (target of front Finder window as alias)
        end tell
        tell application "Terminal"
            do script "cd -- " & quoted form of folderPath
            activate
        end tell
        """, timeout: 30) { _, error in
            if let error {
                let message: String
                if (error[NSAppleScript.errorNumber] as? Int) == -1743 {
                    message = "Allow Finder and Terminal under System Settings → Privacy & Security → Automation → Finder Address Bar, then try again."
                } else {
                    message = error[NSAppleScript.errorMessage] as? String ?? "Terminal could not be opened."
                }
                self.model.feedback = message
                let alert = NSAlert()
                alert.messageText = "Could not open Terminal"
                alert.informativeText = message
                alert.runModal()
            } else { self.model.endEditing() }
        }
    }
    func errorText(_ error: NSDictionary) -> String {
        if (error[NSAppleScript.errorNumber] as? Int) == -1743 {
            denied = true
            return "Allow Finder in System Settings → Privacy & Security → Automation, then choose Retry Finder in the menu."
        }
        return error[NSAppleScript.errorMessage] as? String ?? "Finder could not be read."
    }
    func refresh() {
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard front == "com.apple.finder" || front == Bundle.main.bundleIdentifier else { panel.orderOut(nil); diagnostic("Hidden while another app is active: \(front ?? "unknown")"); return }
        guard !busy, !denied else { return }
        script("""
        tell application "Finder"
            if (count of Finder windows) is 0 then return {"", 0, 0, 0, 0, 0, false, 0}
            set b to bounds of front Finder window
            try
                set p to POSIX path of (target of front Finder window as alias)
            on error
                set p to ""
            end try
            return {p, item 1 of b, item 2 of b, item 3 of b, item 4 of b, sidebar width of front Finder window, toolbar visible of front Finder window, id of front Finder window}
        end tell
        """) { value, error in
            if let error {
                // A transient Finder timeout is not a navigation or focus change.
                // Keep the last known folder and active draft; retry on the next poll.
                self.model.message = self.errorText(error)
                self.diagnostic(self.model.message)
                if self.denied { self.finderToolbarVisible = false; self.panel.orderOut(nil) }
                return
            }
            guard let value, value.numberOfItems == 8 else { return }
            self.finderToolbarVisible = value.atIndex(7)?.booleanValue == true && value.atIndex(8)?.int32Value != 0
            let path = value.atIndex(1)?.stringValue ?? ""
            self.model.receiveFolder(path.isEmpty ? nil : URL(fileURLWithPath: path).standardizedFileURL, windowID: value.atIndex(8)?.int32Value ?? 0)
            self.model.message = path.isEmpty ? "Open a regular folder. Recents and search views have no directory path." : ""
            self.positionPanel()
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
