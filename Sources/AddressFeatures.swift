import Foundation

enum AddressFeatures {
    static func expand(_ input: String) -> String {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.count > 1 && ((value.first == "\"" && value.last == "\"") || (value.first == "'" && value.last == "'")) { value = String(value.dropFirst().dropLast()) }
        let aliases = ["home": NSHomeDirectory(), "desktop": NSHomeDirectory() + "/Desktop", "documents": NSHomeDirectory() + "/Documents", "downloads": NSHomeDirectory() + "/Downloads", "applications": "/Applications", "computer": "/Volumes"]
        if let alias = aliases[value.lowercased()] { return alias }
        // Expand only a leading variable; literal dollar signs inside names stay literal.
        let variables = ["$HOME": NSHomeDirectory(), "${HOME}": NSHomeDirectory(), "%USERPROFILE%": NSHomeDirectory(), "%HOME%": NSHomeDirectory(), "$TMPDIR": NSTemporaryDirectory(), "%TEMP%": NSTemporaryDirectory()]
        for (key, replacement) in variables where value == key || value.hasPrefix(key + "/") {
            value = replacement + value.dropFirst(key.count)
            break
        }
        return (value as NSString).expandingTildeInPath
    }
    static func externalURL(_ input: String) -> URL? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("\\\\") {
            let path = value.dropFirst(2).replacingOccurrences(of: "\\", with: "/")
            return URL(string: "smb://" + (path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path))
        }
        guard let url = URL(string: value), ["https", "http", "smb", "afp", "ftp"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
        return url
    }
    static func localItem(_ input: String, current: URL?) throws -> URL {
        let value = expand(input)
        guard !value.isEmpty else { throw Failure.message("Enter a path.") }
        let url: URL
        if value.hasPrefix("file://") {
            guard let parsed = URL(string: value), parsed.isFileURL, [nil, "", "localhost"].contains(parsed.host) else { throw Failure.message("Use a local file URL or smb://server/share.") }
            url = parsed
        } else if value.hasPrefix("/") { url = URL(fileURLWithPath: value) }
        else if let current { url = current.appendingPathComponent(value) }
        else { throw Failure.message("Enter an absolute path.") }
        let result = url.standardizedFileURL
        guard FileManager.default.fileExists(atPath: result.path) else { throw Failure.message("Path not found: \(result.path)") }
        return result
    }
    static func directories(_ parent: URL) -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(at: parent, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        return items.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
    static func suggestions(_ input: String, current: URL?, history: [String]) -> [String] {
        let value = expand(input)
        if value.isEmpty { return Array(history.prefix(30)) }
        let base: URL
        if value.hasPrefix("/") { base = URL(fileURLWithPath: value) }
        else if let current { base = current.appendingPathComponent(value) }
        else { return [] }
        let parent = value.hasSuffix("/") ? base : base.deletingLastPathComponent()
        let prefix = value.hasSuffix("/") ? "" : base.lastPathComponent
        let directories = directories(parent).filter { ($0.lastPathComponent.range(of: prefix, options: [.anchored, .caseInsensitive]) != nil || prefix.isEmpty) }.prefix(100).map { $0.path + "/" }
        var seen = Set<String>()
        return (directories + history.filter { $0.range(of: value, options: [.anchored, .caseInsensitive]) != nil }).filter { seen.insert($0).inserted }
    }
    static func application(_ input: String) -> URL? {
        let name = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let file = name.hasSuffix(".app") ? name : name + ".app"
        for parent in ["/Applications", "/System/Applications", "/System/Applications/Utilities", NSHomeDirectory() + "/Applications"] {
            let url = URL(fileURLWithPath: parent).appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }
    static func remember(_ path: String, history: [String]) -> [String] {
        Array(([path] + history.filter { $0 != path }).prefix(30))
    }
}
