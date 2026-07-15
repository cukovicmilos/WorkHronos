import Foundation

public struct ProjectGroup: Identifiable, Equatable {
    public let project: String
    public let totalSeconds: TimeInterval
    public let entries: [TimeEntry]
    public var id: String { project }
}

public enum WeekGrouping {
    /// ISO nedelja (ponedeljak start) koja sadrži dati datum.
    public static func weekInterval(containing date: Date, calendar: Calendar = .iso8601) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date)!
    }

    /// Grupisanje entry-ja po projektu; grupe sortirane po najskorijem entry-ju,
    /// entry-ji unutar grupe po startu opadajuće.
    public static func groups(from entries: [TimeEntry]) -> [ProjectGroup] {
        Dictionary(grouping: entries, by: \.project)
            .map { project, entries in
                let sorted = entries.sorted { $0.startAt > $1.startAt }
                return ProjectGroup(
                    project: project,
                    totalSeconds: sorted.reduce(0) { $0 + $1.duration() },
                    entries: sorted
                )
            }
            .sorted { ($0.entries.first?.startAt ?? .distantPast) > ($1.entries.first?.startAt ?? .distantPast) }
    }
}

extension Calendar {
    public static let iso8601: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }()
}
