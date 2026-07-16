import SwiftUI
import WorkHronosKit

struct WeekHistoryView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.openWindow) private var openWindow
    @State private var editingEntry: TimeEntry?
    @State private var deletingEntry: TimeEntry?
    @State private var deletingProject: String?
    @State private var deletingProjectCount: Int?

    var body: some View {
        VStack(spacing: 0) {
            weekHeader
                .padding(.horizontal)
                .padding(.vertical, 8)
            Divider()
            if store.days.isEmpty {
                emptyState
            } else {
                groupList
            }
        }
        .sheet(item: $editingEntry) { entry in
            EntryEditSheet(entry: entry)
        }
        .confirmationDialog(
            "Delete this entry?",
            isPresented: Binding(
                get: { deletingEntry != nil },
                set: { if !$0 { deletingEntry = nil } }
            ),
            presenting: deletingEntry
        ) { entry in
            Button("Delete", role: .destructive) { store.delete(entry) }
        } message: { entry in
            Text("\(entry.project.isEmpty ? "(no project)" : entry.project) · \(DurationFormat.format(entry.duration()))")
        }
        .confirmationDialog(
            "Delete entire project?",
            isPresented: Binding(
                get: { deletingProject != nil },
                set: { if !$0 { deletingProject = nil } }
            ),
            presenting: deletingProject
        ) { project in
            Button(deletingProjectCount.map { "Delete \($0) entries" } ?? "Delete All Entries",
                   role: .destructive) {
                store.deleteProject(named: project)
            }
        } message: { project in
            Text("This permanently deletes all entries of \"\(project.isEmpty ? "(no project)" : project)\" across all weeks.")
        }
    }

    private var weekHeader: some View {
        HStack(spacing: 8) {
            Button { store.previousWeek() } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.borderless)
            Button { store.nextWeek() } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.borderless)
            Text(store.weekLabel)
                .font(.callout.weight(.medium))
                .onTapGesture { store.goToCurrentWeek() }
                .help("Click to jump to the current week")
            Button { openWindow(id: "week-summary") } label: {
                Image(systemName: "macwindow.on.rectangle")
            }
            .buttonStyle(.borderless)
            .help("Open week summary in a new window")
            .accessibilityLabel("Open week summary in a new window")
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                (Text("Today: ").foregroundStyle(.secondary)
                 + Text(DurationFormat.formatHoursMinutes(store.todayTotal(asOf: context.date)))
                 + Text("  Week: ").foregroundStyle(.secondary)
                 + Text(DurationFormat.formatHoursMinutes(store.weekTotal(asOf: context.date))))
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No entries this week")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var groupList: some View {
        List {
            ForEach(store.days) { day in
                Section {
                    ForEach(day.projects) { group in
                        DisclosureGroup {
                            ForEach(group.entries) { entry in
                                entryRow(entry)
                            }
                        } label: {
                            groupLabel(group)
                                .contextMenu {
                                    Button("Delete Project…", role: .destructive) {
                                        deletingProjectCount = store.entryCount(project: group.project)
                                        deletingProject = group.project
                                    }
                                }
                        }
                    }
                } header: {
                    dayHeader(day)
                }
            }
        }
        .listStyle(.inset)
    }

    private func dayHeader(_ day: DayGroup) -> some View {
        HStack {
            Text(day.dayStart.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
            Spacer()
            Text(DurationFormat.format(day.totalSeconds))
                .monospacedDigit()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    private func groupLabel(_ group: ProjectGroup) -> some View {
        HStack {
            Text(group.project.isEmpty ? "(no project)" : group.project)
                .fontWeight(.medium)
                .lineLimit(1)
            Text("\(group.entries.count)")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Capsule().fill(.quaternary))
            Spacer()
            Text(DurationFormat.format(group.totalSeconds))
                .font(.body.monospacedDigit())
            continueButton(project: group.project)
        }
    }

    /// Toggl "continue": startuje novi timer sa nazivom projekta iz liste.
    private func continueButton(project: String) -> some View {
        Button {
            store.start(project: project)
        } label: {
            Image(systemName: "play.circle")
                .foregroundStyle(.green)
        }
        .buttonStyle(.borderless)
        .help("Start timer for this project")
        .accessibilityLabel("Start timer for this project")
    }

    private func entryRow(_ entry: TimeEntry) -> some View {
        HStack {
            Text(timeRange(entry))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
            Text(DurationFormat.format(entry.duration()))
                .font(.callout.monospacedDigit())
            continueButton(project: entry.project)
        }
        .contentShape(Rectangle())
        .onTapGesture { editingEntry = entry }
        .contextMenu {
            Button("Edit…") { editingEntry = entry }
            Button("Delete", role: .destructive) { deletingEntry = entry }
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) { deletingEntry = entry }
        }
    }

    private func timeRange(_ entry: TimeEntry) -> String {
        let start = entry.startAt.formatted(date: .omitted, time: .shortened)
        let end = entry.endAt?.formatted(date: .omitted, time: .shortened) ?? "…"
        return "\(start) – \(end)"
    }
}
