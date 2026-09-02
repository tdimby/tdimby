import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AddLinkView: View {
    @EnvironmentObject var store: MusicStore
    @EnvironmentObject var displayNameStore: DisplayNameStore

    @State private var linkText = ""
    @State private var clipboardSuggestion: String?
    @State private var isLookingUp = false
    @State private var lookupError: String?
    @State private var item: SpotifyItem?

    @State private var stars = 0
    @State private var note = ""
    @State private var selectedGroupID: String?
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var didSubmit = false

    var body: some View {
        NavigationStack {
            Form {
                if let clipboardSuggestion {
                    Section {
                        Button {
                            linkText = clipboardSuggestion
                            self.clipboardSuggestion = nil
                            Task { await lookUp() }
                        } label: {
                            Label("Use Spotify link from clipboard", systemImage: "doc.on.clipboard")
                        }
                    }
                }

                Section("Spotify Link") {
                    TextField("Paste a Spotify share link…", text: $linkText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button {
                        Task { await lookUp() }
                    } label: {
                        if isLookingUp {
                            ProgressView()
                        } else {
                            Text("Look Up")
                        }
                    }
                    .disabled(linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLookingUp)
                    if let lookupError {
                        Text(lookupError).foregroundStyle(.red).font(.footnote)
                    }
                }

                if let item {
                    Section(item.kind.displayName) {
                        SongRow(item: item)
                    }

                    Section("Your Rating") {
                        StarRatingView(rating: $stars)
                        TextField("Add a note (optional)", text: $note, axis: .vertical)
                    }

                    Section("Rate For") {
                        Picker("Audience", selection: $selectedGroupID) {
                            Text("Everyone (Worldwide)").tag(String?.none)
                            ForEach(store.myGroups) { group in
                                Text(group.name).tag(String?.some(group.id))
                            }
                        }
                    }

                    Section {
                        Button {
                            Task { await submit() }
                        } label: {
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Text("Submit Rating")
                            }
                        }
                        .disabled(stars == 0 || isSubmitting)
                        if let submitError {
                            Text(submitError).foregroundStyle(.red).font(.footnote)
                        }
                        if didSubmit {
                            Label("Rating posted!", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .navigationTitle("Add & Rate")
            .onAppear { checkClipboard() }
        }
    }

    private func checkClipboard() {
        #if canImport(UIKit)
        guard let text = UIPasteboard.general.string, SpotifyLinkParser.firstLink(in: text) != nil else { return }
        clipboardSuggestion = text
        #endif
    }

    private func lookUp() async {
        lookupError = nil
        item = nil
        didSubmit = false
        guard let link = SpotifyLinkParser.firstLink(in: linkText) else {
            lookupError = "That doesn't look like a Spotify link."
            return
        }
        isLookingUp = true
        defer { isLookingUp = false }
        do {
            item = try await SpotifyMetadataService.lookup(link)
        } catch {
            lookupError = error.localizedDescription
        }
    }

    private func submit() async {
        guard let item else { return }
        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }
        do {
            let group = store.myGroups.first { $0.id == selectedGroupID }
            _ = try await store.submitRating(
                for: item,
                stars: stars,
                note: note,
                group: group,
                displayName: displayNameStore.name
            )
            didSubmit = true
            stars = 0
            note = ""
            linkText = ""
            self.item = nil
        } catch {
            submitError = error.localizedDescription
        }
    }
}
