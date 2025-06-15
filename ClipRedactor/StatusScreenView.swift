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


    var body: some View {
        ZStack {
            if showSplash {
                VStack {
                    Spacer()
                    Image("LargeIcon")
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 94, height: 94)
                    Spacer()
                }
                .transition(.opacity)
            } else {
                VStack(spacing: 12) {


                    Button(action: {
                        watcher.isRunning ? watcher.stop() : watcher.start()
                    }) {
                        Text(watcher.isRunning ? "Pause" : "Resume")
                    }
                    .buttonStyle(.borderedProminent)

//                    Text("Debug: canUnredact = \(watcher.canUnredact.description)")
//                        .font(.caption2)
//                        .foregroundColor(.red)

                    if watcher.canUnredact {
                        Button("Unredact") {
                            watcher.restoreLastPreRedactionValue()
                        }
                        .buttonStyle(.borderedProminent)
                        .focused($unredactIsFocused)
                        .onAppear {
                            unredactIsFocused = true
                        }
                    }

                    Text("Status: \(watcher.isRunning ? "Running" : "Paused")")
                        .font(.caption)
                        .foregroundColor(watcher.isRunning ? .gray : .red)
                }
                .transition(.opacity)
            }
        }
        .padding(20)
        .frame(width: 180, height: 100)
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
            if watcher.canUnredact == false {
                if let window = NSApp.windows.first(where: { $0.title == "ClipRedactor" }), !window.isKeyWindow {
                    window.orderOut(nil)
                }
            }
        }
    }
}
