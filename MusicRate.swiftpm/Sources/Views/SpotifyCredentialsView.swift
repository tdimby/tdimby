import SwiftUI

struct SpotifyCredentialsView: View {
    @EnvironmentObject var credentials: SpotifyCredentialsStore
    @Environment(\.dismiss) private var dismiss
    @State private var clientID = ""
    @State private var clientSecret = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Search uses the real Spotify catalog, which needs your own free API keys.")
                    Text("1. Go to developer.spotify.com/dashboard and log in with any Spotify account.\n2. Create an app — any name and description works; for the redirect URI, anything like https://example.com is fine, since MusicRate never opens a login screen.\n3. Open the app's Settings and copy its Client ID and Client Secret below.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Client ID") {
                    TextField("Client ID", text: $clientID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Client Secret") {
                    SecureField("Client Secret", text: $clientSecret)
                }
            }
            .navigationTitle("Spotify API Keys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        credentials.clientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
                        credentials.clientSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                    .disabled(clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            clientID = credentials.clientID
            clientSecret = credentials.clientSecret
        }
    }
}
