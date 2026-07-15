import SwiftUI

struct SetupView: View {
    @EnvironmentObject var root: RootModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Welcome to WorkHronos")
                .font(.title2.bold())
            Text("Choose where to keep your time-tracking database. Pick a folder inside Dropbox to sync it between machines.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            VStack(spacing: 8) {
                Button("Use Default Location") { root.useDefaultLocation() }
                    .keyboardShortcut(.defaultAction)
                Button("Create Database…") { root.chooseNewFile() }
                Button("Open Existing…") { root.openExistingFile() }
            }
            .controlSize(.large)

            Text(RootModel.defaultPath)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(32)
        .frame(minWidth: 380, minHeight: 480)
    }
}

struct DatabaseUnavailableView: View {
    @EnvironmentObject var root: RootModel
    let path: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Database Unavailable")
                .font(.title2.bold())
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Text("If the file lives in Dropbox, it may not have synced yet.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack {
                Button("Retry") { root.openStored() }
                    .keyboardShortcut(.defaultAction)
                Button("Choose Again…") { root.openExistingFile() }
            }
            .controlSize(.large)
        }
        .padding(32)
        .frame(minWidth: 380, minHeight: 480)
    }
}
