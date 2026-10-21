//
//  AuthManager.swift
//  FreshSnap
//
//  Created by Mack Low on 21/10/2026.
//

import Foundation
import FirebaseAuth
import Observation
 
// FreshSnap – Week 5, Steps 4 to 6
// Talks to Firebase Authentication and keeps track of who is logged in.
// The screens read isLoggedIn, name and email from here.
 
@MainActor
@Observable
final class AuthManager {
    var isLoggedIn = false
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
        _ = try await Auth.auth().createUser(withEmail: email, password: password)
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
 
    func logOut() {
        try? Auth.auth().signOut()
        refresh()
    }
}
 
