//
//  FridgeView.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 21/10/2026.
//

import SwiftUI
import SwiftData
 
// FreshSnap – Weeks 5 and 6
// Three tabs: Fridge, Recipes and Scan.
// Profile opens from a button in the top-right corner of every screen.
 
struct ContentView: View {
    var body: some View {
        TabView {
            FridgeView()
                .tabItem { Label("Fridge", systemImage: "refrigerator") }
 
            RecipesView()
                .tabItem { Label("Recipes", systemImage: "fork.knife") }
 
            ScanView()
                .tabItem { Label("Scan", systemImage: "camera.viewfinder") }
        }
    }
}
 
// MARK: - Profile button (top right on every screen)
 
struct ProfileButton: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ProfileView()
                } label: {
                    Image(systemName: "person.crop.circle")
                        .accessibilityLabel("Profile")
                }
            }
        }
    }
}
 
extension View {
    func profileButton() -> some View {
        modifier(ProfileButton())
    }
}
 
// FridgeView, RecipesView and ScanView each live in their own files.
 
// Profile slides in on top of the current tab, with a back button.
struct ProfileView: View {
    @Environment(AuthManager.self) private var auth
    @Query private var allFood: [FoodItem]
 
    // Only this user's food
    private var myFood: [FoodItem] {
        allFood.filter { $0.ownerID == auth.userID }
    }
 
    private var moneySaved: Double {
        myFood.filter { $0.status == .used }.reduce(0) { $0 + $1.price }
    }
 
    private var usedCount: Int {
        myFood.filter { $0.status == .used }.count
    }
 
    private var thrownAwayCount: Int {
        myFood.filter { $0.status == .thrownAway }.count
    }
 
    var body: some View {
        List {
            Section("Money saved") {
                Text(moneySaved, format: .currency(code: "GBP"))
                    .font(.largeTitle.bold())
                LabeledContent("Food used", value: "\(usedCount)")
                LabeledContent("Food thrown away", value: "\(thrownAwayCount)")
            }
 
            Section("Your details") {
                LabeledContent("Name", value: auth.name)
                LabeledContent("Email", value: auth.email)
            }
 
            Section {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            } footer: {
                Text("Reminder time, diet and privacy.")
            }
 
            Section {
                Button("Log out", role: .destructive) {
                    ReminderManager.cancelAll()
                    auth.logOut()
                }
            }
        }
        .navigationTitle("Profile")
    }
}
