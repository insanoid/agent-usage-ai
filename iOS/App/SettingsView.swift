import SwiftUI

struct SettingsView: View {
    @Bindable var model: UsageModel
    @Environment(\.dismiss) private var dismiss
    @State private var serverURL = ""
    @State private var token = ""
    @State private var message: String?
    @State private var testing = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("HTTPS server URL", text: $serverURL)
                        .textContentType(.URL).keyboardType(.URL).textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("API bearer token", text: $token)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().privacySensitive()
                } header: { Text("Private server") } footer: {
                    Text(
                        """
                        Use the base URL ending in /agent-usage. \
                        Leave the token blank to keep the token saved for this URL.
                        """
                    )
                }
                Section {
                    Button {
                        Task { await saveAndTest() }
                    } label: {
                        if testing {
                            ProgressView("Testing connection…")
                        } else {
                            Text("Save and test connection")
                        }
                    }
                    .disabled(testing || model.refreshing || model.fixtureState != nil)
                    if let message {
                        Text(message).font(.subheadline)
                    }
                } footer: {
                    Text(
                        """
                        Keep Tailscale connected. Tokens stay in Keychain and are shared only with this app’s widgets. \
                        Changing the URL clears cached usage.
                        """
                    )
                }
                Section("Home Screen widgets") {
                    Text("Add Agent Usage from the widget gallery. Edit the widget to select a provider and profile.")
                    Text("Widgets request updates about every 30 minutes. iOS controls the actual schedule.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear { serverURL = model.endpoint }
        }
    }

    private func saveAndTest() async {
        testing = true
        defer { testing = false }
        do {
            try model.configure(url: serverURL, token: token)
            token = ""
            await model.refresh()
            message = model.error ?? "Connected. Latest server snapshot loaded."
        } catch { message = UsageRepository.message(for: error) }
    }
}
