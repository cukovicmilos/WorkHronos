import Foundation
import GRDB

public enum AppDatabaseError: LocalizedError {
    case fileNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Database not found at \(path)"
        }
    }
}

public final class AppDatabase {
    public let path: String
    public let dbQueue: DatabaseQueue
    public private(set) var lastKnownSignature: FileSignature?

    /// Otvara (ili kreira, ako je `createIfMissing`) SQLite bazu na datoj putanji.
    /// Dropbox-friendly: DatabaseQueue + journal_mode=DELETE → jedan fajl na disku, bez -wal/-shm.
    public init(path: String, createIfMissing: Bool) throws {
        if !createIfMissing && !FileManager.default.fileExists(atPath: path) {
            throw AppDatabaseError.fileNotFound(path)
        }
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var config = Configuration()
        config.busyMode = .timeout(5)
        config.prepareDatabase { db in
            _ = try String.fetchOne(db, sql: "PRAGMA journal_mode = DELETE")
            try db.execute(sql: "PRAGMA synchronous = FULL")
        }

        self.path = path
        self.dbQueue = try DatabaseQueue(path: path, configuration: config)
        try Self.migrator.migrate(dbQueue)
        refreshFileSignature()
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.execute(sql: """
                CREATE TABLE time_entry (
                    id          INTEGER PRIMARY KEY AUTOINCREMENT,
                    project     TEXT    NOT NULL,
                    start_at    TEXT    NOT NULL,
                    end_at      TEXT,
                    created_at  TEXT    NOT NULL,
                    updated_at  TEXT    NOT NULL
                );
                CREATE INDEX idx_time_entry_start   ON time_entry(start_at);
                CREATE INDEX idx_time_entry_project ON time_entry(project);
                CREATE UNIQUE INDEX idx_one_running ON time_entry(ifnull(end_at, 0)) WHERE end_at IS NULL;
                """)
        }
        return migrator
    }

    // MARK: - External change detection

    public func refreshFileSignature() {
        lastKnownSignature = FileSignature.of(path: path)
    }

    public func hasExternalChange() -> Bool {
        FileSignature.of(path: path) != lastKnownSignature
    }

    public func close() throws {
        try dbQueue.close()
    }

    /// Write koji posle sebe osveži potpis fajla, da sopstvene izmene ne prijavimo kao eksterne.
    @discardableResult
    public func write<T>(_ updates: (Database) throws -> T) throws -> T {
        let result = try dbQueue.write(updates)
        refreshFileSignature()
        return result
    }
}
