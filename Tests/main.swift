import Foundation
import CoreGraphics

var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    guard condition() else { fatalError("FAIL: \(name)") }
    checks += 1
}
let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
let tricky = root.appendingPathComponent("space ' quote \" dollar $ backtick ` slash \\ 雪")
try FileManager.default.createDirectory(at: tricky, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }
let absolute = try PathLogic.resolve(tricky.path, current: nil)
check(absolute == tricky.standardizedFileURL, "literal special characters")
let relative = try PathLogic.resolve(tricky.lastPathComponent, current: root)
check(relative == tricky.standardizedFileURL, "relative path")
let fileURL = try PathLogic.resolve(tricky.absoluteString, current: nil)
check(fileURL.path == tricky.standardizedFileURL.path, "encoded file URL")
let parent = try PathLogic.resolve("..", current: tricky)
check(parent == root.standardizedFileURL, "parent path")
let home = try PathLogic.resolve("~", current: nil)
check(home.path == NSHomeDirectory(), "home expansion")
check(PathLogic.isTerminal(" CMD \n"), "cmd command")
check(PathLogic.isTerminal("terminal"), "terminal command")
check(!PathLogic.isTerminal("terminal; touch /tmp/x"), "no shell execution")
check(PathLogic.ancestors(tricky).first?.path == "/", "root breadcrumb")
check(PathLogic.ancestors(tricky).last == tricky.standardizedFileURL, "current breadcrumb")
check(PathLogic.ancestors(URL(fileURLWithPath: "/")).count == 1, "root terminates")
for invalid in ["", "/not-a-real-folder-12345", "file://remote/tmp"] {
    do { _ = try PathLogic.resolve(invalid, current: nil); fatalError("Accepted invalid path") }
    catch { checks += 1 }
}
let file = root.appendingPathComponent("file.txt")
try Data().write(to: file)
do { _ = try PathLogic.resolve(file.path, current: nil); fatalError("Accepted file") }
catch { checks += 1 }
var scriptError: NSDictionary?
let returned = NSAppleScript(source: "return \(PathLogic.appleString(tricky.path))")!.executeAndReturnError(&scriptError)
check(scriptError == nil && returned.stringValue == tricky.path, "AppleScript string round trip")
let commandScript = NSAppleScript(source: "return \"cd -- \" & quoted form of " + PathLogic.appleString(tricky.path))!
let command = commandScript.executeAndReturnError(&scriptError).stringValue!
check(scriptError == nil, "Terminal command constructs successfully")
let process = Process()
let pipe = Pipe()
process.executableURL = URL(fileURLWithPath: "/bin/zsh")
process.arguments = ["-c", command + " && /bin/pwd"]
process.standardOutput = pipe
try process.run()
process.waitUntilExit()
let actual = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!.trimmingCharacters(in: .newlines)
check(process.terminationStatus == 0 && URL(fileURLWithPath: actual).resolvingSymlinksInPath().path == tricky.resolvingSymlinksInPath().path, "Terminal cd preserves special characters")
check(AddressFeatures.expand("%USERPROFILE%/Documents") == NSHomeDirectory() + "/Documents", "Windows home alias")
check(AddressFeatures.expand("$HOME/Documents") == NSHomeDirectory() + "/Documents", "leading environment variable")
check(AddressFeatures.expand("/tmp/literal$HOME") == "/tmp/literal$HOME", "literal internal variable")
check(AddressFeatures.expand("\"/tmp/space name\"") == "/tmp/space name", "quoted path")
check(AddressFeatures.expand("downloads") == NSHomeDirectory() + "/Downloads", "named location")
check(AddressFeatures.externalURL("https://example.com/a")?.scheme == "https", "web URL")
check(AddressFeatures.externalURL("smb://server/share")?.scheme == "smb", "network URL")
check(AddressFeatures.externalURL("\\\\server\\share")?.absoluteString == "smb://server/share", "UNC maps to SMB")
check(AddressFeatures.externalURL("javascript:alert(1)") == nil, "unsupported URL rejected")
let literalFile = try AddressFeatures.localItem(file.path, current: nil)
check(literalFile.path == file.path, "typed file supported")
let typedFolder = try AddressFeatures.localItem(tricky.path, current: nil)
check(typedFolder.path == tricky.path, "special characters preserved")
let suggested = AddressFeatures.suggestions(root.path + "/spa", current: nil, history: [])
check(suggested.contains { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path == tricky.resolvingSymlinksInPath().path }, "folder completion")
check(AddressFeatures.remember("/a", history: ["/b", "/a"]) == ["/a", "/b"], "recent paths deduplicated")
check(AddressFeatures.remember("/new", history: (0..<40).map { "/\($0)" }).count == 30, "history bounded")
let toolbar = CGRect(x: 200, y: 100, width: 1000, height: 52)
let nav = CGRect(x: 400, y: 110, width: 72, height: 32)
let smallSlot = BarGeometry.slot(navigation: nav, controls: [CGRect(x: 700, y: 110, width: 40, height: 32)], toolbar: toolbar)!
check(smallSlot.minX == 480 && smallSlot.maxX == 692, "field fits available toolbar gap")
check(smallSlot.height == nav.height - 2, "visible height excludes navigation hit-area padding")
check(smallSlot.midY == nav.midY, "vertical alignment follows buttons")
let wideSlot = BarGeometry.slot(navigation: nav, controls: [CGRect(x: 1100, y: 110, width: 40, height: 32)], toolbar: toolbar)!
check(wideSlot.width > 350 && wideSlot.maxX == 1092, "no fixed width cap for measured toolbar")
let customized = BarGeometry.slot(navigation: nav, controls: [CGRect(x: 600, y: 110, width: 32, height: 32), CGRect(x: 1100, y: 110, width: 40, height: 32)], toolbar: toolbar)!
check(customized.maxX == 592, "custom toolbar buttons shorten field")
check(BarGeometry.slot(navigation: nav, controls: [CGRect(x: 490, y: 110, width: 40, height: 32)], toolbar: toolbar) == nil, "do not cover toolbar without space")
let fullscreen = BarGeometry.fallback(window: CGRect(x: 0, y: 0, width: 1440, height: 900), sidebar: 194)!
check(fullscreen.minY == 10, "fullscreen uses actual window top")
let secondDisplay = BarGeometry.slot(navigation: CGRect(x: -1200, y: -300, width: 72, height: 32), controls: [CGRect(x: -800, y: -300, width: 30, height: 32)], toolbar: CGRect(x: -1400, y: -310, width: 1000, height: 52))!
check(secondDisplay.midY == -284 && secondDisplay.maxX == -808, "negative display coordinates preserved")
let model = BarModel()
let first = URL(fileURLWithPath: "/Users")
let second = URL(fileURLWithPath: "/Applications")
model.receiveFolder(first, windowID: 1)
check(model.text == first.path && !model.editing, "launch displays Finder folder")
model.editing = true; model.text = "/unfinished"
model.receiveFolder(first, windowID: 1)
check(model.editing && model.text == "/unfinished", "unchanged Finder poll preserves active draft")
for source in ["double-click", "Back", "Forward", "sidebar"] {
    model.editing = true; model.text = "/unfinished"
    let destination = model.folder == first ? second : first
    model.receiveFolder(destination, windowID: 1)
    check(!model.editing && model.text == destination.path, "Finder navigation overrides draft: " + source)
}
model.editing = true; model.text = "/unfinished"
model.receiveFolder(model.folder, windowID: 2)
check(!model.editing && model.text == model.folder?.path, "window switch ends draft even at same folder")
for event in ["cancel", "focus loss", "commit"] {
    model.editing = true; model.text = "/unfinished"; model.endEditing()
    check(!model.editing && model.text == model.folder?.path, "draft discarded after " + event)
}
model.editing = true; model.text = "/unfinished"
model.receiveFolder(nil, windowID: 2)
check(!model.editing && model.text.isEmpty, "virtual Finder location clears stale path")
for top: CGFloat in [0, 30, -900] {
    let buttons = CGRect(x: 202, y: top + 7, width: 75, height: 38)
    let slot = BarGeometry.slot(navigation: buttons, controls: [], toolbar: CGRect(x: 0, y: top, width: 1440, height: 52))!
    check(slot.midY == buttons.midY, "toolbar center follows hidden/revealed menu and secondary display")
    check(slot.height == 36, "full-screen pill matches visible native button height")
}
print("Passed \(checks) checks")
