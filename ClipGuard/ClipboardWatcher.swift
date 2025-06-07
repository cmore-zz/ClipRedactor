import Foundation
import AppKit

class ClipboardWatcher {
    private let pasteboard = NSPasteboard.general
    private var changeCount: Int
    private var timer: Timer?

    init() {
        self.changeCount = pasteboard.changeCount
    }

    func start() {
        print("ClipGuard: Timer started")
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in

            self.checkPasteboard()
        }
    }

    private func checkPasteboard() {
        guard pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount
        if let content = pasteboard.string(forType: .string) {
           print("ClipGuard: Raw clipboard text ->\n\(content)\n---")
        } else {
           print("ClipGuard: No plain string found in clipboard")
        }

        if let content = pasteboard.string(forType: .string) {
            let redacted = Redactor.redact(content)
            if redacted != content {
                pasteboard.clearContents()
                pasteboard.setString(redacted, forType: .string)
                print("ClipGuard: Redacted sensitive content.")
            }
        }
    }

}
