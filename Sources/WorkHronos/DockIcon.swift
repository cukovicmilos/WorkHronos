import AppKit

/// Menja Dock ikonicu prema stanju timer-a: u boji dok vreme ide, siva dok stoji.
/// U dev modu (`swift run`, bez bundle Resources) učitavanje vraća nil i update je no-op.
@MainActor
enum DockIcon {
    private static let active = load("AppIcon")
    private static let idle = load("AppIcon-Idle")

    static func update(running: Bool) {
        guard let image = running ? active : idle else { return }
        NSApp.applicationIconImage = image
    }

    private static func load(_ name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "icns") else { return nil }
        return NSImage(contentsOf: url)
    }
}
