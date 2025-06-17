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
    private var redactionWasRunning = false

    
    @AppStorage("HideInBackground") private var hideInBackground = true
    @AppStorage("PlayRedactionSound") private var playSound = true
    
    let settingsWindowXKey = "SettingsWindowOriginX"
    let settingsWindowYKey = "SettingsWindowOriginY"
    let settingsWindowWKey = "SettingsWindowWidth"
    let settingsWindowHKey = "SettingsWindowHeight"
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        UserDefaults.standard.register(defaults: [
            "HideInBackground": true,
            "PlayRedactionSound": true
        ])

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
        
        let xKey = "StatusWindowOriginX"
        let yKey = "StatusWindowOriginY"

        let hasX = UserDefaults.standard.object(forKey: xKey) != nil
        let hasY = UserDefaults.standard.object(forKey: yKey) != nil
        
        let x = UserDefaults.standard.double(forKey: xKey)
        let y = UserDefaults.standard.double(forKey: yKey)

        window.delegate = self

        let origin: NSPoint
        if hasX, hasY {
            // Nudging down by 22 points (typical title bar height on standard display)
            origin = NSPoint(x: x, y: y)
        } else {
            origin = NSPoint(x: 100, y: 100)
        }

        window.setFrameTopLeftPoint(NSPoint(x: origin.x, y: origin.y))
        //window.setFrameOrigin(origin)
        
        window.title = "ClipRedactor"
        window.contentView = NSHostingView(rootView: statusView)
        self.statusWindow = window
        window.makeKeyAndOrderFront(nil)

    }
    
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        let frame = window.frame
        let topLeft = NSPoint(x: frame.origin.x, y: frame.origin.y + frame.height)

        if window == self.statusWindow {
            UserDefaults.standard.set(topLeft.x, forKey: "StatusWindowOriginX")
            UserDefaults.standard.set(topLeft.y, forKey: "StatusWindowOriginY")
        } else if window == self.settingsWindow {
            UserDefaults.standard.set(topLeft.x, forKey: settingsWindowXKey)
            UserDefaults.standard.set(topLeft.y, forKey: settingsWindowYKey)
        }
    }
    
    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        if window == self.settingsWindow {
            let size = window.frame.size
            UserDefaults.standard.set(size.width, forKey: settingsWindowWKey)
            UserDefaults.standard.set(size.height, forKey: settingsWindowHKey)
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
        let defaults = UserDefaults.standard
        let hasX = defaults.object(forKey: settingsWindowXKey) != nil
        let hasY = defaults.object(forKey: settingsWindowYKey) != nil
        let hasW = defaults.object(forKey: settingsWindowWKey) != nil
        let hasH = defaults.object(forKey: settingsWindowHKey) != nil

        let rect: NSRect
        if hasX, hasY, hasW, hasH {
            let x = defaults.double(forKey: settingsWindowXKey)
            let y = defaults.double(forKey: settingsWindowYKey)
            let w = defaults.double(forKey: settingsWindowWKey)
            let h = defaults.double(forKey: settingsWindowHKey)
            rect = NSRect(x: x, y: y - h, width: w, height: h) // converting top-left Y to origin
        } else {
            rect = NSRect(x: 200, y: 200, width: 700, height: 600)
        }

        let window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "ClipRedactor Settings"
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view)
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        
        if let watcher = clipboardWatcher {
            redactionWasRunning = watcher.isRunning
            watcher.stop()
            watcher.isTemporarilySuspended = true
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        showStatusWindow()
    }

    func applicationDidResignActive(_ notification: Notification) {
        guard let window = statusWindow else { return }
        
        if hideInBackground {
            window.orderOut(nil)
        }
    }
}

extension AppDelegate {
    func windowWillClose(_ notification: Notification) {
        if let closedWindow = notification.object as? NSWindow,
           closedWindow == self.settingsWindow {
            self.settingsWindow = nil

            clipboardWatcher?.isTemporarilySuspended = false
            if redactionWasRunning {
                clipboardWatcher?.start()
            }
        }
    }
}
