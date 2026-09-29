import AppKit
import Combine

final class BarModel: ObservableObject {
    @Published var folder: URL?
    @Published var message = "Connecting to Finder…"
    @Published var feedback = ""
    @Published var editing = false
    @Published var text = ""
    var finderWindowID: Int32 = 0
    func endEditing() {
        editing = false
        text = folder?.path ?? ""
    }
    func receiveFolder(_ url: URL?, windowID: Int32) {
        let changed = folder != url || finderWindowID != windowID
        folder = url
        finderWindowID = windowID
        if changed || !editing { endEditing() }
    }
    var navigate: ((URL) -> Void)?
    @Published var history = UserDefaults.standard.stringArray(forKey: "recentPaths") ?? []
    var refreshFolder: (() -> Void)?
    var newWindow: ((URL) -> Void)?
    var transfer: (([URL], URL, Bool) -> Void)?
    func remember(_ url: URL) {
        history = AddressFeatures.remember(url.path, history: history)
        UserDefaults.standard.set(history, forKey: "recentPaths")
    }
    func submit() {
        feedback = ""
        if PathLogic.isTerminal(text) { terminal(); return }
        if let url = AddressFeatures.externalURL(text) {
            if NSWorkspace.shared.open(url) { endEditing() }
            else { feedback = "Could not open that address." }
            return
        }
        do {
            let url: URL
            do { url = try AddressFeatures.localItem(text, current: folder) }
            catch {
                // App names, for example Safari, map to installed macOS apps.
                if !text.contains("/"), let app = AddressFeatures.application(text) {
                    url = app
                } else { throw error }
            }
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isApplicationKey])
            if values.isDirectory == true && values.isApplication != true { navigate?(url) }
            else if !NSWorkspace.shared.open(url) { throw Failure.message("Could not open \(url.lastPathComponent).") }
            endEditing()
        } catch { feedback = error.localizedDescription }
    }
    var openTerminal: (() -> Void)?
    func terminal() { openTerminal?() }

}

