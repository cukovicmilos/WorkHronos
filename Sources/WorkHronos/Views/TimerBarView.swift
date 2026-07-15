import SwiftUI
import WorkHronosKit

struct TimerBarView: View {
    @EnvironmentObject var store: AppStore

    @State private var projectText = ""
    @State private var elapsedText = "0:00:00"
    @State private var elapsedEdited = false
    @State private var suggestions: [String] = []
    @State private var highlightIndex: Int?
    @FocusState private var focus: Field?

    private enum Field { case project, elapsed }

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                projectField
                elapsedField
                startStopButton
            }
            .zIndex(10)   // suggestion overlay mora preko sadržaja ispod (kasniji siblings)
            if store.running != nil {
                startedAtRow
            }
        }
        .onReceive(tick) { _ in
            refreshElapsed()
            store.rollWeekIfNeeded()
        }
        .onChange(of: store.running) { _, running in
            if let running {
                projectText = running.project
            }
            refreshElapsed()
        }
        .onAppear {
            if let running = store.running {
                projectText = running.project
            }
            refreshElapsed()
        }
    }

    // MARK: - Project field + autocomplete

    private var projectField: some View {
        TextField("What are you working on?", text: $projectText)
            .textFieldStyle(.roundedBorder)
            .focused($focus, equals: .project)
            .onSubmit(handleProjectSubmit)
            .onChange(of: projectText) { _, text in
                guard focus == .project else { return }
                refreshSuggestions(for: text)
            }
            .onChange(of: focus) { old, new in
                if new == .project {
                    refreshSuggestions(for: projectText)
                } else {
                    dismissSuggestions()
                    if old == .project { commitProjectRename() }
                }
            }
            .onKeyPress(.downArrow) { moveHighlight(1) }
            .onKeyPress(.upArrow) { moveHighlight(-1) }
            .onKeyPress(.escape) {
                guard !suggestions.isEmpty else { return .ignored }
                dismissSuggestions()
                return .handled
            }
            .overlay(alignment: .topLeading) {
                if focus == .project && !suggestions.isEmpty {
                    ProjectAutocomplete(
                        suggestions: suggestions,
                        highlightIndex: highlightIndex,
                        onSelect: accept(suggestion:)
                    )
                    .offset(y: 26)
                }
            }
    }

    private func refreshSuggestions(for text: String) {
        suggestions = store.suggestions(matching: text)
        highlightIndex = nil
    }

    private func dismissSuggestions() {
        suggestions = []
        highlightIndex = nil
    }

    private func moveHighlight(_ delta: Int) -> KeyPress.Result {
        guard !suggestions.isEmpty else { return .ignored }
        if let current = highlightIndex {
            highlightIndex = (current + delta + suggestions.count) % suggestions.count
        } else {
            highlightIndex = delta > 0 ? 0 : suggestions.count - 1
        }
        return .handled
    }

    private func accept(suggestion: String) {
        projectText = suggestion
        dismissSuggestions()
    }

    private func handleProjectSubmit() {
        if let index = highlightIndex, suggestions.indices.contains(index) {
            accept(suggestion: suggestions[index])
            return
        }
        dismissSuggestions()
        if store.running == nil {
            store.start(project: projectText)
        } else {
            commitProjectRename()
        }
    }

    private func commitProjectRename() {
        guard let running = store.running else { return }
        let name = projectText.trimmingCharacters(in: .whitespaces)
        guard name != running.project else { return }
        store.renameRunning(to: name)
    }

    // MARK: - Elapsed field

    private var elapsedField: some View {
        TextField("0:00:00", text: $elapsedText)
            .textFieldStyle(.roundedBorder)
            .font(.body.monospacedDigit())
            .multilineTextAlignment(.center)
            .frame(minWidth: 82)
            .fixedSize(horizontal: true, vertical: false)
            .focused($focus, equals: .elapsed)
            .disabled(store.running == nil)
            .onSubmit {
                commitElapsed()
                elapsedEdited = false
                focus = nil
            }
            .onKeyPress(.escape) {
                elapsedEdited = false
                focus = nil
                return .handled
            }
            .onChange(of: elapsedText) { _, _ in
                if focus == .elapsed { elapsedEdited = true }
            }
            .onChange(of: focus) { old, new in
                if new == .elapsed { elapsedEdited = false }
                if old == .elapsed && new != .elapsed {
                    // Commit na blur samo ako je korisnik zaista kucao — inače bi
                    // ustajali tekst (tick pauzira tokom fokusa) pregazio praćeno vreme.
                    if elapsedEdited { commitElapsed() }
                    elapsedEdited = false
                    refreshElapsed()
                }
            }
    }

    private func commitElapsed() {
        if !store.setRunningDuration(elapsedText) {
            elapsedText = store.running.map { DurationFormat.format($0.duration()) } ?? "0:00:00"
        }
    }

    /// Tick ne prepisuje tekst dok je polje fokusirano (user upravo kuca novo trajanje).
    private func refreshElapsed() {
        guard focus != .elapsed else { return }
        if let running = store.running {
            elapsedText = DurationFormat.format(running.duration())
        } else {
            elapsedText = "0:00:00"
        }
    }

    // MARK: - Start/stop

    private var startStopButton: some View {
        Button {
            if store.running != nil {
                store.stop()
                projectText = ""
            } else {
                store.start(project: projectText)
            }
        } label: {
            Image(systemName: store.running != nil ? "stop.circle.fill" : "play.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(store.running != nil ? .red : .green)
        }
        .buttonStyle(.plain)
    }

    private var startedAtRow: some View {
        HStack(spacing: 4) {
            Text("started at")
                .font(.caption)
                .foregroundStyle(.secondary)
            DatePicker(
                "",
                selection: Binding(
                    get: { store.running?.startAt ?? Date() },
                    set: { store.setRunningStart($0) }
                ),
                displayedComponents: [.hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.field)
            .frame(width: 70)
        }
    }
}
