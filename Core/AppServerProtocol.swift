import Foundation

public enum CodexRateLimitParserError: LocalizedError, Equatable {
    case missingResponse
    case serverError(code: Int?, message: String)
    case missingRateLimits

    public var errorDescription: String? {
        switch self {
        case .missingResponse:
            return L10n.text(
                "error.parser.missing_response",
                fallback: "Codex did not return quota data."
            )
        case let .serverError(code, message):
            let summary = code.map { "\($0): \(message)" } ?? message
            return L10n.format(
                "error.parser.server_format",
                fallback: "Codex App Server returned an error: %@",
                summary
            )
        case .missingRateLimits:
            return L10n.text(
                "error.parser.missing_limits",
                fallback: "Codex returned no recognizable quota windows."
            )
        }
    }
}

public enum CodexRateLimitParser {
    public static func parse(
        jsonLines: String,
        requestID: Int = 2,
        fetchedAt: Date = Date()
    ) throws -> UsageSnapshot {
        let decoder = JSONDecoder()
        var matchedResponse: RateLimitsEnvelope?

        for line in jsonLines.split(whereSeparator: \.isNewline) {
            guard let data = String(line).data(using: .utf8),
                  let envelope = try? decoder.decode(RateLimitsEnvelope.self, from: data),
                  envelope.id == requestID else {
                continue
            }
            matchedResponse = envelope
            break
        }

        guard let response = matchedResponse else {
            throw CodexRateLimitParserError.missingResponse
        }
        if let error = response.error {
            throw CodexRateLimitParserError.serverError(
                code: error.code,
                message: error.message
            )
        }
        guard let result = response.result else {
            throw CodexRateLimitParserError.missingResponse
        }

        let snapshot = result.rateLimitsByLimitId?["codex"] ?? result.rateLimits
        guard let snapshot else {
            throw CodexRateLimitParserError.missingRateLimits
        }

        let windows = [snapshot.primary, snapshot.secondary].compactMap { $0 }
        let fiveHour = windows.first(where: { $0.windowDurationMins == 300 }).map {
            quota(from: $0, kind: .fiveHour)
        }
        let sevenDay = windows.first(where: { $0.windowDurationMins == 10_080 }).map {
            quota(from: $0, kind: .sevenDay)
        }

        let summary = result.rateLimitResetCredits
        let credits = (summary?.credits ?? [])
            .filter { $0.status == "available" }
            .map {
                ResetCredit(
                    grantedAt: Date(timeIntervalSince1970: TimeInterval($0.grantedAt)),
                    expiresAt: $0.expiresAt.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                    status: $0.status
                )
            }
            .sorted {
                ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture)
            }

        return UsageSnapshot(
            fetchedAt: fetchedAt,
            fiveHour: fiveHour,
            sevenDay: sevenDay,
            subscriptionPlan: SubscriptionPlan(
                identifier: snapshot.planType
                    ?? CodexAccountParser.subscriptionPlanIdentifier(
                        jsonLines: jsonLines
                    )
            ),
            availableResetCount: summary?.availableCount ?? 0,
            resetCredits: credits
        )
    }

    private static func quota(from window: RateLimitWindowDTO, kind: QuotaKind) -> QuotaWindow {
        QuotaWindow(
            kind: kind,
            remainingPercent: 100 - window.usedPercent,
            resetsAt: window.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        )
    }
}

private struct RateLimitsEnvelope: Decodable {
    let id: Int?
    let result: RateLimitsResultDTO?
    let error: RPCErrorDTO?
}

private struct RPCErrorDTO: Decodable {
    let code: Int?
    let message: String
}

public enum CodexAuthMode: Equatable, Sendable {
    case chatGPT
    case apiKey
    case signedOut
    case other(String)
    case unknown
}

public enum CodexAccountParser {
    public static func authMode(jsonLines: String, requestID: Int = 2) -> CodexAuthMode {
        let decoder = JSONDecoder()

        for line in jsonLines.split(whereSeparator: \.isNewline) {
            guard let data = String(line).data(using: .utf8),
                  let envelope = try? decoder.decode(AccountEnvelope.self, from: data),
                  envelope.id == requestID else {
                continue
            }
            guard envelope.error == nil, let result = envelope.result else {
                return .unknown
            }
            guard let account = result.account else {
                return .signedOut
            }
            switch account.type.lowercased() {
            case "chatgpt":
                return .chatGPT
            case "apikey", "api_key":
                return .apiKey
            default:
                return .other(account.type)
            }
        }

        return .unknown
    }

    public static func subscriptionPlanIdentifier(
        jsonLines: String,
        requestID: Int = 2
    ) -> String? {
        let decoder = JSONDecoder()

        for line in jsonLines.split(whereSeparator: \.isNewline) {
            guard let data = String(line).data(using: .utf8),
                  let envelope = try? decoder.decode(AccountEnvelope.self, from: data),
                  envelope.id == requestID else {
                continue
            }
            guard envelope.error == nil else { return nil }
            return envelope.result?.account?.planType
        }

        return nil
    }
}

private struct AccountEnvelope: Decodable {
    let id: Int?
    let result: AccountResultDTO?
    let error: RPCErrorDTO?
}

private struct AccountResultDTO: Decodable {
    let account: AccountDTO?
}

private struct AccountDTO: Decodable {
    let type: String
    let planType: String?
}

private struct RateLimitsResultDTO: Decodable {
    let rateLimits: RateLimitSnapshotDTO?
    let rateLimitsByLimitId: [String: RateLimitSnapshotDTO]?
    let rateLimitResetCredits: ResetCreditsSummaryDTO?
}

private struct RateLimitSnapshotDTO: Decodable {
    let planType: String?
    let primary: RateLimitWindowDTO?
    let secondary: RateLimitWindowDTO?
}

private struct RateLimitWindowDTO: Decodable {
    let usedPercent: Int
    let windowDurationMins: Int?
    let resetsAt: Int64?
}

private struct ResetCreditsSummaryDTO: Decodable {
    let availableCount: Int
    let credits: [ResetCreditDTO]?
}

private struct ResetCreditDTO: Decodable {
    let grantedAt: Int64
    let expiresAt: Int64?
    let status: String
}
