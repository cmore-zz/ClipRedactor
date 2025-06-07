import Foundation
import AppKit
import UserNotifications

class ClipboardWatcher {
    private let pasteboard = NSPasteboard.general
    private var changeCount: Int
    private var timer: Timer?
    static var shared: ClipboardWatcher?

    init() {
        self.changeCount = pasteboard.changeCount
        ClipboardWatcher.shared = self
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
                ClipboardManager.shared.storeOriginal(content)
                pasteboard.clearContents()
                pasteboard.setString(redacted, forType: .string)
                print("ClipGuard: Redacted sensitive content.")
                showRedactionNotification(replacement: content, original: redacted)
            }
        }
    }


    func showRedactionNotification(replacement: String, original: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = "Clipboard redacted"
        content.body = replacement.contains("REDACTED") ? replacement : "[REDACTED]: \(replacement)"
        content.sound = .default

        // Optional: Add unredact action
        let unredactAction = UNNotificationAction(identifier: "UNREDACT", title: "Unredact", options: [.foreground])
        let category = UNNotificationCategory(identifier: "CLIPGUARD_REDACTION", actions: [unredactAction], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
        content.categoryIdentifier = "CLIPGUARD_REDACTION"

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func updateChangeCount() {
        self.changeCount = pasteboard.changeCount
    }

}
