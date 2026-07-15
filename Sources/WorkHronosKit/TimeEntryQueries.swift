import Foundation
import GRDB

extension AppDatabase {
    /// Startuje novi timer; ako neki već radi, prvo ga zaustavlja (Toggl ponašanje), ista transakcija.
    @discardableResult
    public func startTimer(project: String, now: Date = Date()) throws -> TimeEntry {
        try write { db in
            try Self.stopRunningEntry(db, at: now)
            var entry = TimeEntry(project: project, startAt: now, createdAt: now, updatedAt: now)
            try entry.insert(db)
            return entry
        }
    }

    public func stopRunning(now: Date = Date()) throws {
        try write { db in
            try Self.stopRunningEntry(db, at: now)
        }
    }

    private static func stopRunningEntry(_ db: Database, at now: Date) throws {
        guard var running = try TimeEntry.runningRequest().fetchOne(db) else { return }
        running.endAt = now
        running.updatedAt = now
        try running.update(db)
    }

    /// Atomično menja running entry (re-fetch unutar transakcije — bez stale snapshot-a);
    /// no-op ako ništa ne radi (npr. timer zaustavljen u međuvremenu).
    public func updateRunning(now: Date = Date(), _ mutate: (inout TimeEntry) -> Void) throws {
        try write { db in
            guard var running = try TimeEntry.runningRequest().fetchOne(db) else { return }
            mutate(&running)
            running.updatedAt = now
            try running.update(db)
        }
    }

    public func fetchRunning() throws -> TimeEntry? {
        try dbQueue.read { db in try TimeEntry.runningRequest().fetchOne(db) }
    }

    public func save(_ entry: TimeEntry, now: Date = Date()) throws {
        var entry = entry
        entry.updatedAt = now
        try write { db in try entry.update(db) }
    }

    public func delete(_ entry: TimeEntry) throws {
        guard let id = entry.id else { return }
        try write { db in _ = try TimeEntry.deleteOne(db, key: id) }
    }

    /// Distinct nazivi projekata, najskorije korišćeni prvi.
    public func projectSuggestions(limit: Int = 50) throws -> [String] {
        try dbQueue.read { db in
            try String.fetchAll(db, sql: """
                SELECT project FROM time_entry
                WHERE project <> ''
                GROUP BY project
                ORDER BY MAX(start_at) DESC
                LIMIT ?
                """, arguments: [limit])
        }
    }
}
