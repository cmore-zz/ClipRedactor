import SwiftUI
import ServiceManagement


struct ClipShieldSettingsView: View {
    @AppStorage("launchAtLogin") var launchAtLogin = false
    @State private var testInput = ""
    @State private var redactedOutput = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // New: persistent instance of Redactor for this view
    private let redactor = Redactor()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Toggle("Start at login", isOn: $launchAtLogin)
                .onAppear {
                    // Sync UI toggle to actual system state
                    launchAtLogin = (SMAppService.mainApp.status == .enabled)
                }
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if #unavailable(macOS 13.0) {
                            alertMessage = "Launch at login requires macOS 13 or later."
                            showAlert = true
                        }
                        else if newValue {
                            try SMAppService.mainApp.register()
                            print("✅ Registered for launch at login")
                        } else {
                            try SMAppService.mainApp.unregister()
                            print("🚫 Unregistered from launch at login")
                        }
                    } catch {
                        alertMessage = "Failed to update login item:\n\(error.localizedDescription)"
                        showAlert = true
                    }
                }

            Divider()

            Text("Test Redactor")
                .font(.headline)

            TextEditor(text: $testInput)
                .border(Color.gray)

            Button("Redact") {
                redactedOutput = redactor.redact(testInput)
            }

            Text("Output:")
                .font(.subheadline)

            TextEditor(text: .constant(redactedOutput))
                .border(Color.green)
                .disabled(true)

            Spacer()
        }
        .padding()
        .frame(width: 500, height: 400)
        .alert("Launch at Login", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
}
