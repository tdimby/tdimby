import SwiftUI

struct SignInView: View {
    @EnvironmentObject var account: AccountStore

    @State private var isSigningUp = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(.green.gradient)
                                .frame(width: 72, height: 72)
                            Image(systemName: "music.note")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        Text("MusicRate")
                            .font(.title2.weight(.bold))
                        Text(isSigningUp ? "Create an account to start rating" : "Sign in to rate and share music")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if !FirebaseConfig.isConfigured {
                    Section {
                        Label("MusicRate isn't connected to a Firebase project yet. Add your API key and project ID in FirebaseConfig.swift.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                if isSigningUp {
                    Section("Your Name") {
                        TextField("Name shown on your ratings", text: $name)
                            .textInputAutocapitalization(.words)
                    }
                }

                Section("Email") {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                }

                Section("Password") {
                    SecureField(isSigningUp ? "At least 6 characters" : "Password", text: $password)
                }

                if let errorText {
                    Section {
                        Label(errorText, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
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
                                Text(isSigningUp ? "Create Account" : "Sign In").bold()
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(!canSubmit || isSubmitting)
                    .listRowInsets(EdgeInsets())
                    .padding(12)

                    Button(isSigningUp ? "Already have an account? Sign In" : "New here? Create an Account") {
                        withAnimation { isSigningUp.toggle() }
                        errorText = nil
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
                    .padding(.bottom, 8)
                }
                .listRowBackground(Color.clear)

                if GoogleAuthConfig.isConfigured {
                    Section {
                        Button {
                            Task { await signInWithGoogle() }
                        } label: {
                            HStack {
                                Spacer()
                                Label("Sign in with Google", systemImage: "g.circle.fill")
                                Spacer()
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isSubmitting)
                    }
                }

                Section {
                    Button {
                        Task { await signInAsTestUser() }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Continue as Test User", systemImage: "hammer.fill")
                                .foregroundStyle(.orange)
                            Spacer()
                        }
                    }
                    .disabled(isSubmitting)
                } footer: {
                    Text("Instantly signs into (or creates) a shared test account — no typing needed. For trying the app out, not for real use.")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .animation(.default, value: isSigningUp)
        }
    }

    private var canSubmit: Bool {
        let emailOK = !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let passwordOK = password.count >= 6
        let nameOK = !isSigningUp || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return emailOK && passwordOK && nameOK
    }

    private func submit() async {
        isSubmitting = true
        errorText = nil
        defer { isSubmitting = false }
        do {
            if isSigningUp {
                try await account.signUp(email: email, password: password, displayName: name)
            } else {
                try await account.signIn(email: email, password: password)
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func signInWithGoogle() async {
        isSubmitting = true
        errorText = nil
        defer { isSubmitting = false }
        do {
            try await account.signInWithGoogle()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func signInAsTestUser() async {
        isSubmitting = true
        errorText = nil
        defer { isSubmitting = false }
        do {
            try await account.signInAsTestUser()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
