import SwiftUI
import WorkHronosKit

struct EntryEditSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let entry: TimeEntry
    @State private var project: String
    @State private var start: Date
    @State private var end: Date
    @State private var durationText: String
    @State private var confirmingDelete = false

    init(entry: TimeEntry) {
        self.entry = entry
        _project = State(initialValue: entry.project)
        _start = State(initialValue: entry.startAt)
        _end = State(initialValue: entry.endAt ?? Date())
        _durationText = State(initialValue: DurationFormat.format(entry.duration()))
    }

    private var isValid: Bool { end >= start }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit Entry")
                .font(.headline)

            Form {
                TextField("Project", text: $project)
                DatePicker("Date", selection: dateBinding, displayedComponents: [.date])
                DatePicker("Start", selection: $start, displayedComponents: [.hourAndMinute])
                DatePicker("End", selection: $end, displayedComponents: [.hourAndMinute])
                TextField("Duration", text: $durationText)
                    .font(.body.monospacedDigit())
                    .onSubmit(commitDuration)
            }
            .onChange(of: start) { _, _ in refreshDurationText() }
            .onChange(of: end) { _, _ in refreshDurationText() }

            if !isValid {
                Text("End must be after start.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Text("Delete")
                }
                .confirmationDialog("Delete this entry?", isPresented: $confirmingDelete) {
                    Button("Delete", role: .destructive) {
                        store.delete(entry)
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 340)
    }

    /// Toggl semantika: promena datuma pomera i start i end za isti broj dana (duration očuvan).
    private var dateBinding: Binding<Date> {
        Binding(
            get: { start },
            set: { newDate in
                let calendar = store.calendar
                let delta = calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: start),
                    to: calendar.startOfDay(for: newDate)
                ).day ?? 0
                guard delta != 0 else { return }
                start = calendar.date(byAdding: .day, value: delta, to: start)!
                end = calendar.date(byAdding: .day, value: delta, to: end)!
            }
        )
    }

    /// Toggl semantika: edit trajanja drži start, pomera end.
    private func commitDuration() {
        guard let duration = DurationFormat.parse(durationText) else {
            refreshDurationText()
            return
        }
        end = start.addingTimeInterval(duration)
    }

    private func refreshDurationText() {
        durationText = DurationFormat.format(end.timeIntervalSince(start))
    }

    private func save() {
        commitDuration()
        guard isValid else { return }
        var updated = entry
        updated.project = project.trimmingCharacters(in: .whitespaces)
        updated.startAt = start
        updated.endAt = end
        store.save(updated)
        dismiss()
    }
}
