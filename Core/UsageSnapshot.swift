import Foundation

public struct SubscriptionPlan: Codable, Equatable, Sendable {
    public let identifier: String

    public init?(identifier: String?) {
        guard let identifier else { return nil }
        let normalized = identifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty, normalized != "unknown" else { return nil }
        self.identifier = normalized
    }

    public var displayName: String {
        switch identifier {
        case "free":
            "Free"
        case "go":
            "Go"
        case "plus":
            "Plus"
        case "pro":
            "Pro20x"
        case "prolite":
            "Pro 5x"
        case "team":
            "Team"
        case "self_serve_business_usage_based", "business":
            "Business"
        case "enterprise_cbp_usage_based", "enterprise":
            "Enterprise"
        case "edu":
            "Edu"
        default:
            identifier
                .replacingOccurrences(of: "_", with: " ")
                .split(separator: " ")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
    }
}

public enum QuotaKind: String, Codable, CaseIterable, Sendable {
    case fiveHour
    case sevenDay

    public var shortLabel: String {
        switch self {
        case .fiveHour: "5h"
        case .sevenDay: "7d"
        }
    }

    public var displayName: String {
        switch self {
        case .fiveHour:
            L10n.text("quota.five_hour", fallback: "5 hours")
        case .sevenDay:
            L10n.text("quota.seven_day", fallback: "7 days")
        }
    }
}

public enum MenuBarQuotaDisplayMode: String, Codable, CaseIterable, Sendable {
    public static let defaultsKey = "menuBarQuotaDisplayMode"

    case fiveHour
    case sevenDay
    case both

    public var selectedKinds: [QuotaKind] {
        switch self {
        case .fiveHour:
            [.fiveHour]
        case .sevenDay:
            [.sevenDay]
        case .both:
            [.fiveHour, .sevenDay]
        }
    }
}

public struct QuotaWindow: Codable, Equatable, Identifiable, Sendable {
    public let kind: QuotaKind
    public let remainingPercent: Int
    public let resetsAt: Date?

    public var id: QuotaKind { kind }

    public init(kind: QuotaKind, remainingPercent: Int, resetsAt: Date?) {
        self.kind = kind
        self.remainingPercent = min(100, max(0, remainingPercent))
        self.resetsAt = resetsAt
    }
}

public struct ResetCredit: Codable, Equatable, Identifiable, Sendable {
    public let grantedAt: Date
    public let expiresAt: Date?
    public let status: String

    public var id: String {
        "\(Int(grantedAt.timeIntervalSince1970))-\(Int(expiresAt?.timeIntervalSince1970 ?? 0))"
    }

    public init(grantedAt: Date, expiresAt: Date?, status: String) {
        self.grantedAt = grantedAt
        self.expiresAt = expiresAt
        self.status = status
    }
}

public struct UsageSnapshot: Codable, Equatable, Sendable {
    public let fetchedAt: Date
    public let fiveHour: QuotaWindow?
    public let sevenDay: QuotaWindow?
    public let subscriptionPlan: SubscriptionPlan?
    public let availableResetCount: Int
    public let resetCredits: [ResetCredit]
    public let hasCurrentResetCreditData: Bool

    public init(
        fetchedAt: Date,
        fiveHour: QuotaWindow?,
        sevenDay: QuotaWindow?,
        subscriptionPlan: SubscriptionPlan? = nil,
        availableResetCount: Int,
        resetCredits: [ResetCredit],
        hasCurrentResetCreditData: Bool = true
    ) {
        self.fetchedAt = fetchedAt
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.subscriptionPlan = subscriptionPlan
        self.availableResetCount = max(0, availableResetCount)
        self.resetCredits = resetCredits
        self.hasCurrentResetCreditData = hasCurrentResetCreditData
    }

    private enum CodingKeys: String, CodingKey {
        case fetchedAt
        case fiveHour
        case sevenDay
        case subscriptionPlan
        case availableResetCount
        case resetCredits
        case hasCurrentResetCreditData
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
        fiveHour = try container.decodeIfPresent(QuotaWindow.self, forKey: .fiveHour)
        sevenDay = try container.decodeIfPresent(QuotaWindow.self, forKey: .sevenDay)
        subscriptionPlan = try container.decodeIfPresent(
            SubscriptionPlan.self,
            forKey: .subscriptionPlan
        )
        availableResetCount = max(
            0,
            try container.decode(Int.self, forKey: .availableResetCount)
        )
        resetCredits = try container.decode([ResetCredit].self, forKey: .resetCredits)
        hasCurrentResetCreditData = try container.decodeIfPresent(
            Bool.self,
            forKey: .hasCurrentResetCreditData
        ) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fetchedAt, forKey: .fetchedAt)
        try container.encodeIfPresent(fiveHour, forKey: .fiveHour)
        try container.encodeIfPresent(sevenDay, forKey: .sevenDay)
        try container.encodeIfPresent(subscriptionPlan, forKey: .subscriptionPlan)
        try container.encode(availableResetCount, forKey: .availableResetCount)
        try container.encode(resetCredits, forKey: .resetCredits)
        try container.encode(hasCurrentResetCreditData, forKey: .hasCurrentResetCreditData)
    }

    public func preservingResetCredits(from previous: UsageSnapshot?) -> UsageSnapshot {
        guard !hasCurrentResetCreditData, let previous else { return self }
        return UsageSnapshot(
            fetchedAt: fetchedAt,
            fiveHour: fiveHour,
            sevenDay: sevenDay,
            subscriptionPlan: subscriptionPlan,
            availableResetCount: previous.availableResetCount,
            resetCredits: previous.resetCredits,
            hasCurrentResetCreditData: false
        )
    }

    public var orderedQuotas: [QuotaWindow] {
        [fiveHour, sevenDay].compactMap { $0 }
    }

    public var menuBarTitle: String {
        menuBarTitle(for: .both)
    }

    public func menuBarTitle(for mode: MenuBarQuotaDisplayMode) -> String {
        let quotasByKind = Dictionary(
            uniqueKeysWithValues: orderedQuotas.map { ($0.kind, $0) }
        )
        let parts = mode.selectedKinds.compactMap { kind -> String? in
            if let quota = quotasByKind[kind] {
                return "\(kind.shortLabel) \(quota.remainingPercent)%"
            }
            return mode == .both ? nil : "\(kind.shortLabel) --"
        }
        return parts.isEmpty ? "Codex --" : parts.joined(separator: " · ")
    }
}

public extension UsageSnapshot {
    static let preview: UsageSnapshot = {
        let calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(identifier: "Asia/Shanghai")!
        func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
            var components = DateComponents()
            components.calendar = calendar
            components.timeZone = timeZone
            components.year = year
            components.month = month
            components.day = day
            components.hour = hour
            components.minute = minute
            return components.date!
        }

        return UsageSnapshot(
            fetchedAt: date(2026, 7, 15, 20, 33),
            fiveHour: QuotaWindow(
                kind: .fiveHour,
                remainingPercent: 82,
                resetsAt: date(2026, 7, 15, 21, 40)
            ),
            sevenDay: QuotaWindow(
                kind: .sevenDay,
                remainingPercent: 93,
                resetsAt: date(2026, 7, 22, 9, 2)
            ),
            subscriptionPlan: SubscriptionPlan(identifier: "prolite"),
            availableResetCount: 4,
            resetCredits: [
                ResetCredit(grantedAt: date(2026, 6, 18, 8, 31), expiresAt: date(2026, 7, 18, 8, 31), status: "available"),
                ResetCredit(grantedAt: date(2026, 6, 27, 8, 0), expiresAt: date(2026, 7, 27, 8, 0), status: "available"),
                ResetCredit(grantedAt: date(2026, 7, 2, 4, 17), expiresAt: date(2026, 8, 1, 4, 17), status: "available"),
                ResetCredit(grantedAt: date(2026, 7, 14, 2, 0), expiresAt: date(2026, 8, 13, 2, 0), status: "available")
            ]
        )
    }()
}
