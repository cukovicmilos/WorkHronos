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

    /// Ručni unos već završenog intervala (bez start/stop) — Toggl manual mode.
    @discardableResult
    public func addCompletedEntry(project: String, start: Date, end: Date,
                                  now: Date = Date()) throws -> TimeEntry {
        try write { db in
            var entry = TimeEntry(project: project, startAt: start, endAt: end,
                                  createdAt: now, updatedAt: now)
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

    /// Broj svih entry-ja projekta (kroz sve nedelje).
    public func entryCount(project: String) throws -> Int {
        try dbQueue.read { db in
            try TimeEntry.filter(Column("project") == project).fetchCount(db)
        }
    }

    /// Briše sve entry-je projekta (uključujući eventualni running).
    public func deleteAllEntries(project: String) throws {
        try write { db in
            _ = try TimeEntry.filter(Column("project") == project).deleteAll(db)
        }
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
