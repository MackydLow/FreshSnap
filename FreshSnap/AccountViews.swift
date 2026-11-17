//
//  AccountViews.swift
//  FreshSnap
//
//  Created by Mack Low on 06/11/2026.
//

import SwiftUI
import SwiftData

// FreshSnap – Week 7, Step 5
// Profile extras: change name or email (flow: "Change name or email? -> Yes"),
// and delete account (required by Apple for apps with sign-up).

// MARK: - Edit name or email

struct EditDetailsView: View {
    @Environment(AuthManager.self) private var auth

    @State private var name = ""
    @State private var newEmail = ""
    @State private var password = ""
    @State private var nameMessage: String?
    @State private var emailMessage: String?
    @State private var emailFailed = false
    @State private var isWorking = false

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .textContentType(.name)
                Button("Save name") {
                    Task { await saveName() }
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty
                          || name == auth.name || isWorking)
                if let nameMessage {
                    Text(nameMessage).foregroundStyle(.green)
                }
            } header: {
                Text("Name")
            }

            Section {
                LabeledContent("Current email", value: auth.email)
                TextField("New email", text: $newEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Your password", text: $password)
                    .textContentType(.password)
                Button("Send confirmation link") {
                    Task { await changeEmail() }
                }
                .disabled(newEmail.isEmpty || password.isEmpty || isWorking)
                if let emailMessage {
                    Text(emailMessage).foregroundStyle(emailFailed ? .red : .green)
                }
            } header: {
                Text("Email")
            } footer: {
                Text("We'll email a link to your new address. Your email only changes once you tap it, and you may need to log in again afterwards.")
            }
        }
        .navigationTitle("Edit details")
        .onAppear { name = auth.name }
    }

    private func saveName() async {
        isWorking = true
        do {
            try await auth.updateName(name.trimmingCharacters(in: .whitespaces))
            nameMessage = "Name saved."
        } catch {
            nameMessage = nil
        }
        isWorking = false
    }

    private func changeEmail() async {
        isWorking = true
        do {
            try await auth.requestEmailChange(to: newEmail.trimmingCharacters(in: .whitespaces),
                                              password: password)
            emailFailed = false
            emailMessage = "Check \(newEmail) for a confirmation link."
            password = ""
        } catch {
            emailFailed = true
            emailMessage = "Couldn't change your email. Check your password and the new address, then try again."
        }
        isWorking = false
    }
}

// MARK: - Delete account

struct DeleteAccountView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.modelContext) private var modelContext
    @Query private var allFood: [FoodItem]
    @Query private var allFavourites: [FavouriteRecipe]

    @State private var password = ""
    @State private var confirming = false
    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        Form {
            Section {
                Text("This permanently deletes your FreshSnap account, the food saved in your fridge on this iPhone, your money saved, and your reminders. It can't be undone.")
            }

            Section {
                SecureField("Your password", text: $password)
                    .textContentType(.password)
            } footer: {
                Text("For your security, enter your password to confirm it's you.")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }

            Section {
                Button("Delete account", role: .destructive) {
                    confirming = true
                }
                .disabled(password.isEmpty || isWorking)
            }
        }
        .navigationTitle("Delete account")
        .confirmationDialog("Delete your account?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("Everything will be deleted. This can't be undone.")
        }
    }

    private func deleteAccount() async {
        isWorking = true
        errorMessage = nil
        let userID = auth.userID
        let myFood = allFood.filter { $0.ownerID == userID }

        do {
            // Delete the Firebase account first, so nothing is lost if this fails
            try await auth.deleteAccount(password: password)
            for item in myFood {
                modelContext.delete(item)
            }
            for favourite in allFavourites where favourite.ownerID == userID {
                modelContext.delete(favourite)
            }
            ReminderManager.cancelAll()
        } catch {
            errorMessage = "Couldn't delete your account. Check your password and internet connection, then try again."
        }
        isWorking = false
    }
}
