import Foundation

enum PathLogic {
    static func isTerminal(_ input: String) -> Bool {
        ["terminal", "cmd"].contains(input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
    static func resolve(_ input: String, current: URL?) throws -> URL {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw Failure.message("Enter a folder path.") }
        let url: URL
        if value.hasPrefix("file://") {
            guard let parsed = URL(string: value), parsed.isFileURL,
                  parsed.host == nil || parsed.host == "" || parsed.host == "localhost" else {
                throw Failure.message("Enter a local file URL.")
            }
            url = parsed
        } else {
            let expanded = (value as NSString).expandingTildeInPath
            if expanded.hasPrefix("/") { url = URL(fileURLWithPath: expanded) }
            else if let current { url = current.appendingPathComponent(expanded) }
            else { throw Failure.message("Use an absolute path when Finder has no current folder.") }
        }
        let result = url.standardizedFileURL
        var directory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: result.path, isDirectory: &directory), directory.boolValue else {
            throw Failure.message("Folder not found or not accessible: \(result.path)")
        }
        return result
    }
    static func ancestors(_ url: URL) -> [URL] {
        var result = [url.standardizedFileURL]
        while result[0].path != "/" { result.insert(result[0].deletingLastPathComponent(), at: 0) }
        return result
    }
    static func appleString(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
enum Failure: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let value) = self { return value }; return nil }
}
