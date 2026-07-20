import Foundation

public struct ProjectGroup: Identifiable, Equatable {
    public let project: String
    public let totalSeconds: TimeInterval
    public let entries: [TimeEntry]
    public var id: String { project }

    /// Najskoriji update bilo kog entry-ja u grupi — projekat koji je poslednji menjan ide prvi.
    public var lastUpdatedAt: Date { entries.map(\.updatedAt).max() ?? .distantPast }
}

public struct DayGroup: Identifiable, Equatable {
    public let dayStart: Date
    public let totalSeconds: TimeInterval
    public let projects: [ProjectGroup]
    public var id: Date { dayStart }
}

public enum WeekGrouping {
    /// Grupisanje po danima (najskoriji dan prvi), unutar dana po projektu.
    public static func days(from entries: [TimeEntry], calendar: Calendar = .iso8601,
                            asOf now: Date = Date()) -> [DayGroup] {
        Dictionary(grouping: entries) { calendar.startOfDay(for: $0.startAt) }
            .map { day, dayEntries in
                DayGroup(
                    dayStart: day,
                    totalSeconds: dayEntries.reduce(0) { $0 + $1.duration(asOf: now) },
                    projects: groups(from: dayEntries, asOf: now)
                )
            }
            .sorted { $0.dayStart > $1.dayStart }
    }

    /// ISO nedelja (ponedeljak start) koja sadrži dati datum.
    public static func weekInterval(containing date: Date, calendar: Calendar = .iso8601) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date)!
    }

    /// Grupisanje entry-ja po projektu; grupe sortirane po poslednjem update-u
    /// (poslednji menjan/dodat projekat prvi), entry-ji unutar grupe po startu opadajuće.
    /// `asOf` određuje "sada" za running entry — pozivalac koji već ima svoj tick (TimelineView)
    /// prosleđuje isti datum, da se header i redovi ne razilaze za sekundu.
    public static func groups(from entries: [TimeEntry], asOf now: Date = Date()) -> [ProjectGroup] {
        Dictionary(grouping: entries, by: \.project)
            .map { project, entries in
                let sorted = entries.sorted { $0.startAt > $1.startAt }
                return ProjectGroup(
                    project: project,
                    totalSeconds: sorted.reduce(0) { $0 + $1.duration(asOf: now) },
                    entries: sorted
                )
            }
            // tiebreak po nazivu → stabilan redosled kad je updatedAt jednak (bez nasumičnog skakanja)
            .sorted { ($0.lastUpdatedAt, $0.project) > ($1.lastUpdatedAt, $1.project) }
    }
}

extension Calendar {
    public static let iso8601: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }()
}
