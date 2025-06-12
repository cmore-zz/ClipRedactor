import SwiftUI
import ServiceManagement

struct RuleEntry: Identifiable, Hashable {
    let id = UUID()
    var replacement: String
    var pattern: String
    var isGrouped: Bool
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

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Replacement")
                              .frame(width: 180, alignment: .leading)
                            Text("Pattern")
                              .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Grouped?")
                              .frame(width: 80, alignment: .center)
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

                                Toggle("Grouped", isOn: $rule.isGrouped)
                                  .frame(width: 80, alignment: .center)
                                  .labelsHidden()
                                  .onChange(of: rule.isGrouped) {
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

                        HStack {
                            Spacer()
                            Button(action: {
                                rules.append(RuleEntry(replacement: "", pattern: "", isGrouped: false, isBuiltin: false))
                                dirtyRules = true
                            }) {
                                Image(systemName: "plus")
                            }
                            .help("Add Rule")
                        }

                        Button("Save Rules") {
                            saveRules()
                        }
                        .disabled(!dirtyRules)
                        .padding(.top, 4)
                    }
                }

                Divider()

                Spacer()

                Text("Test Redactor")
                    .font(.headline)

                TextEditor(text: $testInput)
                    .frame(maxWidth: .infinity)
                    .border(Color.gray)

                Button("Redact") {
                    redactedOutput = redactor.redact(testInput)
                }

                Text("Output:")
                    .font(.subheadline)

                TextEditor(text: .constant(redactedOutput))
                    .frame(maxWidth: .infinity)
                    .border(Color.green)
                    .disabled(true)

                Spacer()
            }
            .padding()
            .frame(minWidth: 500, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
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
        let overrides = overrideFile.flatMap { Redactor.loadUserMap(from: $0) } ?? [:]

        var entries: [RuleEntry] = []

        for (replacement, (pattern, isGrouped)) in merged {
            let isBuiltin = Redactor.builtInMap[replacement] != nil && overrides[replacement] == nil
            entries.append(RuleEntry(replacement: replacement, pattern: pattern, isGrouped: isGrouped, isBuiltin: isBuiltin))
        }

        self.rules = entries.sorted { $0.replacement < $1.replacement }
    }

    private func saveRules() {
        var jsonObject: [String: Any?] = [:]

        for rule in rules {
            if rule.replacement.isEmpty || rule.pattern.isEmpty { continue }

            let isOverriding = Redactor.builtInMap[rule.replacement] != nil
            if rule.isBuiltin && !isOverriding { continue }

            if rule.pattern == "__DELETE__" {
                jsonObject[rule.replacement] = nil
            } else if rule.isGrouped {
                jsonObject[rule.replacement] = ["pattern": rule.pattern]
            } else {
                jsonObject[rule.replacement] = rule.pattern
            }
        }

        guard let data = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
              let file = Redactor.defaultOverrideFile()
        else {
            alertMessage = "Failed to serialize override rules."
            showAlert = true
            return
        }

        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
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
