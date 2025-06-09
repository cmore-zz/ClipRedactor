import AppKit
import UserNotifications
import ServiceManagement
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var clipboardWatcher: ClipboardWatcher?
    var settingsWindow: NSWindow?

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

        if let mainMenu = NSApp.mainMenu,
           let appMenuItem = mainMenu.item(at: 0),
           let settingsItem = appMenuItem.submenu?.item(withTitle: "Settings…") {
            settingsItem.target = self
            settingsItem.action = #selector(AppDelegate.showSettings(_:))
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

    @objc func showSettings(_ sender: Any?) {
        if self.settingsWindow == nil {
            let view = ClipShieldSettingsView()

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered, defer: false
            )
            window.center()
            window.title = "ClipShield Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: view)
            window.makeKeyAndOrderFront(nil)
            self.settingsWindow = window
        } else {
            self.settingsWindow?.makeKeyAndOrderFront(nil)
        }
    }
}
