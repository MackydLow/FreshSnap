//
//  FridgeView.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 21/10/2026.
//

import SwiftUI
 
// FreshSnap – Week 5, Steps 2 to 5
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
 
// MARK: - Placeholder screens (replaced in Week 6)
// FridgeView is in FridgeView.swift
 
struct RecipesView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No recipes yet",
                systemImage: "fork.knife",
                description: Text("Add food to your fridge to see meal ideas.")
            )
            .navigationTitle("Recipes")
            .profileButton()
        }
    }
}
 
struct ScanView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Scanning comes in Week 6",
                systemImage: "camera.viewfinder",
                description: Text("Receipt, label and barcode scanning will live here.")
            )
            .navigationTitle("Scan")
            .profileButton()
        }
    }
}
 
// Profile slides in on top of the current tab, with a back button.
struct ProfileView: View {
    @Environment(AuthManager.self) private var auth
 
    var body: some View {
        List {
            Section("Your details") {
                LabeledContent("Name", value: auth.name)
                LabeledContent("Email", value: auth.email)
            }
 
            Section {
                Button("Log out", role: .destructive) {
                    auth.logOut()
                }
            }
        }
        .navigationTitle("Profile")
    }
}
