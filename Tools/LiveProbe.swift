import Foundation

@main
struct LiveProbe {
    static func main() async {
        do {
            let snapshot = try await CodexAppServerClient().fetch(customPath: nil)
            let safeResult: [String: Any] = [
                "fiveHourPresent": snapshot.fiveHour != nil,
                "sevenDayRemaining": snapshot.sevenDay?.remainingPercent as Any,
                "subscriptionPlan": snapshot.subscriptionPlan?.displayName as Any,
                "availableResetCount": snapshot.availableResetCount,
                "resetCreditRows": snapshot.resetCredits.count
            ]
            let data = try JSONSerialization.data(withJSONObject: safeResult, options: [.prettyPrinted, .sortedKeys])
            print(String(decoding: data, as: UTF8.self))
        } catch {
            fputs("live_probe_failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}
