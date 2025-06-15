import AppKit
import UserNotifications
import ServiceManagement
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSWindowDelegate {
    var clipboardWatcher: ClipboardWatcher?
    var settingsWindow: NSWindow?
    var statusWindow: NSWindow!
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {

        //        NSApplication.shared.setActivationPolicy(.accessory)
        clipboardWatcher = ClipboardWatcher()
        clipboardWatcher?.start()

        if let watcher = clipboardWatcher {
            watcher.$canUnredact
              .receive(on: RunLoop.main)
              .sink { [weak self] canUnredact in
                  if canUnredact {
                      self?.showStatusWindow()
                  }
              }
              .store(in: &cancellables)
        }

        
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
            self.showStatusWindow()
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
    
    func showStatusWindow() {
        
        if statusWindow != nil {
            statusWindow?.makeKeyAndOrderFront(nil)
            return
        }
        guard let watcher = clipboardWatcher else { return }
        let statusView = StatusScreenView(watcher: watcher)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
            styleMask: [.titled],
            backing: .buffered, defer: false
        )
        window.center()
        window.title = "ClipRedactor"
        window.contentView = NSHostingView(rootView: statusView)
        window.makeKeyAndOrderFront(nil)
        self.statusWindow = window
        
        // Optional auto-close fallback (also inside StatusScreenView)
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
//            window.close()
//        }
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

    func applicationDidBecomeActive(_ notification: Notification) {
        showStatusWindow()
    }

    func applicationDidResignActive(_ notification: Notification) {
        guard let window = statusWindow else { return }
        if window.isVisible {
            window.orderOut(nil)
        }
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
