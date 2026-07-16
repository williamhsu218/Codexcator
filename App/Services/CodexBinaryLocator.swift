import Foundation

enum CodexBinaryLocatorError: LocalizedError {
    case invalidCustomPath(String)
    case notFound

    var errorDescription: String? {
        switch self {
        case let .invalidCustomPath(path):
            L10n.format(
                "error.binary.invalid_path_format",
                fallback: "The configured Codex path is not executable: %@",
                path
            )
        case .notFound:
            L10n.text(
                "error.binary.not_found",
                fallback: "Codex was not found on this Mac. Install or sign in to ChatGPT/Codex, or specify the Codex path in Settings."
            )
        }
    }
}

enum CodexBinaryLocator {
    static func candidates(customPath: String?) throws -> [URL] {
        let fileManager = FileManager.default

        if let customPath, !customPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let expanded = NSString(string: customPath).expandingTildeInPath
            guard fileManager.isExecutableFile(atPath: expanded) else {
                throw CodexBinaryLocatorError.invalidCustomPath(customPath)
            }
            return [URL(fileURLWithPath: expanded)]
        }

        var candidates = [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            NSString(string: "~/.local/bin/codex").expandingTildeInPath
        ]

        if let path = ProcessInfo.processInfo.environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").map {
                URL(fileURLWithPath: String($0)).appendingPathComponent("codex").path
            })
        }
        candidates.append("/Applications/ChatGPT.app/Contents/Resources/codex")

        var seenPaths = Set<String>()
        let executables = candidates.compactMap { path -> URL? in
            guard fileManager.isExecutableFile(atPath: path) else { return nil }
            let url = URL(fileURLWithPath: path).standardizedFileURL
            let identity = url.resolvingSymlinksInPath().path
            guard seenPaths.insert(identity).inserted else { return nil }
            return url
        }

        guard !executables.isEmpty else {
            throw CodexBinaryLocatorError.notFound
        }
        return executables
    }

    static func locate(customPath: String?) throws -> URL {
        try candidates(customPath: customPath)[0]
    }
}
