import AppKit

@main
final class FixtureApp: NSObject, NSApplicationDelegate {
    private var window: NSWindow!

    static func main() {
        let app = NSApplication.shared
        let delegate = FixtureApp()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
        _ = delegate
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 240), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "mac-control-mcp fixture"
        let field = NSTextField(frame: NSRect(x: 30, y: 140, width: 300, height: 28))
        field.identifier = NSUserInterfaceItemIdentifier("fixture-input")
        field.placeholderString = "Fixture input"
        let button = NSButton(title: "Fixture action", target: self, action: #selector(press))
        button.frame = NSRect(x: 30, y: 90, width: 160, height: 32)
        button.identifier = NSUserInterfaceItemIdentifier("fixture-action")
        let secure = NSSecureTextField(frame: NSRect(x: 30, y: 40, width: 300, height: 28))
        secure.identifier = NSUserInterfaceItemIdentifier("fixture-password")
        secure.stringValue = "must-never-appear"
        window.contentView?.addSubview(field)
        window.contentView?.addSubview(button)
        window.contentView?.addSubview(secure)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func press() { window.title = "fixture-action-complete" }
}
