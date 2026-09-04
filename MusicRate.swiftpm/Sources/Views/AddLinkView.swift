import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AddLinkView: View {
    @EnvironmentObject var store: MusicStore
    @EnvironmentObject var account: AccountStore

    @State private var linkText = ""
    @State private var clipboardSuggestion: String?
    @State private var isLookingUp = false
    @State private var lookupError: String?
    @State private var item: SpotifyItem?

    @State private var stars = 0
    @State private var note = ""
    @State private var audience: RatingAudience = .privateOnly
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
                        } label: {
                            Label("Use Spotify link from clipboard", systemImage: "doc.on.clipboard")
                        }
                    }
                }

                Section {
                    HStack {
                        TextField("Paste a Spotify share link…", text: $linkText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                        if isLookingUp {
                            ProgressView()
                        } else if item != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    if let lookupError {
                        Text(lookupError).foregroundStyle(.red).font(.footnote)
                    }
                } header: {
                    Text("Spotify Link")
                } footer: {
                    Text("Looked up automatically as soon as you paste a full link.")
                }

                if let item {
                    Section(item.kind.displayName) {
                        SongRow(item: item)
                    }

                    Section {
                        StarRatingView(rating: $stars)
                        TextField("Add a note (optional)", text: $note, axis: .vertical)
                    } header: {
                        Text("Your Rating")
                    }

                    Section {
                        Picker("Audience", selection: $audience) {
                            Text("Private (Just Me)").tag(RatingAudience.privateOnly)
                            ForEach(store.myGroups) { group in
                                Text(group.name).tag(RatingAudience.group(group))
                            }
                        }
                    } header: {
                        Text("Rate For")
                    } footer: {
                        Text("Private ratings are only visible to you.")
                    }

                    Section {
                        Button {
                            Task { await submit() }
                        } label: {
                            HStack {
                                Spacer()
                                if isSubmitting {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Submit Rating").bold()
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(stars == 0 || isSubmitting)
                        .listRowInsets(EdgeInsets())
                        .padding(12)
                        if let submitError {
                            Text(submitError).foregroundStyle(.red).font(.footnote)
                        }
                        if didSubmit {
                            Label("Rating posted!", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Add & Rate")
            .animation(.default, value: item)
            .onAppear { checkClipboard() }
            .task(id: linkText) {
                await autoLookUp()
            }
        }
    }

    private func checkClipboard() {
        #if canImport(UIKit)
        guard let text = UIPasteboard.general.string, SpotifyLinkParser.firstLink(in: text) != nil else { return }
        clipboardSuggestion = text
        #endif
    }

    private func autoLookUp() async {
        didSubmit = false
        let trimmed = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            item = nil
            lookupError = nil
            return
        }
        guard let link = SpotifyLinkParser.firstLink(in: linkText) else {
            // Don't flash an error while the user is still typing/pasting -
            // only clear any existing result.
            item = nil
            return
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled else { return }

        lookupError = nil
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
            _ = try await store.submitRating(
                for: item,
                stars: stars,
                note: note,
                audience: audience,
                displayName: account.displayName
            )
            Haptics.success()
            didSubmit = true
            stars = 0
            note = ""
            audience = .privateOnly
            linkText = ""
            self.item = nil
        } catch {
            submitError = error.localizedDescription
        }
    }
}
