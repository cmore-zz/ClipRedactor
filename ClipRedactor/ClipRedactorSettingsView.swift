import Foundation
import SwiftUI
import ServiceManagement

struct RuleEntry: Identifiable, Hashable {
    let id = UUID()
    var replacement: String
    var pattern: String
    var requireCodeContext: Bool
    var isBuiltin: Bool
}


struct ClipRedactorSettingsView: View {
    @AppStorage("launchAtLogin") var launchAtLogin = false
    @State private var testInput = ""
    @State private var redactedOutput = ""
    @State private var showAlert = false
    @State private var alertMessage = ""

    @State private var rules: [RuleEntry] = []
    @State private var dirtyRules = false

    private let redactor = Redactor()

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 20) {
                Toggle("Start at login", isOn: $launchAtLogin)
                    .onAppear {
                        launchAtLogin = (SMAppService.mainApp.status == .enabled)
                        loadRules()
                    }
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if #unavailable(macOS 13.0) {
                                alertMessage = "Launch at login requires macOS 13 or later."
                                showAlert = true
                            } else if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            alertMessage = "Failed to update login item:\n\(error.localizedDescription)"
                            showAlert = true
                        }
                    }

                Divider()

                Text("Redaction Rules")
                    .font(.headline)

                // Main rules section gets priority for vertical space
                VStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Replacement")
                                  .frame(width: 180, alignment: .leading)
                                Text("Pattern")
                                  .frame(maxWidth: .infinity, alignment: .leading)
                                Text("Code/Config?")
                                  .frame(width: 100, alignment: .center)
                                Spacer()
                            }
                              .font(.caption)
                              .foregroundColor(.secondary)

                            ForEach($rules) { $rule in
                                HStack {
                                    TextField("Replacement", text: $rule.replacement)
                                      .frame(width: 180)
                                      .onChange(of: rule.replacement) {
                                          dirtyRules = true
                                      }

                                    TextField("Pattern", text: $rule.pattern)
                                      .onChange(of: rule.pattern) {
                                          dirtyRules = true
                                      }

                                    Toggle("", isOn: $rule.requireCodeContext)
                                      .frame(width: 100, alignment: .center)
                                      .labelsHidden()
                                      .onChange(of: rule.requireCodeContext) {
                                          dirtyRules = true
                                      }

                                    if !rule.isBuiltin {
                                        Button(role: .destructive) {
                                            rules.removeAll { $0.id == rule.id }
                                            dirtyRules = true
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    HStack {
                        Button("Save Rules") {
                            saveRules()
                        }
                        .disabled(!dirtyRules)

                        Spacer()

                        Button(action: {
                            rules.append(RuleEntry(replacement: "", pattern: "", requireCodeContext: false, isBuiltin: false))
                            dirtyRules = true
                        }) {
                            Image(systemName: "plus")
                            Text("Add Rule")
                        }
                        .help("Add Rule")
                    }
                    .padding(.top, 4)
                }
                .frame(maxHeight: .infinity)
                .layoutPriority(1)

                Divider()

                // Test redactor and output area with fixed heights
                VStack(alignment: .leading, spacing: 8) {
                    Text("Test Redactor")
                        .font(.headline)

                    TextEditor(text: $testInput)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .border(Color.gray)

                    Button("Redact") {
                        redactedOutput = redactor.redact(testInput)
                    }

                    Text("Output:")
                        .font(.subheadline)

                    TextEditor(text: .constant(redactedOutput))
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .border(Color.green)
                        .disabled(true)
                }

                Spacer()
            }
            .padding()
            .frame(minWidth: 500, idealHeight: 700, maxHeight: .infinity)
        }
        .background(ResizableWindowAccessor())
        .alert("Launch at Login", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func loadRules() {
        let merged = Redactor.mergedMap()
        let overrideFile = Redactor.defaultOverrideFile()
        let overrides: [String: (String, Bool)] = overrideFile.flatMap {
        Redactor.loadUserMap(from: $0)
    }?.reduce(into: [String: (String, Bool)]()) { result, def in
        result[def.replacement] = (def.pattern, def.requireCodeContext ?? false)
    } ?? [:]

        var entries: [RuleEntry] = []

        for (replacement, rule) in merged {
            let pattern = rule.pattern
            let requireCodeContext = rule.requireCodeContext
            let isBuiltin = Redactor.builtInMap[replacement] != nil && overrides[replacement] == nil
            entries.append(RuleEntry(replacement: replacement, pattern: pattern, requireCodeContext: requireCodeContext, isBuiltin: isBuiltin))
        }

        self.rules = entries.sorted { $0.replacement < $1.replacement }
    }

    private func saveRules() {
        var userRules: [RuleDef] = []

        for rule in rules {
            guard !rule.replacement.isEmpty, !rule.pattern.isEmpty else { continue }

            if rule.isBuiltin {
                // Don't re-save built-in rules
                continue
            }

            userRules.append(RuleDef(
                               replacement: rule.replacement,
                               pattern: rule.pattern,
                               requireCodeContext: rule.requireCodeContext
                             ))
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(userRules)

            guard let file = Redactor.defaultOverrideFile() else {
                alertMessage = "Could not determine file location."
                showAlert = true
                return
            }

            try FileManager.default.createDirectory(
              at: file.deletingLastPathComponent(),
              withIntermediateDirectories: true
            )
            try data.write(to: file, options: .atomic)
            dirtyRules = false
        } catch {
            alertMessage = "Failed to save override rules:\n\(error.localizedDescription)"
            showAlert = true
        }
    }

}

struct ResizableWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first(where: { $0.isVisible && $0.level == .normal }) {
                window.styleMask.insert(.resizable)
                window.minSize = NSSize(width: 500, height: 400)
            }
        }
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
