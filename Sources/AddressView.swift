import AppKit
import SwiftUI

final class BarButton: NSButton {
    var invoke: (() -> Void)?
    var drop: (([URL], Bool) -> Void)?
    init(_ title: String, symbol: String? = nil, action: @escaping () -> Void) {
        super.init(frame: .zero)
        self.title = title
        if let symbol { image = NSImage(systemSymbolName: symbol, accessibilityDescription: title); imagePosition = .imageOnly }
        isBordered = false
        font = .systemFont(ofSize: 13, weight: .medium)
        contentTintColor = .secondaryLabelColor
        target = self; self.action = #selector(run); invoke = action
        registerForDraggedTypes([.fileURL])
        setAccessibilityLabel(title)
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc func run() { invoke?() }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard drop != nil else { return [] }
        return NSEvent.modifierFlags.contains(.option) ? .copy : .move
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty, let drop else { return false }
        drop(urls, NSEvent.modifierFlags.contains(.option)); return true
    }
}

struct BarView: NSViewRepresentable {
    @ObservedObject var model: BarModel
    func makeNSView(context: Context) -> AddressView { AddressView(model: model) }
    func updateNSView(_ view: AddressView, context: Context) { view.update() }
}

final class AddressView: NSView, NSTextFieldDelegate, NSMenuDelegate {
    static let shadowPadding: CGFloat = 12
    let backdrop = NSVisualEffectView()
    let tint = CALayer()
    let model: BarModel
    let combo = NSTextField()
    var elements: [NSView] = []
    var signature = ""
    var wasEditing = false
    var queued: DispatchWorkItem?
    var suggestionGeneration = 0
    var suggestions: [String] = []
    var pillRect: NSRect { bounds.insetBy(dx: Self.shadowPadding, dy: Self.shadowPadding) }
    init(model: BarModel) {
        self.model = model
        super.init(frame: NSRect(x: 0, y: 0, width: 350, height: 32))
        wantsLayer = true
        layer?.masksToBounds = false
        backdrop.material = .popover
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdrop.wantsLayer = true
        backdrop.layer?.masksToBounds = true
        backdrop.layer?.addSublayer(tint)
        addSubview(backdrop)
        combo.delegate = self
        combo.isEditable = true
        combo.font = .systemFont(ofSize: 13, weight: .medium)
        combo.textColor = .labelColor
        combo.usesSingleLineMode = true
        combo.drawsBackground = false
        combo.isBezeled = false
        combo.isSelectable = true
        combo.cell?.isScrollable = true
        combo.isBordered = false
        combo.focusRingType = .none
        combo.target = self; combo.action = #selector(submit)
        combo.setAccessibilityLabel("Folder address")
        registerForDraggedTypes([.fileURL, .string])
        update()
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    // Shared fill keeps viewing and editing consistent with Finder's search field.
    private func barFill(dark: Bool) -> NSColor {
        dark ? NSColor(srgbRed: 33 / 255, green: 37 / 255, blue: 37 / 255, alpha: 1)
             : NSColor(srgbRed: 250 / 255, green: 250 / 255, blue: 250 / 255, alpha: 1)
    }
    private func editingRing(dark: Bool) -> NSColor {
        dark ? NSColor(srgbRed: 72 / 255, green: 123 / 255, blue: 160 / 255, alpha: 1)
             : NSColor(srgbRed: 162 / 255, green: 191 / 255, blue: 245 / 255, alpha: 1)
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); updateBackdrop(); needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let pill = pillRect
        guard pill.width > 0, pill.height > 0 else { return }
        let radius = pill.height / 2
        let pillPath = NSBezierPath(roundedRect: pill, xRadius: radius, yRadius: radius)

        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua

        // Flat fill blends into Finder's toolbar without a floating drop shadow.
        let fillColor = barFill(dark: isDark)
        fillColor.setFill()
        pillPath.fill()

        // Native subtle border
        let strokeColor: NSColor
        if model.editing {
            strokeColor = editingRing(dark: isDark)
        } else if isDark {
            strokeColor = NSColor(white: 1.0, alpha: 0.16)
        } else {
            strokeColor = NSColor(white: 0.0, alpha: 0.12)
        }
        strokeColor.setStroke()
        if model.editing {
            // Draw the focus ring outside the pill without moving or resizing it.
            let focusPath = NSBezierPath(roundedRect: pill.insetBy(dx: -1.5, dy: -1.5), xRadius: radius + 1.5, yRadius: radius + 1.5)
            focusPath.lineWidth = 3
            focusPath.stroke()
        } else {
            pillPath.lineWidth = 0.75
            pillPath.stroke()
        }
    }
    func updateBackdrop() {
        let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        // Layer colors are fixed CGColors; resolve them using this view's appearance,
        // including when editing or changing themes outside a drawing callback.
        effectiveAppearance.performAsCurrentDrawingAppearance {
            tint.backgroundColor = barFill(dark: dark).cgColor
            backdrop.layer?.borderWidth = model.editing ? 0 : 0.75
            backdrop.layer?.borderColor = NSColor.white.withAlphaComponent(dark ? 0.16 : 0.85).cgColor
        }
    }
    func edit() {
        model.text = model.folder?.path ?? ""
        model.editing = true
        update()
    }
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if pillRect.contains(point) { edit() }
    }
    func update() {
        let key = "\(model.folder?.path ?? "")|\(model.editing)|\(Int(bounds.width))|\(Int(bounds.height))|\(model.feedback)|\(model.message)"
        guard signature != key else { return }
        signature = key
        // Keep the active field attached during layout/feedback updates.
        if !model.editing && wasEditing { window?.makeFirstResponder(self) }
        for item in elements where item !== combo || !model.editing { item.removeFromSuperview() }
        elements = []
        let pill = pillRect
        func place(_ item: NSView, x: CGFloat, width: CGFloat) {
            // A text field draws at the top of its frame; use its native line height
            // so the editing baseline stays centered like the breadcrumb buttons.
            let height: CGFloat = item === combo ? ceil(combo.cell?.cellSize.height ?? 17) : 22
            item.frame = NSRect(x: x, y: pill.midY - height / 2, width: width, height: height)
            if item.superview == nil { addSubview(item) }
            elements.append(item)
        }
        var right = pill.maxX - 5
        let terminal = BarButton("Open Terminal here", symbol: "terminal") { [weak self] in self?.model.terminal() }
        terminal.isEnabled = model.folder != nil
        right -= 23; place(terminal, x: right, width: 23)
        // Preserve the existing path layout with the two toolbar buttons removed.
        right -= 19
        if pill.width >= 230 && !model.editing {
            right -= 21
        }
        if !model.feedback.isEmpty {
            let error = BarButton("Show error", symbol: "exclamationmark.circle") { [weak self] in
                guard let self else { return }; let alert = NSAlert(); alert.messageText = "Address bar"; alert.informativeText = self.model.feedback; alert.runModal()
            }
            error.toolTip = model.feedback; right -= 20; place(error, x: right, width: 20)
        }
        if model.editing {
            place(combo, x: pill.minX + 12, width: max(30, right - (pill.minX + 18)))
            if !wasEditing {
                combo.stringValue = model.text
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.model.editing else { return }
                    self.window?.makeKey()
                    self.combo.selectText(nil)
                    self.loadSuggestions()
                }
            }
        } else {
            var parts = model.folder.map(PathLogic.ancestors) ?? []
            let maxWidth = max(20, right - (pill.minX + 14))
            func width(_ url: URL) -> CGFloat {
                min(180, max(25, (name(url) as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium)]).width + 8)) + 17
            }
            var hidden: [URL] = []
            while parts.count > 1 && parts.reduce(CGFloat(0), { $0 + width($1) }) + (hidden.isEmpty ? 0 : 22) > maxWidth {
                hidden.append(parts.removeFirst())
            }
            var x: CGFloat = pill.minX + 12
            if !hidden.isEmpty && maxWidth > 75 {
                let saved = hidden
                let more = BarButton("…") { [weak self] in self?.locationsMenu(saved, title: "Parent folders") }
                place(more, x: x, width: 22); x += 22
            }
            for part in parts {
                let available = right - x - 3
                guard available > 10 else { break }
                let isCurrent = part.path == model.folder?.path
                let label = BarButton(name(part)) { [weak self] in
                    if isCurrent { self?.edit() } else { self?.model.navigate?(part) }
                }
                label.contentTintColor = isCurrent ? .labelColor : .secondaryLabelColor
                label.lineBreakMode = .byTruncatingMiddle
                label.toolTip = part.path + (isCurrent ? " — click to edit" : "")
                label.drop = { [weak self] urls, copy in self?.model.transfer?(urls, part, copy) }
                label.menu = contextMenu(for: part)
                let labelWidth = min(width(part) - 17, max(20, available - 17))
                place(label, x: x, width: labelWidth); x += labelWidth
                if right - x >= 17 {
                    let children = BarButton("Folders in " + name(part), symbol: "chevron.right") { [weak self] in self?.childrenMenu(part) }
                    place(children, x: x, width: 17); x += 17
                }
            }
            if parts.isEmpty {
                let label = BarButton("Enter folder path") { [weak self] in self?.edit() }
                label.toolTip = model.message
                place(label, x: pill.minX + 12, width: maxWidth)
            }
        }
        wasEditing = model.editing
        updateBackdrop()
        needsDisplay = true
    }
    override func layout() {
        super.layout()
        backdrop.frame = pillRect
        backdrop.layer?.cornerRadius = pillRect.height / 2
        tint.frame = backdrop.bounds
        updateBackdrop()
        update()
    }
    func name(_ url: URL) -> String { url.path == "/" ? "/" : url.lastPathComponent }
    @objc func submit() { model.text = combo.stringValue; model.submit() }
    func controlTextDidEndEditing(_ notification: Notification) {
        // AppKit can end an editing session while handing off to the field editor.
        // Only discard the draft if focus really left the field after that handoff.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.model.editing else { return }
            if self.combo.currentEditor() == nil { self.model.endEditing() }
        }
    }
    func controlTextDidChange(_ obj: Notification) { model.text = combo.stringValue; loadSuggestions() }
    func loadSuggestions() {
        queued?.cancel(); suggestionGeneration += 1
        let generation = suggestionGeneration
        let input = combo.stringValue; let current = model.folder; let history = model.history
        let item = DispatchWorkItem { [weak self] in
            let values = AddressFeatures.suggestions(input, current: current, history: history)
            DispatchQueue.main.async {
                guard let self, generation == self.suggestionGeneration, self.model.editing else { return }
                self.suggestions = values
                // Suggestions stay in the bar menu, not a boxed combo control.
            }
        }
        queued = item
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.15, execute: item)
    }
    func controlTextDidBeginEditing(_ notification: Notification) {
        if let editor = combo.currentEditor() as? NSTextView {
            editor.drawsBackground = false
            editor.backgroundColor = .clear
        }
    }
    func showChoices() {
        if model.editing && !suggestions.isEmpty {
            let menu = NSMenu()
            for path in suggestions { menu.addItem(item(path, "complete", value: path)) }
            popup(menu)
        } else { historyMenu() }
    }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.cancelOperation(_:)) { model.endEditing(); window?.makeFirstResponder(self); return true }
        if selector == #selector(NSResponder.insertNewline(_:)) { submit(); return true }
        if selector == #selector(NSResponder.moveDown(_:)) { showChoices(); return true }
        if selector == #selector(NSResponder.insertTab(_:)), let value = suggestions.first {
            combo.stringValue = value; model.text = value; textView.string = value
            textView.setSelectedRange(NSRange(location: value.utf16.count, length: 0)); loadSuggestions(); return true
        }
        return false
    }
    func handleShortcut(_ event: NSEvent) -> Bool {
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if (key == "l" && (flags.contains(.command) || flags.contains(.control))) || (key == "d" && flags.contains(.option)) { edit(); return true }
        if event.keyCode == 118 { historyMenu(); return true } // F4
        if event.keyCode == 96 { model.refreshFolder?(); return true } // F5
        if event.keyCode == 126 && flags.contains(.option), let folder = model.folder { model.navigate?(folder.deletingLastPathComponent()); return true }
        return false
    }
    func popup(_ menu: NSMenu) { menu.popUp(positioning: nil, at: NSPoint(x: pillRect.minX, y: pillRect.maxY), in: self) }
    func item(_ title: String, _ command: String, value: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(menuAction(_:)), keyEquivalent: "")
        item.target = self; item.representedObject = ["command": command, "value": value ?? ""]
        return item
    }
    func historyMenu() {
        let menu = NSMenu()
        menu.addItem(item("Edit address", "edit"))
        for path in model.history { menu.addItem(item(path, "navigate", value: path)) }
        menu.addItem(.separator()); menu.addItem(item("Clear recent locations", "clear"))
        popup(menu)
    }
    func locationsMenu(_ urls: [URL], title: String) {
        let menu = NSMenu(title: title)
        for url in urls { menu.addItem(item(url.path, "navigate", value: url.path)) }
        popup(menu)
    }
    func childrenMenu(_ parent: URL) {
        // Fetch outside the UI thread; a slow mounted disk must not freeze the bar.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let children = Array(AddressFeatures.directories(parent).prefix(200))
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let menu = NSMenu()
                menu.addItem(self.item("Open " + self.name(parent), "navigate", value: parent.path))
                menu.addItem(.separator())
                for url in children { menu.addItem(self.item(self.name(url), "navigate", value: url.path)) }
                if children.isEmpty { let empty = NSMenuItem(title: "No accessible subfolders", action: nil, keyEquivalent: ""); menu.addItem(empty) }
                self.popup(menu)
            }
        }
    }
    func contextMenu(for folder: URL?) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item("Edit address", "edit"))
        if let folder {
            menu.addItem(item("Copy address as text", "copy", value: folder.path))
            menu.addItem(item("Copy file URL", "copy", value: folder.absoluteString))
            menu.addItem(item("Open in new Finder window", "new", value: folder.path))
            menu.addItem(item("Go to parent folder", "navigate", value: folder.deletingLastPathComponent().path))
        }
        menu.addItem(item("Paste and go", "paste")); menu.addItem(item("Open Terminal here", "terminal"))
        return menu
    }
    override func menu(for event: NSEvent) -> NSMenu? { contextMenu(for: model.folder) }
    @objc func menuAction(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: String] else { return }
        let value = info["value"] ?? ""
        switch info["command"] {
        case "edit": edit()
        case "complete":
            combo.stringValue = value; model.text = value
            window?.makeFirstResponder(combo)
            if let editor = combo.currentEditor() as? NSTextView { editor.string = value; editor.setSelectedRange(NSRange(location: value.utf16.count, length: 0)) }
            loadSuggestions()
        case "copy": NSPasteboard.general.clearContents(); NSPasteboard.general.setString(value, forType: .string)
        case "navigate": model.navigate?(URL(fileURLWithPath: value))
        case "new": model.newWindow?(URL(fileURLWithPath: value))
        case "paste": model.text = NSPasteboard.general.string(forType: .string) ?? ""; model.submit()
        case "terminal": model.terminal()
        case "clear": model.history = []; UserDefaults.standard.removeObject(forKey: "recentPaths")
        default: break
        }
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .link }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], let url = urls.first {
            model.text = url.path; model.submit(); return true
        }
        if let text = sender.draggingPasteboard.string(forType: .string) { model.text = text; model.submit(); return true }
        return false
    }
}
