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
    @AppStorage("HideInBackground") private var hideInBackground = true
    @AppStorage("PlayRedactionSound") private var playSound = true
    @State private var testInput = ""
    @State private var redactedOutput = ""
    @State private var showAlert = false
    @State private var alertMessage = ""

    @State private var rules: [RuleEntry] = []
    @State private var dirtyRules = false
    @State private var showLogo = true
    
    var hasInvalidRegexes: Bool {
        rules.contains { rule in
            !rule.pattern.isEmpty && (try? NSRegularExpression(pattern: rule.pattern)) == nil
        }
    }
    var nonUniqueReplacements: Set<String> {
        var seen = Set<String>()
        var duplicates = Set<String>()
        for rule in rules {
            if !rule.replacement.isEmpty {
                if seen.contains(rule.replacement) {
                    duplicates.insert(rule.replacement)
                } else {
                    seen.insert(rule.replacement)
                }
            }
        }
        return duplicates
    }

    private let redactor = Redactor()

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 20) {
                Toggle("Start at login", isOn: $launchAtLogin)
                    .padding(.top, 16)
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
                
                Toggle("Hide status window when app is in background", isOn: $hideInBackground)

                
                Toggle("Play sound when redaction occurs", isOn: $playSound)
                    .onChange(of: playSound) { _, newValue in
                        //print(NSSound.soundNames)
                        // Frog, Pop, Tink (no boop)
                        SoundManager.shared.play()
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
                                  .help("The replacement redaction text. (must be unique).")

                                  .frame(width: 180, alignment: .leading)
                                  .padding(.leading, 4)
                                Text("Pattern")
                                  .help("The regular expression (\"regex\") pattern.")
                                  .frame(maxWidth: .infinity, alignment: .leading)
                                Text("Context\nRequired")
                                  .help("Only redact when pattern appears in a quoted string or in a key-value setting like \"password: secret123\".")
                                    .frame(width: 100, alignment: .center)
                                    .padding(.top, 6)
                                    .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                                Spacer()
                            }
                              .font(.subheadline.weight(.medium))
                              .foregroundColor(.secondary)
                            Spacer().frame(height: 8)
                            ForEach($rules) { $rule in
                                HStack {
                                    let isDuplicate = nonUniqueReplacements.contains(rule.replacement)
                                    TextField("Replacement", text: $rule.replacement)
                                      .frame(width: 180)
                                      .border(isDuplicate ? Color.red : Color.clear)
                                       .help(isDuplicate ? "This replacement value is not unique." : "")
                                      .onChange(of: rule.replacement) {
                                          dirtyRules = true
                                      }
                                      .padding(.leading, 4)


                                    TextField("Pattern", text: $rule.pattern)
                                        .border((try? NSRegularExpression(pattern: rule.pattern)) == nil && !rule.pattern.isEmpty ? Color.red : Color.clear)
                                        .help((try? NSRegularExpression(pattern: rule.pattern)) == nil && !rule.pattern.isEmpty ? "Invalid regular expression syntax." : "")
                                      .onChange(of: rule.pattern) {
                                          dirtyRules = true
                                      }


                                    Toggle("", isOn: $rule.requireCodeContext)
                                      .frame(width: 50, alignment: .center)
                                      .labelsHidden()
                                      .onChange(of: rule.requireCodeContext) {
                                          dirtyRules = true
                                      }

                                    Button(role: .destructive) {
                                        rules.removeAll { $0.id == rule.id }
                                        dirtyRules = true
                                    } label: {
                                        Image(systemName: "minus")
                                          .font(.system(size: 10, weight: .regular))
                                    }
                                    .controlSize(.small)
                                    .padding(.trailing, 4)
                                }
                            }
                        }
                    }
                    .background(Color.gray.opacity(0.035))
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.black.opacity(0.1))
                            .offset(y: -0.5),
                        alignment: .top
                    )
.cornerRadius(6)
.overlay(
    RoundedRectangle(cornerRadius: 6)
        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
)
                    HStack {
                        Button("Save Rules") {
                            saveRules()
                        }
                        .disabled(!dirtyRules || hasInvalidRegexes || !nonUniqueReplacements.isEmpty)

                        Spacer()

                        Button(action: {
                            rules.append(RuleEntry(replacement: "", pattern: "", requireCodeContext: false, isBuiltin: false))
                            dirtyRules = true
                        }) {
                            Image(systemName: "plus")
                        }
                        .help("Add Rule")
                    }
                    .padding(.top, 4)
                }
                .frame(maxHeight: .infinity)
                .layoutPriority(1)

                Divider()

                // Test redactor and output area with fixed heights
                VStack(alignment: .leading, spacing: 4) {
                    Text("Test Redactor")
                        .font(.headline)

                    TextEditor(text: $testInput)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .border(Color.gray)
                    

                    Button("Redact") {
                        let testMap: [String: RuleDef] = rules.reduce(into: [:]) { result, rule in
                            if !rule.replacement.isEmpty && !rule.pattern.isEmpty {
                                result[rule.replacement] = RuleDef(
                                    replacement: rule.replacement,
                                    pattern: rule.pattern,
                                    requireCodeContext: rule.requireCodeContext
                                )
                            }
                        }
                        let testRedactor = Redactor(customMap: testMap)
                        let (redacted, _) = testRedactor.redact(testInput)
                        redactedOutput = redacted
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
              .padding(.horizontal, 12)
              .padding(.vertical, 4)
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
            guard !rule.replacement.isEmpty else { continue }

            if let builtIn = Redactor.builtInMap[rule.replacement] {
                let modified = rule.pattern != builtIn.pattern || rule.requireCodeContext != builtIn.requireCodeContext

                if rule.pattern.isEmpty {
                    // Save a null-pattern rule to override and remove built-in rule
                    userRules.append(RuleDef(
                        replacement: rule.replacement,
                        pattern: "",
                        requireCodeContext: false
                    ))
                } else if modified {
                    // Save override for modified built-in rule
                    userRules.append(RuleDef(
                        replacement: rule.replacement,
                        pattern: rule.pattern,
                        requireCodeContext: rule.requireCodeContext
                    ))
                }
            } else if !rule.pattern.isEmpty {
                // New custom rule
                userRules.append(RuleDef(
                    replacement: rule.replacement,
                    pattern: rule.pattern,
                    requireCodeContext: rule.requireCodeContext
                ))
            }
        }
        
        let currentReplacements = Set(rules.map { $0.replacement })
        for (replacement, _) in Redactor.builtInMap {
            if !currentReplacements.contains(replacement) {
                userRules.append(RuleDef(
                    replacement: replacement,
                    pattern: "",  // Empty pattern indicates deletion
                    requireCodeContext: false
                ))
            }
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
