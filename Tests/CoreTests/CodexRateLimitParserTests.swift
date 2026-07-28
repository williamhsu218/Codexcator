import Foundation
import Testing
@testable import CodexIndicatorCore

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
    #expect(snapshot.subscriptionPlan?.displayName == "Plus")
    #expect(snapshot.availableResetCount == 4)
    #expect(snapshot.resetCredits.count == 1)
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
    #expect(snapshot.availableResetCount == 4)
    #expect(snapshot.resetCredits.isEmpty)
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
    #expect(SubscriptionPlan(identifier: "prolite")?.displayName == "Pro5x")
    #expect(SubscriptionPlan(identifier: "self_serve_business_usage_based")?.displayName == "Business")
    #expect(SubscriptionPlan(identifier: "enterprise_cbp_usage_based")?.displayName == "Enterprise")
    #expect(SubscriptionPlan(identifier: "unknown") == nil)
}
