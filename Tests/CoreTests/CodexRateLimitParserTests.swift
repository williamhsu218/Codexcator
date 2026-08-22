import Foundation
import Testing
@testable import QuotAICore

@Test("Parses 5-hour and 7-day windows by duration, not field position")
func parsesBothQuotaWindows() throws {
    let payload = """
    {"id":1,"result":{"userAgent":"test"}}
    {"id":2,"result":{"rateLimits":{"planType":"free","primary":{"usedPercent":18,"windowDurationMins":300,"resetsAt":1784122800},"secondary":{"usedPercent":7,"windowDurationMins":10080,"resetsAt":1784682166}},"rateLimitsByLimitId":{"codex":{"planType":"plus","primary":{"usedPercent":7,"windowDurationMins":10080,"resetsAt":1784682166},"secondary":{"usedPercent":18,"windowDurationMins":300,"resetsAt":1784122800}}},"rateLimitResetCredits":{"availableCount":4,"credits":[{"grantedAt":1781742705,"expiresAt":1784334705,"status":"available"}]}}}
    """

    let snapshot = try CodexRateLimitParser.parse(jsonLines: payload)

    #expect(snapshot.fiveHour?.remainingPercent == 82)
    #expect(snapshot.sevenDay?.remainingPercent == 93)
    #expect(snapshot.menuBarTitle == "5h 82% · 7d 93%")
    #expect(snapshot.menuBarTitle(for: .fiveHour) == "5h 82%")
    #expect(snapshot.menuBarTitle(for: .sevenDay) == "7d 93%")
    #expect(snapshot.menuBarTitle(for: .both) == "5h 82% · 7d 93%")
    #expect(snapshot.subscriptionPlan?.displayName == "Plus")
    #expect(snapshot.availableResetCount == 4)
    #expect(snapshot.resetCredits.count == 1)
    #expect(snapshot.hasCurrentResetCreditData)
}

@Test("Hides the 5-hour quota when Codex omits it")
func omitsMissingFiveHourWindow() throws {
    let payload = """
    {"id":2,"result":{"rateLimits":{"primary":{"usedPercent":7,"windowDurationMins":10080,"resetsAt":1784682166},"secondary":null},"rateLimitResetCredits":{"availableCount":4,"credits":null}}}
    """

    let snapshot = try CodexRateLimitParser.parse(jsonLines: payload)

    #expect(snapshot.fiveHour == nil)
    #expect(snapshot.sevenDay?.remainingPercent == 93)
    #expect(snapshot.menuBarTitle == "7d 93%")
    #expect(snapshot.menuBarTitle(for: .fiveHour) == "5h --")
    #expect(snapshot.menuBarTitle(for: .sevenDay) == "7d 93%")
    #expect(snapshot.menuBarTitle(for: .both) == "7d 93%")
    #expect(snapshot.availableResetCount == 4)
    #expect(snapshot.resetCredits.isEmpty)
    #expect(snapshot.hasCurrentResetCreditData)
}

@Test("Uses available reset detail rows when the summary count lags")
func derivesResetCountFromAvailableRows() throws {
    let payload = """
    {"id":2,"result":{"rateLimits":{"primary":{"usedPercent":7,"windowDurationMins":10080,"resetsAt":1784682166},"secondary":null},"rateLimitResetCredits":{"availableCount":0,"credits":[{"grantedAt":1781742705,"expiresAt":1784334705,"status":"available"},{"grantedAt":1781742706,"expiresAt":1784334706,"status":"available"},{"grantedAt":1781742707,"expiresAt":1784334707,"status":"redeemed"}]}}}
    """

    let snapshot = try CodexRateLimitParser.parse(jsonLines: payload)

    #expect(snapshot.availableResetCount == 2)
    #expect(snapshot.resetCredits.count == 2)
}

@Test("Distinguishes unavailable reset details from a confirmed zero count")
func distinguishesUnavailableResetDetails() throws {
    let unavailablePayload = """
    {"id":2,"result":{"rateLimits":{"primary":{"usedPercent":7,"windowDurationMins":10080,"resetsAt":1784682166}},"rateLimitResetCredits":null}}
    """
    let zeroPayload = """
    {"id":2,"result":{"rateLimits":{"primary":{"usedPercent":7,"windowDurationMins":10080,"resetsAt":1784682166}},"rateLimitResetCredits":{"availableCount":0,"credits":[]}}}
    """

    let unavailable = try CodexRateLimitParser.parse(jsonLines: unavailablePayload)
    let zero = try CodexRateLimitParser.parse(jsonLines: zeroPayload)

    #expect(!unavailable.hasCurrentResetCreditData)
    #expect(zero.hasCurrentResetCreditData)
    #expect(zero.availableResetCount == 0)
}

@Test("Preserves the last valid reset details when the backend temporarily omits them")
func preservesLastValidResetDetails() {
    let previous = UsageSnapshot.preview
    let unavailable = UsageSnapshot(
        fetchedAt: previous.fetchedAt.addingTimeInterval(300),
        fiveHour: nil,
        sevenDay: QuotaWindow(kind: .sevenDay, remainingPercent: 88, resetsAt: nil),
        subscriptionPlan: SubscriptionPlan(identifier: "prolite"),
        availableResetCount: 0,
        resetCredits: [],
        hasCurrentResetCreditData: false
    )

    let merged = unavailable.preservingResetCredits(from: previous)

    #expect(merged.fetchedAt == unavailable.fetchedAt)
    #expect(merged.sevenDay?.remainingPercent == 88)
    #expect(merged.availableResetCount == previous.availableResetCount)
    #expect(merged.resetCredits == previous.resetCredits)
    #expect(!merged.hasCurrentResetCreditData)
}

@Test("Does not preserve stale resets when the backend confirms zero")
func acceptsConfirmedZeroResetCount() {
    let current = UsageSnapshot(
        fetchedAt: UsageSnapshot.preview.fetchedAt.addingTimeInterval(300),
        fiveHour: nil,
        sevenDay: UsageSnapshot.preview.sevenDay,
        availableResetCount: 0,
        resetCredits: [],
        hasCurrentResetCreditData: true
    )

    #expect(current.preservingResetCredits(from: .preview) == current)
}

@Test("Decodes caches written before reset freshness was added")
func decodesLegacySnapshotCache() throws {
    let encoded = try JSONEncoder().encode(UsageSnapshot.preview)
    var object = try #require(
        JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )
    object.removeValue(forKey: "hasCurrentResetCreditData")
    let legacyData = try JSONSerialization.data(withJSONObject: object)

    let decoded = try JSONDecoder().decode(UsageSnapshot.self, from: legacyData)

    #expect(decoded.hasCurrentResetCreditData)
    #expect(decoded.availableResetCount == UsageSnapshot.preview.availableResetCount)
}

@Test("Clamps malformed percentages into a display-safe range")
func clampsRemainingPercentage() throws {
    let payload = """
    {"id":2,"result":{"rateLimits":{"primary":{"usedPercent":130,"windowDurationMins":300,"resetsAt":null},"secondary":null},"rateLimitResetCredits":{"availableCount":0,"credits":[]}}}
    """

    let snapshot = try CodexRateLimitParser.parse(jsonLines: payload)

    #expect(snapshot.fiveHour?.remainingPercent == 0)
}

@Test("Preserves JSON-RPC error codes and messages")
func preservesServerErrorDetails() throws {
    let payload = #"{"id":2,"error":{"code":-32601,"message":"Method not found"}}"#

    do {
        _ = try CodexRateLimitParser.parse(jsonLines: payload)
        Issue.record("Expected the parser to surface the server error")
    } catch let error as CodexRateLimitParserError {
        #expect(error == .serverError(code: -32_601, message: "Method not found"))
    }
}

@Test("Reads ChatGPT, API key, and signed-out account modes")
func readsAccountAuthModes() {
    let chatGPT = #"{"id":2,"result":{"account":{"type":"chatgpt","planType":"pro"}}}"#
    let apiKey = #"{"id":2,"result":{"account":{"type":"apiKey"}}}"#
    let signedOut = #"{"id":2,"result":{"account":null}}"#

    #expect(CodexAccountParser.authMode(jsonLines: chatGPT) == .chatGPT)
    #expect(CodexAccountParser.authMode(jsonLines: apiKey) == .apiKey)
    #expect(CodexAccountParser.authMode(jsonLines: signedOut) == .signedOut)
    #expect(CodexAccountParser.subscriptionPlanIdentifier(jsonLines: chatGPT) == "pro")
    #expect(CodexAccountParser.subscriptionPlanIdentifier(jsonLines: apiKey) == nil)
}

@Test("Falls back to the account plan when quota data omits it")
func readsPlanFromAccountFallback() throws {
    let payload = """
    {"id":2,"result":{"account":{"type":"chatgpt","planType":"business"}}}
    {"id":3,"result":{"rateLimits":{"primary":{"usedPercent":7,"windowDurationMins":10080,"resetsAt":1784682166},"secondary":null},"rateLimitResetCredits":{"availableCount":0,"credits":[]}}}
    """

    let snapshot = try CodexRateLimitParser.parse(jsonLines: payload, requestID: 3)

    #expect(snapshot.subscriptionPlan?.displayName == "Business")
}

@Test("Normalizes known plan variants and hides unknown plan values")
func formatsSubscriptionPlans() {
    #expect(SubscriptionPlan(identifier: "pro")?.displayName == "Pro20x")
    #expect(SubscriptionPlan(identifier: "prolite")?.displayName == "Pro 5x")
    #expect(SubscriptionPlan(identifier: "self_serve_business_usage_based")?.displayName == "Business")
    #expect(SubscriptionPlan(identifier: "enterprise_cbp_usage_based")?.displayName == "Enterprise")
    #expect(SubscriptionPlan(identifier: "unknown") == nil)
}
