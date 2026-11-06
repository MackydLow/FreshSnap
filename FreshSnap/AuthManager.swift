//
//  AuthManager.swift
//  FreshSnap
//
//  Created by Mack Low on 21/10/2026.
//

import Foundation
import FirebaseAuth
import Observation
 
// FreshSnap – Week 5, Steps 4 to 6 (Week 7: onboarding, edit details, delete account)
// Talks to Firebase Authentication and keeps track of who is logged in.
// The screens read isLoggedIn, name and email from here.
 
@MainActor
@Observable
final class AuthManager {
    var isLoggedIn = false
    var justSignedUp = false   // new users see onboarding before the tabs
    var userID = ""
    var name = ""
    var email = ""
 
    @ObservationIgnored private var listener: AuthStateDidChangeListenerHandle?
 
    init() {
        refresh()
        // Firebase tells us whenever someone logs in or out.
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
            guard let self else { return }
            Task { @MainActor in self.refresh() }
        }
    }
 
    // Copies the current user's details into the properties the screens use.
    func refresh() {
        let user = Auth.auth().currentUser
        isLoggedIn = user != nil
        userID = user?.uid ?? ""
        name = user?.displayName ?? ""
        email = user?.email ?? ""
    }
 
    // Sign up: create the account, then save the user's name on it.
    func signUp(name: String, email: String, password: String) async throws {
        // Set first, so the tabs never flash up before onboarding
        justSignedUp = true
        do {
            _ = try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            justSignedUp = false
            throw error
        }
        if let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest() {
            changeRequest.displayName = name
            try await changeRequest.commitChanges()
        }
        refresh()
    }
 
    func logIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
        refresh()
    }
 
    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
 
    // MARK: Profile extras (Week 7)
 
    func updateName(_ name: String) async throws {
        guard let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest() else { return }
        changeRequest.displayName = name
        try await changeRequest.commitChanges()
        refresh()
    }
 
    // Firebase asks for the password again before sensitive changes.
    private func confirmPassword(_ password: String) async throws {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            throw URLError(.userAuthenticationRequired)
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        _ = try await user.reauthenticate(with: credential)
    }
 
    // Sends a link to the new address; the email changes once it's tapped.
    func requestEmailChange(to newEmail: String, password: String) async throws {
        try await confirmPassword(password)
        try await Auth.auth().currentUser?.sendEmailVerification(beforeUpdatingEmail: newEmail)
    }
 
    func deleteAccount(password: String) async throws {
        try await confirmPassword(password)
        try await Auth.auth().currentUser?.delete()
        justSignedUp = false
        refresh()
    }
 
    // Called at the end of onboarding
    func finishOnboarding() {
        justSignedUp = false
    }
 
    func logOut() {
        justSignedUp = false
        try? Auth.auth().signOut()
        refresh()
    }
}
 
