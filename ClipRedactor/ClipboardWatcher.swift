import Foundation
import AppKit
import UserNotifications
import SwiftUI

struct RedactionResult {
    let originalText: String
    let redactedText: String
    let key: String
}

class ClipboardWatcher: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var canUnredact: Bool = false
    @Published var isTemporarilySuspended: Bool = false

    private var lastProcessedContent: String?
    @Published var lastRedactionResult: RedactionResult?


    private let pasteboard = NSPasteboard.general
    private let redactor = Redactor()
    private var changeCount: Int
    private var timer: Timer?
    static var shared: ClipboardWatcher?
    @AppStorage("PlayRedactionSound") private var playSound = true


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

        let (redacted, firstMatch) = redactor.redact(capturedContent)
        if redacted != capturedContent {
            guard let firstMatch = firstMatch else {
                fatalError("Expected a match but found nil")
            }
            ClipboardManager.shared.storeOriginal(capturedContent)
            lastRedactionResult = RedactionResult(
                originalText: capturedContent, redactedText: redacted, key: firstMatch.key
            )
            let success = pasteboard.clearContents()
            if (success != 0) {
                let wrote = pasteboard.setString(redacted, forType: .string)
                print("Clipboard updated with redacted content. Write success: \(wrote)")
            } else {
                print("Failed to clear clipboard.")
            }
            canUnredact = true

            if playSound {
                SoundManager.shared.play()
            }

            showRedactionNotification(replacement: capturedContent, original: redacted)
        } else if let lastResult = lastRedactionResult,
                  capturedContent != lastResult.redactedText {
            print("ClipRedactor: setting to false because content \(capturedContent) does not match \(lastRedactionResult?.redactedText ?? "nil").")
            canUnredact = false
        }
    }


    func showRedactionNotification(replacement: String, original: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = "Clipboard redacted"
        content.body = replacement.contains("REDACTED") ? replacement : "[REDACTED]: \(replacement)"

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
