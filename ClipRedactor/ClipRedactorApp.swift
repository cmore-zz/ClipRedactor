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


struct SplashScreenView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image("SplashIcon")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 128, height: 128)
            
            Text("ClipRedactor starting...")
                .font(.title3)
        }
        .padding(20)
        .background(Color(NSColor.windowBackgroundColor))
        .frame(width: 250, height: 250)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
               // NSApp.keyWindow?.close()
            }
        }
    }
}

