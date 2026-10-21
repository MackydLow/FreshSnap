//
//  AuthViews.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 21/10/2026.
//

import SwiftUI
 
// FreshSnap – Week 5, Steps 4 and 5
// The screens from the "Login or sign up" flow diagram.
 
// MARK: - Root: Welcome when logged out, the main tabs when logged in
 
struct RootView: View {
    @Environment(AuthManager.self) private var auth
 
    var body: some View {
        if auth.isLoggedIn {
            ContentView()
        } else {
            WelcomeView()
        }
    }
}
 
// MARK: - Welcome
 
struct WelcomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
 
                Image(systemName: "camera")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("FreshSnap")
                    .font(.largeTitle.bold())
                Text("Snap your shop. Waste less food.")
                    .foregroundStyle(.secondary)
 
                Spacer()
 
                NavigationLink {
                    SignUpView()
                } label: {
                    Text("Sign up").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
 
                NavigationLink {
                    LoginView()
                } label: {
                    Text("Log in").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
            .padding()
        }
    }
}
 
// MARK: - Sign up
 
struct SignUpView: View {
    @Environment(AuthManager.self) private var auth
 
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isWorking = false
 
    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !email.trimmingCharacters(in: .whitespaces).isEmpty
            && password.count >= 6
    }
 
    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .textContentType(.name)
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
            } footer: {
                Text("Your password needs at least 6 characters.")
            }
 
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
 
            Section {
                Button {
                    Task { await signUp() }
                } label: {
                    if isWorking {
                        ProgressView()
                    } else {
                        Text("Create account")
                    }
                }
                .disabled(!canSubmit || isWorking)
            }
        }
        .navigationTitle("Sign up")
    }
 
    private func signUp() async {
        isWorking = true
        errorMessage = nil
        do {
            try await auth.signUp(
                name: name.trimmingCharacters(in: .whitespaces),
                email: email.trimmingCharacters(in: .whitespaces),
                password: password
            )
        } catch {
            // e.g. "The email address is already in use by another account."
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}
 
// MARK: - Login
 
struct LoginView: View {
    @Environment(AuthManager.self) private var auth
 
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isWorking = false
 
    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                    .textContentType(.password)
            }
 
            // "Details correct?" – No: show a message and let them try again
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
 
            Section {
                Button {
                    Task { await logIn() }
                } label: {
                    if isWorking {
                        ProgressView()
                    } else {
                        Text("Log in")
                    }
                }
                .disabled(email.isEmpty || password.isEmpty || isWorking)
 
                NavigationLink("Forgot password?") {
                    ForgotPasswordView()
                }
            }
        }
        .navigationTitle("Log in")
    }
 
    private func logIn() async {
        isWorking = true
        errorMessage = nil
        do {
            try await auth.logIn(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password
            )
        } catch {
            errorMessage = "Email or password is incorrect. Try again, or reset your password."
        }
        isWorking = false
    }
}
 
// MARK: - Forgot password
 
struct ForgotPasswordView: View {
    @Environment(AuthManager.self) private var auth
 
    @State private var email = ""
    @State private var message: String?
    @State private var isWorking = false
 
    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text("We'll email you a link to choose a new password.")
            }
 
            if let message {
                Section {
                    Text(message)
                }
            }
 
            Section {
                Button {
                    Task { await sendLink() }
                } label: {
                    if isWorking {
                        ProgressView()
                    } else {
                        Text("Send reset link")
                    }
                }
                .disabled(email.isEmpty || isWorking)
            }
        }
        .navigationTitle("Reset password")
    }
 
    private func sendLink() async {
        isWorking = true
        do {
            try await auth.sendPasswordReset(email: email.trimmingCharacters(in: .whitespaces))
            message = "If an account uses that email, a reset link is on its way. Check your junk folder too."
        } catch {
            message = error.localizedDescription
        }
        isWorking = false
    }
}
 
