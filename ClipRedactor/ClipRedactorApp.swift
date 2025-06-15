//
//  ClipRedactorApp.swift
//  ClipRedactor
//
//  Created by Charles Morehead on 6/6/25.
//

import SwiftUI

@main
struct ClipRedactorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // Keeps the app alive without showing a document window
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    NSApp.sendAction(#selector(AppDelegate.showSettings(_:)), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}




