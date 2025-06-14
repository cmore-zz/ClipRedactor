import AppKit
import UserNotifications
import ServiceManagement
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSWindowDelegate {
    var clipboardWatcher: ClipboardWatcher?
    var settingsWindow: NSWindow?
    var splashWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {

        //        NSApplication.shared.setActivationPolicy(.accessory)
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
        
        UserDefaults.standard.set(false, forKey: "NSAutomaticQuoteSubstitutionEnabled")
        UserDefaults.standard.set(false, forKey: "NSAutomaticDashSubstitutionEnabled")
        
        if let mainMenu = NSApp.mainMenu,
           let appMenuItem = mainMenu.item(at: 0),
           let settingsItem = appMenuItem.submenu?.item(withTitle: "Settings…") {
            settingsItem.target = self
            settingsItem.action = #selector(AppDelegate.showSettings(_:))
        }
        DispatchQueue.main.async {
            self.showSplash()
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
    
    func showSplash() {
        let splashView = SplashScreenView()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        window.center()
        window.title = "ClipRedactor"
        window.contentView = NSHostingView(rootView: splashView)
        window.makeKeyAndOrderFront(nil)
        self.splashWindow = window
        
        // Optional auto-close fallback (also inside SplashScreenView)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            window.close()
        }
    }
    
    
    @objc func showSettings(_ sender: Any?) {
        if let window = settingsWindow {
            if window.isVisible {
                window.makeKeyAndOrderFront(nil)
            } else {
                // The window exists but is not visible (perhaps hidden or offscreen)
                window.orderFrontRegardless()
            }
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let view = ClipRedactorSettingsView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false
        )
        window.center()
        window.title = "ClipRedactor Settings"
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        
        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension AppDelegate {
    func windowWillClose(_ notification: Notification) {
        if let closedWindow = notification.object as? NSWindow,
           closedWindow == self.settingsWindow {
            self.settingsWindow = nil
        }
    }
}
