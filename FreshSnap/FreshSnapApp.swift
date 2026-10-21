//
//  FreshSnapApp.swift
//  FreshSnap
//
//  Created by Mack Low on 21/10/2026.
//

import SwiftUI
import SwiftData
import FirebaseCore
 
@main
struct FreshSnapApp: App {
    @State private var auth: AuthManager
 
    init() {
        // Firebase must start before AuthManager uses it.
        FirebaseApp.configure()
        _auth = State(initialValue: AuthManager())
    }
 
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FoodItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
 
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
 
    var body: some Scene {
        WindowGroup {
            // Shows Welcome when logged out, and the tabs when logged in.
            RootView()
                .environment(auth)
        }
        .modelContainer(sharedModelContainer)
    }
}
