//
//  ClipShieldApp.swift
//  ClipShield
//
//  Created by Charles Morehead on 6/6/25.
//

import SwiftUI

@main
struct ClipShieldApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Required even if unused
         Settings {
            ClipShieldSettingsView()
        }
    }
}
