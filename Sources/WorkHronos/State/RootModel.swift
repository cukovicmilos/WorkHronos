import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WorkHronosKit

enum Settings {
    // Eksplicitni suite: swift run (bez bundle id) i .app inače koriste različite plist domene.
    static let defaults = UserDefaults(suiteName: "com.orff.workhronos") ?? .standard

    static var databasePath: String? {
        get { defaults.string(forKey: "databasePath") }
        set { defaults.set(newValue, forKey: "databasePath") }
    }
}

@MainActor
final class RootModel: ObservableObject {
    enum AppState {
        case setup
        case unavailable(path: String, message: String)
        case ready(AppStore)
    }

    @Published var state: AppState = .setup

    static let defaultPath = NSString(
        string: "~/Library/Application Support/WorkHronos/workhronos.sqlite"
    ).expandingTildeInPath

    init() {
        openStored()
    }

    func openStored() {
        guard let path = Settings.databasePath else {
            state = .setup
            return
        }
        // Nikad tiho ne kreirati novu bazu na sačuvanoj putanji — to fork-uje podatke
        // (npr. Dropbox još nije sync-ovao fajl).
        open(path: path, createIfMissing: false)
    }

    func useDefaultLocation() {
        open(path: Self.defaultPath, createIfMissing: true)
    }

    func chooseNewFile() {
        let panel = NSSavePanel()
        panel.title = "Create Database"
        panel.nameFieldStringValue = "workhronos.sqlite"
        panel.canCreateDirectories = true
        if let type = UTType(filenameExtension: "sqlite") {
            panel.allowedContentTypes = [type]
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // Save panel je već tražio potvrdu zamene — "Create" preko postojećeg fajla
        // mora da krene od prazne baze, ne da tiho otvori staru.
        try? FileManager.default.removeItem(at: url)
        open(path: url.path, createIfMissing: true)
    }

    func openExistingFile() {
        let panel = NSOpenPanel()
        panel.title = "Open Database"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(path: url.path, createIfMissing: false)
    }

    private func open(path: String, createIfMissing: Bool) {
        do {
            let db = try AppDatabase(path: path, createIfMissing: createIfMissing)
            Settings.databasePath = path
            state = .ready(AppStore(db: db))
        } catch {
            state = .unavailable(path: path, message: error.localizedDescription)
        }
    }

    /// Na aktivaciju aplikacije: ako je Dropbox zamenio fajl (novi inode/mtime), reopen baze.
    func handleActivation() {
        if case .ready(let store) = state {
            store.reopenIfChangedExternally()
        }
    }
}
