import Foundation
import GRDB

public struct TimeEntry: Codable, Identifiable, Equatable {
    public var id: Int64?
    public var project: String
    public var startAt: Date
    public var endAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: Int64? = nil, project: String, startAt: Date, endAt: Date? = nil,
                createdAt: Date, updatedAt: Date) {
        self.id = id
        self.project = project
        self.startAt = startAt
        self.endAt = endAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var isRunning: Bool { endAt == nil }

    public func duration(asOf now: Date = Date()) -> TimeInterval {
        (endAt ?? now).timeIntervalSince(startAt)
    }
}

extension TimeEntry: FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "time_entry"

    enum CodingKeys: String, CodingKey {
        case id
        case project
        case startAt = "start_at"
        case endAt = "end_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension TimeEntry {
    public static func runningRequest() -> QueryInterfaceRequest<TimeEntry> {
        filter(Column("end_at") == nil)
    }

    /// Zaustavljeni entry-ji čiji start pada u dati interval (entry pripada nedelji svog starta).
    public static func stoppedRequest(in interval: DateInterval) -> QueryInterfaceRequest<TimeEntry> {
        filter(Column("end_at") != nil
               && Column("start_at") >= interval.start
               && Column("start_at") < interval.end)
            .order(Column("start_at").desc)
    }
}
