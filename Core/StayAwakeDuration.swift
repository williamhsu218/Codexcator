import Foundation

public enum StayAwakeDuration: String, CaseIterable, Codable, Identifiable, Sendable {
    case fiveMinutes
    case tenMinutes
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case twoHours
    case fiveHours
    case indefinitely

    public var id: String { rawValue }

    public var interval: TimeInterval? {
        switch self {
        case .fiveMinutes: 5 * 60
        case .tenMinutes: 10 * 60
        case .fifteenMinutes: 15 * 60
        case .thirtyMinutes: 30 * 60
        case .oneHour: 60 * 60
        case .twoHours: 2 * 60 * 60
        case .fiveHours: 5 * 60 * 60
        case .indefinitely: nil
        }
    }

    public func expirationDate(startingAt startDate: Date) -> Date? {
        interval.map { startDate.addingTimeInterval($0) }
    }
}
