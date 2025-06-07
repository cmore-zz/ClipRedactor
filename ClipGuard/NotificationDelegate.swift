import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == "UNREDACT" {
            // TODO: Restore previous clipboard content (from history, or a temp var)
            print("Unredact requested")
            ClipboardManager.shared .restoreLastPreRedactionValue()
        }
        completionHandler()
    }
}
