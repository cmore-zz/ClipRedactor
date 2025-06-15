import Foundation
import AppKit
import UserNotifications

class ClipboardWatcher: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var canUnredact: Bool = false

    private var lastProcessedContent: String?
    private var lastRedactedContent: String?
    private var lastPreredactedContent: String?

    private let pasteboard = NSPasteboard.general
    private let redactor = Redactor()
    private var changeCount: Int
    private var timer: Timer?
    static var shared: ClipboardWatcher?

    init() {
        self.changeCount = pasteboard.changeCount
        ClipboardWatcher.shared = self
    }

    func start() {
        print("ClipRedactor: Timer started")
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in

            self.checkPasteboard()
        }
    }

    func stop() {
        print("ClipRedactor: Timer stopped")
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func checkPasteboard() {
        guard pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount
        
        if let keyWindow = NSApp.keyWindow,
           keyWindow.title == "ClipRedactor Settings" {
            print("ClipRedactor: skipping clipboard check due to settings window focus")
            return
        }

        guard let capturedContent = pasteboard.string(forType: .string) else {
            lastProcessedContent = nil
            canUnredact = false
            print("ClipRedactor: No plain string found in clipboard")
            return
        }

        if (capturedContent == lastProcessedContent) {
            // already processed... ignore
            return
        }

        lastProcessedContent = capturedContent

        print("ClipRedactor: Raw clipboard text ->\n\(capturedContent)\n---")

        let redacted = redactor.redact(capturedContent)
        if redacted != capturedContent {
            ClipboardManager.shared.storeOriginal(capturedContent)
            lastRedactedContent = redacted
            lastPreredactedContent = capturedContent
            let success = pasteboard.clearContents()
            if (success != 0) {
                let wrote = pasteboard.setString(redacted, forType: .string)
                print("Clipboard updated with redacted content. Write success: \(wrote)")
            } else {
                print("Failed to clear clipboard.")
            }
            canUnredact = true
            showRedactionNotification(replacement: capturedContent, original: redacted)
        } else if capturedContent != lastRedactedContent {
            print("ClipRedactor: setting to false because content \(capturedContent) does not match \(lastRedactedContent ?? "nil").")
            canUnredact = false
        }
    }


    func showRedactionNotification(replacement: String, original: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = "Clipboard redacted"
        content.body = replacement.contains("REDACTED") ? replacement : "[REDACTED]: \(replacement)"
        content.sound = .default

        // Optional: Add unredact action
        let unredactAction = UNNotificationAction(identifier: "UNREDACT", title: "Unredact", options: [.foreground])
        let category = UNNotificationCategory(identifier: "CLIPREDACTOR_REDACTION", actions: [unredactAction], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
        content.categoryIdentifier = "CLIPREDACTOR_REDACTION"

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func updateChangeCount() {
        self.changeCount = pasteboard.changeCount
    }

    func restoreLastPreRedactionValue() {
        ClipboardManager.shared.restoreLastPreRedactionValue()

        print("ClipRedactor: setting to false because unredact).")
        canUnredact = false
    }

}
