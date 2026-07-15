import SwiftUI
import WorkHronosKit

struct WeekHistoryView: View {
    @EnvironmentObject var store: AppStore
    @State private var editingEntry: TimeEntry?

    var body: some View {
        VStack(spacing: 0) {
            weekHeader
                .padding(.horizontal)
                .padding(.vertical, 8)
            Divider()
            if store.groups.isEmpty {
                emptyState
            } else {
                groupList
            }
        }
        .sheet(item: $editingEntry) { entry in
            EntryEditSheet(entry: entry)
        }
    }

    private var weekHeader: some View {
        HStack(spacing: 8) {
            Button { store.previousWeek() } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.borderless)
            Button { store.nextWeek() } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.borderless)
            Text(weekLabel)
                .font(.callout.weight(.medium))
                .onTapGesture { store.goToCurrentWeek() }
                .help("Click to jump to the current week")
            Spacer()
            Text(DurationFormat.format(store.weekTotal))
                .font(.callout.monospacedDigit().weight(.semibold))
        }
    }

    private var weekLabel: String {
        let interval = store.weekInterval
        let lastDay = interval.end.addingTimeInterval(-1)
        let formatter = DateIntervalFormatter()
        formatter.dateTemplate = "MMM d"
        let range = formatter.string(from: interval.start, to: lastDay)
        let week = store.calendar.component(.weekOfYear, from: interval.start)
        return "\(range) · W\(week)"
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
            ForEach(store.groups) { group in
                DisclosureGroup {
                    ForEach(group.entries) { entry in
                        entryRow(entry)
                    }
                } label: {
                    groupLabel(group)
                }
            }
        }
        .listStyle(.inset)
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
            Text(entry.startAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
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
    }

    private func timeRange(_ entry: TimeEntry) -> String {
        let start = entry.startAt.formatted(date: .omitted, time: .shortened)
        let end = entry.endAt?.formatted(date: .omitted, time: .shortened) ?? "…"
        return "\(start) – \(end)"
    }
}
