import SwiftUI
import WorkHronosKit

/// Zbirni pregled nedelje: projekti sa ukupnim satima, bez grupisanja po danima.
/// Bira nedelju nezavisno od glavnog prozora (store drži zaseban summaryWeekStart).
struct WeekSummaryView: View {
    @EnvironmentObject var store: AppStore
    /// Marker "dokle sam stigao" pri prolasku kroz listu projekata.
    @State private var selectedProject: String?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let groups = store.weekSummaryGroups(asOf: context.date)
            VStack(spacing: 0) {
                header(asOf: context.date)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                Divider()
                if groups.isEmpty {
                    emptyState
                } else {
                    List(groups, selection: $selectedProject) { group in
                        row(group)
                    }
                    .listStyle(.inset)
                }
            }
        }
        .navigationTitle("Week Summary")
        // Marker "dokle sam stigao" važi za jednu nedelju — promena nedelje ga poništava.
        .onChange(of: store.summaryWeekStart) { selectedProject = nil }
    }

    private func header(asOf now: Date) -> some View {
        HStack(spacing: 8) {
            Button { store.previousSummaryWeek() } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.borderless)
                .accessibilityLabel("Previous week")
            Button { store.nextSummaryWeek() } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.borderless)
                .accessibilityLabel("Next week")
            Text(store.summaryWeekLabel)
                .font(.callout.weight(.medium))
                .onTapGesture { store.goToCurrentSummaryWeek() }
                .help("Click to jump to the current week")
            Spacer()
            (Text("Week: ").foregroundStyle(.secondary)
             + Text(DurationFormat.formatHoursMinutes(store.summaryWeekTotal(asOf: now))))
                .font(.callout.monospacedDigit().weight(.semibold))
                .lineLimit(1)
        }
    }

    private func row(_ group: ProjectGroup) -> some View {
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
        }
        .padding(.vertical, 2)
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
}
