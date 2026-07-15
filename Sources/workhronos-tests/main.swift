// Mini test runner — CLT nema XCTest/Testing module, pa testovi žive u executable targetu.
// Pokretanje: swift run workhronos-tests  (ili: make test)
import Foundation
import GRDB
import WorkHronosKit

var failures = 0
var checks = 0

func expect(_ condition: Bool, _ label: String, file: StaticString = #file, line: UInt = #line) {
    checks += 1
    if !condition {
        failures += 1
        print("FAIL [\(file):\(line)] \(label)")
    }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String,
                               file: StaticString = #file, line: UInt = #line) {
    expect(actual == expected, "\(label) — expected \(expected), got \(actual)", file: file, line: line)
}

func expectNil<T>(_ value: T?, _ label: String, file: StaticString = #file, line: UInt = #line) {
    expect(value == nil, "\(label) — expected nil, got \(String(describing: value))", file: file, line: line)
}

func expectClose(_ actual: TimeInterval, _ expected: TimeInterval, accuracy: TimeInterval, _ label: String,
                 file: StaticString = #file, line: UInt = #line) {
    expect(abs(actual - expected) <= accuracy, "\(label) — expected \(expected)±\(accuracy), got \(actual)",
           file: file, line: line)
}

func expectThrows(_ label: String, file: StaticString = #file, line: UInt = #line, _ body: () throws -> Void) {
    do {
        try body()
        failures += 1
        checks += 1
        print("FAIL [\(file):\(line)] \(label) — expected error, none thrown")
    } catch {
        checks += 1
    }
}

func withTempDatabase(_ body: (AppDatabase, URL) throws -> Void) throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("workhronos-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let db = try AppDatabase(path: dir.appendingPathComponent("test.sqlite").path, createIfMissing: true)
    try body(db, dir)
    try? db.close()
}

// MARK: - DurationFormat

func testDurationFormat() {
    expectEqual(DurationFormat.format(0), "0:00:00", "format 0")
    expectEqual(DurationFormat.format(59), "0:00:59", "format 59")
    expectEqual(DurationFormat.format(60), "0:01:00", "format 60")
    expectEqual(DurationFormat.format(4517), "1:15:17", "format 4517")
    expectEqual(DurationFormat.format(36_000), "10:00:00", "format 36000")
    expectEqual(DurationFormat.format(-5), "0:00:00", "format negativan")

    expectEqual(DurationFormat.parse("1:30:45"), 5445, "parse h:mm:ss")
    expectEqual(DurationFormat.parse("0:00:30"), 30, "parse 0:00:30")
    expectEqual(DurationFormat.parse("1:30"), 5400, "parse h:mm (Toggl)")
    expectEqual(DurationFormat.parse("10:05"), 36_300, "parse 10:05")
    expectNil(DurationFormat.parse("1:75"), "parse 1:75 nevalidan")
    expectNil(DurationFormat.parse("1:10:75"), "parse 1:10:75 nevalidan")
    expectNil(DurationFormat.parse("1:2:3:4"), "parse 4 dela nevalidan")
    expectNil(DurationFormat.parse("a:30"), "parse a:30 nevalidan")
    expectNil(DurationFormat.parse("1:"), "parse '1:' nevalidan")

    expectEqual(DurationFormat.parse("90"), 5400, "parse 90 = minuti")
    expectEqual(DurationFormat.parse("0"), 0, "parse 0")
    expectEqual(DurationFormat.parse("1.5"), 90, "parse 1.5 min")
    expectEqual(DurationFormat.parse("1,5"), 90, "parse 1,5 min")

    expectEqual(DurationFormat.parse("1h 30m"), 5400, "parse 1h 30m")
    expectEqual(DurationFormat.parse("1h30m"), 5400, "parse 1h30m")
    expectEqual(DurationFormat.parse("45m"), 2700, "parse 45m")
    expectEqual(DurationFormat.parse("2h"), 7200, "parse 2h")
    expectEqual(DurationFormat.parse("30s"), 30, "parse 30s")
    expectEqual(DurationFormat.parse("1.5h"), 5400, "parse 1.5h")
    expectEqual(DurationFormat.parse("1h 2m 3s"), 3723, "parse 1h 2m 3s")
    expectNil(DurationFormat.parse("h"), "parse 'h' nevalidan")
    expectNil(DurationFormat.parse("xyz"), "parse xyz nevalidan")
    expectNil(DurationFormat.parse(""), "parse prazan")
    expectNil(DurationFormat.parse("   "), "parse whitespace")
}

// MARK: - AppDatabase

func testCreateAndReopen() throws {
    try withTempDatabase { db, dir in
        expect(FileManager.default.fileExists(atPath: db.path), "fajl kreiran")
        try db.close()
        _ = try AppDatabase(path: db.path, createIfMissing: false)
    }
}

func testOpenMissingFileThrows() {
    expectThrows("otvaranje nepostojećeg fajla mora da baci grešku") {
        _ = try AppDatabase(path: "/nonexistent-dir-xyz/missing.sqlite", createIfMissing: false)
    }
}

func testJournalModeDeleteAndNoSidecars() throws {
    try withTempDatabase { db, _ in
        let mode = try db.dbQueue.read { try String.fetchOne($0, sql: "PRAGMA journal_mode") }
        expectEqual(mode?.lowercased(), "delete", "journal_mode")

        try db.startTimer(project: "test")
        try db.close()

        expect(!FileManager.default.fileExists(atPath: db.path + "-wal"), "nema -wal")
        expect(!FileManager.default.fileExists(atPath: db.path + "-shm"), "nema -shm")
        expect(!FileManager.default.fileExists(atPath: db.path + "-journal"), "nema -journal posle close")
    }
}

func testStartStopTimer() throws {
    try withTempDatabase { db, _ in
        let started = try db.startTimer(project: "alpha")
        expect(started.id != nil, "insert dodeljuje id")
        expect(started.isRunning, "novi timer radi")
        expectEqual(try db.fetchRunning()?.project, "alpha", "running fetch")

        try db.stopRunning()
        expectNil(try db.fetchRunning(), "posle stop nema running")

        let all = try db.dbQueue.read { try TimeEntry.fetchAll($0) }
        expectEqual(all.count, 1, "jedan entry")
        expect(all[0].endAt != nil, "end_at popunjen")
    }
}

func testStartingNewTimerStopsPrevious() throws {
    try withTempDatabase { db, _ in
        try db.startTimer(project: "alpha")
        try db.startTimer(project: "beta")
        expectEqual(try db.fetchRunning()?.project, "beta", "novi timer radi")
        let all = try db.dbQueue.read { try TimeEntry.fetchAll($0) }
        expectEqual(all.count, 2, "dva entry-ja")
        expectEqual(all.filter(\.isRunning).count, 1, "tačno jedan running")
    }
}

func testOnlyOneRunningEnforcedByIndex() throws {
    try withTempDatabase { db, _ in
        let now = Date()
        expectThrows("unique partial index mora da spreči dva running entry-ja") {
            try db.write { dbc in
                var first = TimeEntry(project: "a", startAt: now, createdAt: now, updatedAt: now)
                try first.insert(dbc)
                var second = TimeEntry(project: "b", startAt: now, createdAt: now, updatedAt: now)
                try second.insert(dbc)
            }
        }
    }
}

func testDurationEditShiftsStart() throws {
    try withTempDatabase { db, _ in
        var entry = try db.startTimer(project: "alpha")
        let now = Date()
        entry.startAt = now.addingTimeInterval(-3600)
        try db.save(entry)
        expectClose(try db.fetchRunning()!.duration(asOf: now), 3600, accuracy: 1, "duration edit pomera start")
    }
}

func testWeekRequestFiltersAndSorts() throws {
    try withTempDatabase { db, _ in
        let calendar = Calendar.iso8601
        let thisWeek = WeekGrouping.weekInterval(containing: Date(), calendar: calendar)
        let lastWeekDay = calendar.date(byAdding: .day, value: -3, to: thisWeek.start)!

        try db.write { dbc in
            var old = TimeEntry(project: "old", startAt: lastWeekDay,
                                endAt: lastWeekDay.addingTimeInterval(1800),
                                createdAt: lastWeekDay, updatedAt: lastWeekDay)
            try old.insert(dbc)
            var current = TimeEntry(project: "new", startAt: thisWeek.start.addingTimeInterval(3600),
                                    endAt: thisWeek.start.addingTimeInterval(7200),
                                    createdAt: Date(), updatedAt: Date())
            try current.insert(dbc)
        }
        try db.startTimer(project: "running")

        let thisWeekEntries = try db.dbQueue.read { try TimeEntry.stoppedRequest(in: thisWeek).fetchAll($0) }
        expectEqual(thisWeekEntries.map(\.project), ["new"], "ova nedelja bez running entry-ja")

        let lastWeek = WeekGrouping.weekInterval(containing: lastWeekDay, calendar: calendar)
        let lastWeekEntries = try db.dbQueue.read { try TimeEntry.stoppedRequest(in: lastWeek).fetchAll($0) }
        expectEqual(lastWeekEntries.map(\.project), ["old"], "prošla nedelja")
    }
}

func testGrouping() {
    let now = Date()
    func entry(_ project: String, offset: TimeInterval, duration: TimeInterval) -> TimeEntry {
        TimeEntry(project: project, startAt: now.addingTimeInterval(offset),
                  endAt: now.addingTimeInterval(offset + duration),
                  createdAt: now, updatedAt: now)
    }
    let groups = WeekGrouping.groups(from: [
        entry("a", offset: -7200, duration: 600),
        entry("b", offset: -3600, duration: 300),
        entry("a", offset: -1800, duration: 900),
    ])
    expectEqual(groups.map(\.project), ["a", "b"], "grupe po najskorijem entry-ju")
    expectClose(groups[0].totalSeconds, 1500, accuracy: 0.5, "total grupe")
    expectEqual(groups[0].entries.count, 2, "broj entry-ja u grupi")
    expectClose(groups[0].entries[0].duration(), 900, accuracy: 0.5, "najskoriji entry prvi u grupi")
}

func testProjectSuggestionsRecencyOrdered() throws {
    try withTempDatabase { db, _ in
        let now = Date()
        try db.write { dbc in
            for (project, offset) in [("alpha", -7200.0), ("beta", -3600.0), ("alpha", -1800.0), ("gamma", -600.0)] {
                var e = TimeEntry(project: project, startAt: now.addingTimeInterval(offset),
                                  endAt: now.addingTimeInterval(offset + 60),
                                  createdAt: now, updatedAt: now)
                try e.insert(dbc)
            }
        }
        expectEqual(try db.projectSuggestions(), ["gamma", "alpha", "beta"], "suggestions po recency")
    }
}

func testExternalChangeDetection() throws {
    try withTempDatabase { db, dir in
        try db.startTimer(project: "x")
        expect(!db.hasExternalChange(), "posle sopstvenog write-a nema external change")

        // simulacija Dropbox sync-a: zameni fajl kopijom (novi inode)
        let copy = dir.appendingPathComponent("copy.sqlite").path
        try FileManager.default.copyItem(atPath: db.path, toPath: copy)
        try FileManager.default.removeItem(atPath: db.path)
        try FileManager.default.moveItem(atPath: copy, toPath: db.path)

        expect(db.hasExternalChange(), "zamena fajla detektovana")
    }
}

// MARK: - Run

let tests: [(String, () throws -> Void)] = [
    ("DurationFormat", testDurationFormat),
    ("CreateAndReopen", testCreateAndReopen),
    ("OpenMissingFileThrows", testOpenMissingFileThrows),
    ("JournalModeDeleteAndNoSidecars", testJournalModeDeleteAndNoSidecars),
    ("StartStopTimer", testStartStopTimer),
    ("StartingNewTimerStopsPrevious", testStartingNewTimerStopsPrevious),
    ("OnlyOneRunningEnforcedByIndex", testOnlyOneRunningEnforcedByIndex),
    ("DurationEditShiftsStart", testDurationEditShiftsStart),
    ("WeekRequestFiltersAndSorts", testWeekRequestFiltersAndSorts),
    ("Grouping", testGrouping),
    ("ProjectSuggestionsRecencyOrdered", testProjectSuggestionsRecencyOrdered),
    ("ExternalChangeDetection", testExternalChangeDetection),
]

for (name, test) in tests {
    do {
        try test()
        print("ok   \(name)")
    } catch {
        failures += 1
        print("FAIL \(name) — threw \(error)")
    }
}

print("\n\(checks) checks, \(failures) failures")
exit(failures == 0 ? 0 : 1)
