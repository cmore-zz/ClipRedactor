//
//  ClipGuardApp.swift
//  ClipGuard
//
//  Created by Charles Morehead on 6/6/25.
//

import SwiftUI

@main
struct ClipGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Required even if unused
        Settings {
            EmptyView()
        }
    }
}
