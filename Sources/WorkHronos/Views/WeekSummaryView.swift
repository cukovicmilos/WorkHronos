import SwiftUI
import WorkHronosKit

/// Zbirni pregled izabrane nedelje: projekti sa ukupnim satima, bez grupisanja po danima.
/// Prati nedelju izabranu u glavnom prozoru (deli isti AppStore).
struct WeekSummaryView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let groups = store.weekSummaryGroups()
            VStack(spacing: 0) {
                header(asOf: context.date)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                Divider()
                if groups.isEmpty {
                    emptyState
                } else {
                    List(groups) { group in
                        row(group)
                    }
                    .listStyle(.inset)
                }
            }
        }
        .navigationTitle("Week Summary")
    }

    private func header(asOf now: Date) -> some View {
        HStack {
            Text(store.weekLabel)
                .font(.callout.weight(.medium))
            Spacer()
            (Text("Week: ").foregroundStyle(.secondary)
             + Text(DurationFormat.formatHoursMinutes(store.weekTotal(asOf: now))))
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
