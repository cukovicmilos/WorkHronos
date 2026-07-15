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
    }
}

/// Van .app bundle-a (swift run) proces se diže kao background — bez Dock ikonice i fokusa.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
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
            case .unavailable(let path, let message):
                DatabaseUnavailableView(path: path, message: message)
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
