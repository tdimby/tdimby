import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: MusicStore
    @EnvironmentObject var displayNameStore: DisplayNameStore
    @State private var showNamePrompt = false

    var body: some View {
        TabView {
            FeedView()
                .tabItem { Label("Worldwide", systemImage: "globe") }

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            AddLinkView()
                .tabItem { Label("Paste Link", systemImage: "link") }

            GroupsView()
                .tabItem { Label("Groups", systemImage: "person.3.fill") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .task {
            showNamePrompt = !displayNameStore.hasChosenName
        }
        .sheet(isPresented: $showNamePrompt) {
            ChooseNameView()
                .interactiveDismissDisabled(!displayNameStore.hasChosenName)
        }
        .alert(
            "MusicRate",
            isPresented: Binding(
                get: { store.lastError != nil },
                set: { if !$0 { store.lastError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { store.lastError = nil }
        } message: {
            Text(store.lastError ?? "")
        }
    }
}

struct ChooseNameView: View {
    @EnvironmentObject var displayNameStore: DisplayNameStore
    @Environment(\.dismiss) private var dismiss
    @State private var draftName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Your name", text: $draftName)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("What should other listeners see?")
                } footer: {
                    Text("This is shown next to the ratings you post. You can change it later from Profile.")
                }
            }
            .navigationTitle("Welcome to MusicRate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        displayNameStore.name = draftName
                        dismiss()
                    }
                    .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear { draftName = displayNameStore.name }
    }
}
