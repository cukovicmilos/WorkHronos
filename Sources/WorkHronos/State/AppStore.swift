import Foundation
import GRDB
import WorkHronosKit

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var running: TimeEntry?
    @Published private(set) var weekEntries: [TimeEntry] = []
    @Published var selectedWeekStart: Date {
        didSet { startWeekObservation() }
    }
    @Published var errorMessage: String?

    private(set) var db: AppDatabase
    private var runningCancellable: AnyDatabaseCancellable?
    private var weekCancellable: AnyDatabaseCancellable?
    private var lastKnownCurrentWeekStart: Date

    let calendar = Calendar.iso8601

    init(db: AppDatabase) {
        self.db = db
        let currentWeekStart = WeekGrouping.weekInterval(containing: Date()).start
        self.selectedWeekStart = currentWeekStart
        self.lastKnownCurrentWeekStart = currentWeekStart
        startObservations()
    }

    var weekInterval: DateInterval {
        let end = calendar.date(byAdding: .day, value: 7, to: selectedWeekStart)!
        return DateInterval(start: selectedWeekStart, end: end)
    }

    var groups: [ProjectGroup] { WeekGrouping.groups(from: weekEntries) }

    var weekTotal: TimeInterval { weekEntries.reduce(0) { $0 + $1.duration() } }

    // MARK: - Observations

    private func startObservations() {
        let runningObservation = ValueObservation.tracking { db in
            try TimeEntry.runningRequest().fetchOne(db)
        }
        runningCancellable = runningObservation.start(
            in: db.dbQueue,
            scheduling: .immediate,
            onError: { [weak self] error in self?.errorMessage = error.localizedDescription },
            onChange: { [weak self] entry in self?.running = entry }
        )
        startWeekObservation()
    }

    private func startWeekObservation() {
        let interval = weekInterval
        let observation = ValueObservation.tracking { db in
            try TimeEntry.stoppedRequest(in: interval).fetchAll(db)
        }
        weekCancellable = observation.start(
            in: db.dbQueue,
            scheduling: .immediate,
            onError: { [weak self] error in self?.errorMessage = error.localizedDescription },
            onChange: { [weak self] entries in self?.weekEntries = entries }
        )
    }

    // MARK: - Timer actions

    func start(project: String) {
        perform { try db.startTimer(project: project.trimmingCharacters(in: .whitespaces)) }
    }

    func stop() {
        perform { try db.stopRunning() }
    }

    /// Toggl semantika: edit trajanja dok timer radi pomera start_at unazad.
    @discardableResult
    func setRunningDuration(_ text: String) -> Bool {
        guard let running, let duration = DurationFormat.parse(text) else { return false }
        var entry = running
        entry.startAt = Date().addingTimeInterval(-duration)
        perform { try db.save(entry) }
        return true
    }

    func setRunningStart(_ date: Date) {
        guard let running else { return }
        var entry = running
        // Toggl semantika: start "posle sada" znači prethodni dan, ne clamp na now.
        entry.startAt = date > Date() ? calendar.date(byAdding: .day, value: -1, to: date)! : date
        perform { try db.save(entry) }
    }

    // MARK: - Entry editing

    func save(_ entry: TimeEntry) {
        perform { try db.save(entry) }
    }

    func delete(_ entry: TimeEntry) {
        perform { try db.delete(entry) }
    }

    // MARK: - Week navigation

    func previousWeek() { shiftWeek(by: -1) }
    func nextWeek() { shiftWeek(by: 1) }

    func goToCurrentWeek() {
        selectedWeekStart = WeekGrouping.weekInterval(containing: Date(), calendar: calendar).start
    }

    private func shiftWeek(by weeks: Int) {
        selectedWeekStart = calendar.date(byAdding: .weekOfYear, value: weeks, to: selectedWeekStart)!
    }

    // MARK: - Autocomplete

    func suggestions(matching text: String) -> [String] {
        let all = (try? db.projectSuggestions()) ?? []
        let query = text.trimmingCharacters(in: .whitespaces).lowercased()
        let matches = query.isEmpty
            ? all
            : all.filter { $0.lowercased().contains(query) && $0.lowercased() != query }
        return Array(matches.prefix(8))
    }

    // MARK: - External changes (Dropbox)

    func reopenIfChangedExternally() {
        guard db.hasExternalChange() else { return }
        // Fajl privremeno ne postoji (Dropbox usred sync-a) — stari handle i dalje radi,
        // pokušaćemo ponovo na sledeću aktivaciju.
        guard FileManager.default.fileExists(atPath: db.path) else { return }
        do {
            // Prvo otvori novu bazu; staru zatvaramo tek po uspehu, da store nikad
            // ne ostane sa zatvorenim queue-om.
            let newDb = try AppDatabase(path: db.path, createIfMissing: false)
            runningCancellable?.cancel()
            runningCancellable = nil
            weekCancellable?.cancel()
            weekCancellable = nil
            try? db.close()
            db = newDb
            startObservations()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Ako je app otvoren preko ponedeljka 00:00, "tekuća" nedelja se pomera sa realnim vremenom.
    func rollWeekIfNeeded() {
        let actual = WeekGrouping.weekInterval(containing: Date(), calendar: calendar).start
        guard actual != lastKnownCurrentWeekStart else { return }
        if selectedWeekStart == lastKnownCurrentWeekStart {
            selectedWeekStart = actual
        }
        lastKnownCurrentWeekStart = actual
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
