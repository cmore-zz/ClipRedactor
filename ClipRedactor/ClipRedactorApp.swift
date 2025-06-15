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


struct StatusScreenView: View {
    @ObservedObject var watcher: ClipboardWatcher
    @FocusState private  var unredactIsFocused: Bool


    var body: some View {
        VStack(spacing: 10) {
            Image("LargeIcon")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 128, height: 128)

            Button(action: {
                watcher.isRunning ? watcher.stop() : watcher.start()
            }) {
                Text(watcher.isRunning ? "Pause" : "Resume")
            }

            Text("Debug: canUnredact = \(watcher.canUnredact.description)")
              .font(.caption2)
              .foregroundColor(.red)

            if watcher.canUnredact {
                Button("Unredact") {
                    watcher.restoreLastPreRedactionValue()
                }
                  .focused($unredactIsFocused)
                  .onAppear {
                      unredactIsFocused = true
                  }
            }
            Text("Status: \(watcher.isRunning ? "Running" : "Paused")")
              .font(.caption)
              .foregroundColor(.gray)
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

