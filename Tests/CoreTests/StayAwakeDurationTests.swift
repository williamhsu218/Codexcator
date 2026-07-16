import Foundation
import Testing

@testable import CodexIndicatorCore

@Test("Stay Awake finite durations match Caffeine choices")
func stayAwakeFiniteDurations() {
    #expect(StayAwakeDuration.fiveMinutes.interval == 300)
    #expect(StayAwakeDuration.tenMinutes.interval == 600)
    #expect(StayAwakeDuration.fifteenMinutes.interval == 900)
    #expect(StayAwakeDuration.thirtyMinutes.interval == 1_800)
    #expect(StayAwakeDuration.oneHour.interval == 3_600)
    #expect(StayAwakeDuration.twoHours.interval == 7_200)
    #expect(StayAwakeDuration.fiveHours.interval == 18_000)
}

@Test("Indefinite Stay Awake has no expiration")
func indefiniteStayAwakeHasNoExpiration() {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    #expect(StayAwakeDuration.indefinitely.interval == nil)
    #expect(StayAwakeDuration.indefinitely.expirationDate(startingAt: start) == nil)
    #expect(
        StayAwakeDuration.oneHour.expirationDate(startingAt: start)
            == start.addingTimeInterval(3_600)
    )
}
