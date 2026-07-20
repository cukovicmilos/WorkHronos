import SwiftUI

@main
struct WorkHronosApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var root = RootModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(root)
        }
        .defaultSize(width: 420, height: 560)

        Window("Week Summary", id: "week-summary") {
            if case .ready(let store) = root.state {
                WeekSummaryView()
                    .environmentObject(store)
            }
        }
        .defaultSize(width: 360, height: 420)
    }
}

/// Van .app bundle-a (swift run) proces se diže kao background — bez Dock ikonice i fokusa.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // Ikonicu NE dirati odavde: ovaj callback stiže ~50ms POSLE ContentView.onAppear,
        // pa bi bezuslovno sivo pregazilo tačno stanje i ostalo takvo (onChange se ne okine
        // bez promene running-a). Svaka grana RootView-a sama postavlja svoju ikonicu.
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

struct RootView: View {
    @EnvironmentObject var root: RootModel

    var body: some View {
        Group {
            switch root.state {
            case .setup:
                SetupView()
                    .onAppear { DockIcon.update(running: false) }
            case .unavailable(let path, let message):
                DatabaseUnavailableView(path: path, message: message)
                    .onAppear { DockIcon.update(running: false) }
            case .ready(let store):
                ContentView()
                    .environmentObject(store)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            root.handleActivation()
        }
    }
}
