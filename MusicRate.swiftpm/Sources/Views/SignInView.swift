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
                if !FirebaseConfig.isConfigured {
                    Section {
                        Text("MusicRate isn't connected to a Firebase project yet. Add your API key and project ID in FirebaseConfig.swift.")
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
                        Text(errorText).foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text(isSigningUp ? "Create Account" : "Sign In")
                        }
                    }
                    .disabled(!canSubmit || isSubmitting)
                }

                Section {
                    Button(isSigningUp ? "Already have an account? Sign In" : "New here? Create an Account") {
                        isSigningUp.toggle()
                        errorText = nil
                    }
                }
            }
            .navigationTitle(isSigningUp ? "Create Account" : "Sign In")
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
}
