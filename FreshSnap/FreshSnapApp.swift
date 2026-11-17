//
//  FreshSnapApp.swift
//  FreshSnap
//
//  Created by Mack Low on 21/10/2026.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAppCheck
import UserNotifications

@main
struct FreshSnapApp: App {
    @State private var auth: AuthManager

    init() {
        // App Check protects the AI service. While testing from Xcode, the debug provider
        // prints a token in the console that's registered in the Firebase console.
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #endif

        // Firebase must start before AuthManager uses it.
        FirebaseApp.configure()
        _auth = State(initialValue: AuthManager())
        // Set at launch so tapping a reminder works even when the app was closed
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FoodItem.self,
            FavouriteRecipe.self,   // Week 9
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
