import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var clipboardWatcher: ClipboardWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        clipboardWatcher = ClipboardWatcher()
        clipboardWatcher?.start()

        let center = UNUserNotificationCenter.current()
        center.delegate = self  // 🔁 self is now a UNUserNotificationCenterDelegate

        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification error: \(error)")
            } else if granted {
                print("✅ Notification permission granted")
            } else {
                print("❌ Notification permission denied")
            }
        }
    }

    // Optional: respond to interactions with notifications (e.g., when user clicks a button)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == "UNREDACT" {
            ClipboardManager.shared.restoreLastPreRedactionValue()
        }        
        completionHandler()
    }

    // Optional: show notifications while the app is frontmost
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
