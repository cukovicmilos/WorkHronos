import Foundation
import GRDB
import WorkHronosKit

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var running: TimeEntry?
    @Published private(set) var weekEntries: [TimeEntry] = []
    @Published private(set) var todayEntries: [TimeEntry] = []
    // didSet se okida i na dodelu iste vrednosti (npr. tap na label dok je već na tekućoj
    // nedelji) — bez guard-a to je nepotreban teardown + sinhroni re-fetch na main thread-u.
    @Published var selectedWeekStart: Date {
        didSet {
            guard oldValue != selectedWeekStart else { return }
            startWeekObservation()
        }
    }
    /// Week Summary prozor bira nedelju nezavisno od glavnog prozora.
    @Published var summaryWeekStart: Date {
        didSet {
            guard oldValue != summaryWeekStart else { return }
            startSummaryWeekObservation()
        }
    }
    @Published private(set) var summaryWeekEntries: [TimeEntry] = []
    @Published var errorMessage: String?

    private(set) var db: AppDatabase
    private var runningCancellable: AnyDatabaseCancellable?
    private var weekCancellable: AnyDatabaseCancellable?
    private var dayCancellable: AnyDatabaseCancellable?
    private var summaryWeekCancellable: AnyDatabaseCancellable?
    private var lastKnownCurrentWeekStart: Date
    private var lastKnownDayStart: Date

    let calendar = Calendar.iso8601

    init(db: AppDatabase) {
        self.db = db
        let currentWeekStart = WeekGrouping.weekInterval(containing: Date()).start
        self.selectedWeekStart = currentWeekStart
        self.summaryWeekStart = currentWeekStart
        self.lastKnownCurrentWeekStart = currentWeekStart
        self.lastKnownDayStart = Calendar.iso8601.startOfDay(for: Date())
        startObservations()
    }

    var weekInterval: DateInterval { interval(startingAt: selectedWeekStart) }
    var summaryWeekInterval: DateInterval { interval(startingAt: summaryWeekStart) }

    private func interval(startingAt start: Date) -> DateInterval {
        DateInterval(start: start, end: calendar.date(byAdding: .day, value: 7, to: start)!)
    }

    var days: [DayGroup] { WeekGrouping.days(from: weekEntries, calendar: calendar) }

    var weekLabel: String { label(for: weekInterval) }
    var summaryWeekLabel: String { label(for: summaryWeekInterval) }

    private func label(for interval: DateInterval) -> String {
        let lastDay = interval.end.addingTimeInterval(-1)
        let formatter = DateIntervalFormatter()
        formatter.dateTemplate = "MMM d"
        let range = formatter.string(from: interval.start, to: lastDay)
        let week = calendar.component(.weekOfYear, from: interval.start)
        return "\(range) · W\(week)"
    }

    /// Zbirni pregled nedelje: grupe po projektu (bez dana), abecedno po imenu projekta.
    /// Running timer se uračunava ako je startovao u toj nedelji, kao u weekTotal.
    func weekSummaryGroups() -> [ProjectGroup] {
        var entries = summaryWeekEntries
        let interval = summaryWeekInterval
        if let running, running.startAt >= interval.start, running.startAt < interval.end {
            entries.append(running)
        }
        return WeekGrouping.groups(from: entries)
            .sorted { $0.project.localizedCaseInsensitiveCompare($1.project) == .orderedAscending }
    }

    /// Total nedelje prikazane u Week Summary prozoru.
    func summaryWeekTotal(asOf now: Date = Date()) -> TimeInterval {
        var total = summaryWeekEntries.reduce(0) { $0 + $1.duration() }
        let interval = summaryWeekInterval
        if let running, running.startAt >= interval.start, running.startAt < interval.end {
            total += running.duration(asOf: now)
        }
        return total
    }

    /// Total nedelje; running timer se uračunava ako je startovao u izabranoj nedelji (Toggl).
    func weekTotal(asOf now: Date = Date()) -> TimeInterval {
        var total = weekEntries.reduce(0) { $0 + $1.duration() }
        // ista half-open granica kao stoppedRequest (DateInterval.contains je inclusive na end)
        if let running, running.startAt >= weekInterval.start, running.startAt < weekInterval.end {
            total += running.duration(asOf: now)
        }
        return total
    }

    /// Total danas; entry pripada danu svog starta, running se uračunava ako je startovao danas.
    func todayTotal(asOf now: Date = Date()) -> TimeInterval {
        var total = todayEntries.reduce(0) { $0 + $1.duration() }
        if let running, running.startAt >= calendar.startOfDay(for: now) {
            total += running.duration(asOf: now)
        }
        return total
    }

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
        startDayObservation()
        startSummaryWeekObservation()
    }

    private func startDayObservation() {
        let dayStart = calendar.startOfDay(for: Date())
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let interval = DateInterval(start: dayStart, end: dayEnd)
        let observation = ValueObservation.tracking { db in
            try TimeEntry.stoppedRequest(in: interval).fetchAll(db)
        }
        dayCancellable = observation.start(
            in: db.dbQueue,
            scheduling: .immediate,
            onError: { [weak self] error in self?.errorMessage = error.localizedDescription },
            onChange: { [weak self] entries in self?.todayEntries = entries }
        )
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

    private func startSummaryWeekObservation() {
        let interval = summaryWeekInterval
        let observation = ValueObservation.tracking { db in
            try TimeEntry.stoppedRequest(in: interval).fetchAll(db)
        }
        summaryWeekCancellable = observation.start(
            in: db.dbQueue,
            scheduling: .immediate,
            onError: { [weak self] error in self?.errorMessage = error.localizedDescription },
            onChange: { [weak self] entries in self?.summaryWeekEntries = entries }
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
        guard running != nil, let duration = DurationFormat.parse(text) else { return false }
        perform { try db.updateRunning { $0.startAt = Date().addingTimeInterval(-duration) } }
        return true
    }

    /// Ručni unos: zabeleži završen interval koji se završava sada.
    func addManualEntry(project: String, duration: TimeInterval) {
        let end = Date()
        perform {
            try db.addCompletedEntry(
                project: project.trimmingCharacters(in: .whitespaces),
                start: end.addingTimeInterval(-duration),
                end: end
            )
        }
    }

    func renameRunning(to name: String) {
        perform { try db.updateRunning { $0.project = name } }
    }

    // MARK: - Entry editing

    func save(_ entry: TimeEntry) {
        perform { try db.save(entry) }
    }

    func delete(_ entry: TimeEntry) {
        perform { try db.delete(entry) }
    }

    func deleteProject(named project: String) {
        perform { try db.deleteAllEntries(project: project) }
    }

    /// nil kada count nije pouzdan (DB greška) — UI tada ne prikazuje broj.
    func entryCount(project: String) -> Int? {
        try? db.entryCount(project: project)
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

    func previousSummaryWeek() { shiftSummaryWeek(by: -1) }
    func nextSummaryWeek() { shiftSummaryWeek(by: 1) }

    func goToCurrentSummaryWeek() {
        summaryWeekStart = WeekGrouping.weekInterval(containing: Date(), calendar: calendar).start
    }

    private func shiftSummaryWeek(by weeks: Int) {
        summaryWeekStart = calendar.date(byAdding: .weekOfYear, value: weeks, to: summaryWeekStart)!
    }

    // MARK: - Autocomplete

    func suggestions(matching text: String) -> [String] {
        let query = text.trimmingCharacters(in: .whitespaces).lowercased()
        // Prazno polje ne otvara listu — suggestion-i se prikazuju samo dok korisnik kuca.
        guard !query.isEmpty else { return [] }
        let all = (try? db.projectSuggestions()) ?? []
        let matches = all.filter { $0.lowercased().contains(query) && $0.lowercased() != query }
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
            dayCancellable?.cancel()
            dayCancellable = nil
            summaryWeekCancellable?.cancel()
            summaryWeekCancellable = nil
            try? db.close()
            db = newDb
            startObservations()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Ako je app otvoren preko ponoći / ponedeljka 00:00, "danas" i "tekuća" nedelja
    /// se pomeraju sa realnim vremenom. Pozivač: 1s tick u TimerBarView (uvek mount-ovan).
    func rollDateIfNeeded() {
        let actualWeek = WeekGrouping.weekInterval(containing: Date(), calendar: calendar).start
        if actualWeek != lastKnownCurrentWeekStart {
            // Oba prozora prate novu nedelju samo ako nisu ručno odlutali sa tekuće.
            if selectedWeekStart == lastKnownCurrentWeekStart {
                selectedWeekStart = actualWeek
            }
            if summaryWeekStart == lastKnownCurrentWeekStart {
                summaryWeekStart = actualWeek
            }
            lastKnownCurrentWeekStart = actualWeek
        }

        let actualDay = calendar.startOfDay(for: Date())
        if actualDay != lastKnownDayStart {
            lastKnownDayStart = actualDay
            startDayObservation()
        }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
