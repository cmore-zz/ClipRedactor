//
//  StatusScreenView.swift
//  ClipRedactor
//
//  Created by Charles Morehead on 6/14/25.
//


import SwiftUI

struct StatusScreenView: View {
    @ObservedObject var watcher: ClipboardWatcher
    @FocusState private  var unredactIsFocused: Bool
    @State private var showSplash = true
    @State private var viewIsVisible = false
    @AppStorage("HideInBackground") private var hideInBackground = true


    var body: some View {
        ZStack {
            if showSplash {
                VStack {
                    Spacer()
                    Image("LargeIcon")
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                    Spacer()
                }
                .transition(.opacity)
            } else {
                VStack(spacing: 12) {
                    // Pause/Resume control
                    Button(action: {
                               watcher.isRunning ? watcher.stop() : watcher.start()
                           }) {
                        Text(watcher.isRunning ? "Pause" : "Resume")
                    }
                      .buttonStyle(.borderedProminent)
                      .disabled(watcher.isTemporarilySuspended)

                    // Status text
                    Text("Status: \(watcher.isRunning ? "Running" : (watcher.isTemporarilySuspended ? "Paused for settings" : "Paused"))")
                      .font(.caption)
                      .foregroundColor(watcher.isRunning ? .gray : .red)

                    // Unredact button
                    if watcher.canUnredact {
                        VStack(spacing: 4) {
                            Spacer().frame(height: 4) // Small gap above the button
                            Button("Unredact") {
                                watcher.restoreLastPreRedactionValue()
                            }
                              .buttonStyle(.borderedProminent)
                              .focused($unredactIsFocused)
                              .onAppear { unredactIsFocused = true }
                        }
                    }

                    // Redaction summary
                    if let lastRedaction = watcher.lastRedactionResult {
                        VStack(spacing: 4) {
                            Text("\(lastRedaction.key): \(lastRedaction.originalText.prefix(80).trimmingCharacters(in: .whitespacesAndNewlines))…")
                              .font(.caption)
                              .foregroundColor(.secondary)
                              .multilineTextAlignment(.center)
                              .lineLimit(1)
                        }
                    }
                }

//                    Text("Debug: canUnredact = \(watcher.canUnredact.description)")
//                        .font(.caption2)
//                        .foregroundColor(.red)

            }
        }
        .padding(20)
        .frame(width: UIConstants.StatusWindow.width, height: UIConstants.StatusWindow.height)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            viewIsVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if viewIsVisible {
                    withAnimation {
                        showSplash = false
                    }
                }
            }
        }
        .onChange(of: watcher.canUnredact) {
            if (watcher.canUnredact == false && hideInBackground) {
                if let window = NSApp.windows.first(where: { $0.title == "ClipRedactor" }), !window.isKeyWindow {
                    window.orderOut(nil)
                }
            }
        }
    }
}
