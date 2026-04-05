import SwiftUI

struct SettingsView: View {
    @AppStorage("anthropic_api_key") private var apiKey = ""
    @State private var showKey = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        if showKey {
                            TextField("sk-ant-…", text: $apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(.body, design: .monospaced))
                        } else {
                            SecureField("sk-ant-…", text: $apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    Text("Get your key from console.anthropic.com. It is stored locally in the iOS Keychain and never sent anywhere except directly to api.anthropic.com.")
                }

                Section("About") {
                    LabeledContent("Model", value: "Claude Opus 4.6")
                    LabeledContent("Data source", value: "Apple Health (HealthKit)")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
