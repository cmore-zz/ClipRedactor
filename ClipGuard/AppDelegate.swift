import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var clipboardWatcher: ClipboardWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        clipboardWatcher = ClipboardWatcher()
        clipboardWatcher?.start()
    }
}