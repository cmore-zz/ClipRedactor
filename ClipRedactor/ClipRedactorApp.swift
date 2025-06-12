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
        // Required even if unused
         Settings {
            ClipRedactorSettingsView()
        }
    }
}
