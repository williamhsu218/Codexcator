import Foundation

public enum LocalSnapshotStore {
    private static let filename = "usage-snapshot.json"

    public static func load(fileManager: FileManager = .default) throws -> UsageSnapshot? {
        let fileURL = try snapshotURL(fileManager: fileManager)
        if !fileManager.fileExists(atPath: fileURL.path) {
            // Migrate legacy snapshot if present
            let supportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            for legacyName in ["Codexcator", "CodexIndicator"] {
                let legacyURL = supportURL
                    .appendingPathComponent(legacyName, isDirectory: true)
                    .appendingPathComponent(filename, isDirectory: false)
                if fileManager.fileExists(atPath: legacyURL.path) {
                    let data = try Data(contentsOf: legacyURL)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let snapshot = try decoder.decode(UsageSnapshot.self, from: data)
                    try save(snapshot, fileManager: fileManager)
                    return snapshot
                }
            }
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(UsageSnapshot.self, from: data)
    }

    public static func save(_ snapshot: UsageSnapshot, fileManager: FileManager = .default) throws {
        let fileURL = try snapshotURL(fileManager: fileManager)
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    public static func snapshotURL(fileManager: FileManager = .default) throws -> URL {
        let supportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return supportURL
            .appendingPathComponent("QuotAI", isDirectory: true)
            .appendingPathComponent(filename, isDirectory: false)
    }
}
