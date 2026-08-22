import Foundation
import OSLog

enum AntigravityQuotaClientError: LocalizedError {
    case notRunning
    case runtimeUnavailable
    case quotaUnavailable
    case protocolChanged

    var errorDescription: String? {
        switch self {
        case .notRunning:
            L10n.text(
                "error.antigravity.not_running",
                fallback: "Open Antigravity to read its quota."
            )
        case .runtimeUnavailable:
            L10n.text(
                "error.antigravity.runtime_unavailable",
                fallback: "Antigravity's local quota service is unavailable."
            )
        case .quotaUnavailable:
            L10n.text(
                "error.antigravity.quota_unavailable",
                fallback: "Antigravity quota is temporarily unavailable."
            )
        case .protocolChanged:
            L10n.text(
                "error.antigravity.protocol_changed",
                fallback: "This Antigravity version uses an unsupported quota format."
            )
        }
    }
}

actor AntigravityQuotaClient {
    private nonisolated static let languageServerPattern =
        #"[/]Antigravity( IDE)?\.app/Contents/Resources/bin/language_server( |$)"#
    private nonisolated static let quotaPath =
        "/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary"
    private nonisolated static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.willhsu.QuotAI",
        category: "AntigravityQuota"
    )

    func fetch() async throws -> AntigravityQuotaSnapshot {
        try await Task.detached(priority: .utility) {
            try Self.fetchSynchronously()
        }.value
    }

    private nonisolated static func fetchSynchronously() throws -> AntigravityQuotaSnapshot {
        let processIDs = try languageServerProcessIDs()
        guard !processIDs.isEmpty else {
            throw AntigravityQuotaClientError.notRunning
        }

        var foundRuntimeMetadata = false
        var receivedUnrecognizedResponse = false

        for processID in processIDs {
            guard let commandLine = try? commandLine(processID: processID),
                  let csrfToken = argumentValue(named: "--csrf_token", in: commandLine)
                    ?? argumentValue(named: "--csrf-token", in: commandLine),
                  !csrfToken.isEmpty,
                  !csrfToken.contains(where: \.isNewline),
                  let endpoints = try? listeningEndpoints(processID: processID),
                  !endpoints.isEmpty else {
                continue
            }
            foundRuntimeMetadata = true

            for endpoint in endpoints {
                guard let data = try? requestQuota(
                    endpoint: endpoint,
                    csrfToken: csrfToken
                ) else {
                    continue
                }
                do {
                    let snapshot = try AntigravityQuotaParser.parse(data: data)
                    logger.info(
                        "Antigravity quota refresh succeeded; groupCount=\(snapshot.groups.count, privacy: .public)"
                    )
                    return snapshot
                } catch {
                    receivedUnrecognizedResponse = true
                }
            }
        }

        if receivedUnrecognizedResponse {
            throw AntigravityQuotaClientError.protocolChanged
        }
        if foundRuntimeMetadata {
            throw AntigravityQuotaClientError.quotaUnavailable
        }
        throw AntigravityQuotaClientError.runtimeUnavailable
    }

    private nonisolated static func languageServerProcessIDs() throws -> [Int32] {
        let result = try run(
            executable: URL(fileURLWithPath: "/usr/bin/pgrep"),
            arguments: ["-f", languageServerPattern]
        )
        guard result.status == 0 else { return [] }
        return String(decoding: result.output, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .compactMap { Int32($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private nonisolated static func commandLine(processID: Int32) throws -> String {
        let result = try run(
            executable: URL(fileURLWithPath: "/bin/ps"),
            arguments: ["-ww", "-p", String(processID), "-o", "command="]
        )
        guard result.status == 0 else {
            throw AntigravityQuotaClientError.runtimeUnavailable
        }
        return String(decoding: result.output, as: UTF8.self)
    }

    private nonisolated static func argumentValue(
        named name: String,
        in commandLine: String
    ) -> String? {
        if let range = commandLine.range(of: "\(name)=") {
            let value = commandLine[range.upperBound...].prefix { !$0.isWhitespace }
            return value.isEmpty ? nil : String(value)
        }

        let arguments = commandLine.split(whereSeparator: \.isWhitespace)
        guard let index = arguments.firstIndex(of: Substring(name)),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return String(arguments[index + 1])
    }

    private nonisolated static func listeningEndpoints(
        processID: Int32
    ) throws -> [LoopbackEndpoint] {
        let result = try run(
            executable: URL(fileURLWithPath: "/usr/sbin/lsof"),
            arguments: [
                "-nP", "-a", "-p", String(processID),
                "-iTCP", "-sTCP:LISTEN", "-FnP"
            ]
        )
        guard result.status == 0 else { return [] }

        var endpoints: [LoopbackEndpoint] = []
        for line in String(decoding: result.output, as: UTF8.self)
            .split(whereSeparator: \.isNewline) {
            if line.hasPrefix("n127.0.0.1:"),
               let port = Int(line.dropFirst("n127.0.0.1:".count)) {
                endpoints.append(LoopbackEndpoint(host: "127.0.0.1", port: port))
            } else if line.hasPrefix("n[::1]:"),
                      let port = Int(line.dropFirst("n[::1]:".count)) {
                endpoints.append(LoopbackEndpoint(host: "[::1]", port: port))
            }
        }
        return Array(Set(endpoints)).sorted { $0.port < $1.port }
    }

    private nonisolated static func requestQuota(
        endpoint: LoopbackEndpoint,
        csrfToken: String
    ) throws -> Data {
        let headerData = Data(
            "x-codeium-csrf-token: \(csrfToken)\nContent-Type: application/json\n".utf8
        )
        let result = try run(
            executable: URL(fileURLWithPath: "/usr/bin/curl"),
            arguments: [
                "--silent",
                "--insecure",
                "--fail",
                "--noproxy", "*",
                "--connect-timeout", "2",
                "--max-time", "15",
                "--request", "POST",
                "--header", "@-",
                "--data", #"{"forceRefresh":true}"#,
                "https://\(endpoint.host):\(endpoint.port)\(quotaPath)"
            ],
            standardInput: headerData
        )
        guard result.status == 0, !result.output.isEmpty else {
            throw AntigravityQuotaClientError.quotaUnavailable
        }
        return result.output
    }

    private nonisolated static func run(
        executable: URL,
        arguments: [String],
        standardInput: Data? = nil
    ) throws -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let inputPipe = standardInput == nil ? nil : Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = inputPipe ?? FileHandle.nullDevice
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            if let standardInput, let inputPipe {
                try inputPipe.fileHandleForWriting.write(contentsOf: standardInput)
                try inputPipe.fileHandleForWriting.close()
            }
        } catch {
            if process.isRunning { process.terminate() }
            throw AntigravityQuotaClientError.runtimeUnavailable
        }

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return CommandResult(status: process.terminationStatus, output: output)
    }
}

private struct LoopbackEndpoint: Hashable, Sendable {
    let host: String
    let port: Int
}

private struct CommandResult: Sendable {
    let status: Int32
    let output: Data
}
