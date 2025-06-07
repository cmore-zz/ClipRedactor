import AppKit

class ClipboardManager {
    static let shared = ClipboardManager()
    private var lastOriginal: String?

    func storeOriginal(_ text: String) {
        lastOriginal = text
        print("Setting lastOriginal: \(String(describing: lastOriginal))")
    }

    func restoreLastPreRedactionValue() {
        print("restoreLastPreRedactionValue")
        guard let text = lastOriginal else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        ClipboardWatcher.shared?.updateChangeCount()
        print("Restoring lastOriginal: \(String(describing: lastOriginal))")
    }
}
