//
//  OnboardingView.swift
//  FreshSnap
//
//  Created by Mack Low on 06/11/2026.
//

import SwiftUI
import AVFoundation
import UserNotifications
 
// FreshSnap – Week 7, Step 4
// Onboarding for new users, straight after sign-up (from the flow diagram):
// welcome -> camera access? -> allow notifications? -> dietary needs -> reminder time.
// Each permission is explained before iOS asks, because iOS only asks once.
 
struct OnboardingView: View {
    @Environment(AuthManager.self) private var auth
    @State private var page = 0
 
    @AppStorage(AppSettings.vegetarianKey) private var vegetarian = false
    @AppStorage(AppSettings.veganKey) private var vegan = false
    @AppStorage(AppSettings.nutFreeKey) private var nutFree = false
    @AppStorage(AppSettings.dairyFreeKey) private var dairyFree = false
    @AppStorage(AppSettings.reminderHourKey) private var reminderHour = 9
    @AppStorage(AppSettings.reminderMinuteKey) private var reminderMinute = 0
    @AppStorage(AppSettings.warnDaysKey) private var warnDays = 1
 
    private let lastPage = 4
 
    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: .now) ?? .now
        } set: { newTime in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: newTime)
            reminderHour = parts.hour ?? 9
            reminderMinute = parts.minute ?? 0
        }
    }
 
    var body: some View {
        TabView(selection: $page) {
            // 1. Welcome
            OnboardingPage(
                systemImage: "camera",
                title: auth.name.isEmpty ? "Welcome to FreshSnap" : "Welcome, \(auth.name)",
                message: "Snap your shopping receipt and FreshSnap keeps track of your food, reminds you before it goes off, and suggests meals to use it up."
            ) {
                Button("Get started") { next() }
                    .buttonStyle(.borderedProminent)
            }
            .tag(0)
 
            // 2. Camera
            OnboardingPage(
                systemImage: "camera.viewfinder",
                title: "Scan your shopping",
                message: "FreshSnap uses the camera to read receipts, use-by dates and barcodes. Photos are read on your phone, then discarded. They're never saved or uploaded."
            ) {
                Button("Allow camera") {
                    Task {
                        _ = await AVCaptureDevice.requestAccess(for: .video)
                        next()
                    }
                }
                .buttonStyle(.borderedProminent)
 
                Button("Not now") { next() }
            }
            .tag(1)
 
            // 3. Notifications
            OnboardingPage(
                systemImage: "bell.badge",
                title: "One reminder a day",
                message: "Get a single summary when food needs using, never a flood of alerts. You choose the time next."
            ) {
                Button("Allow notifications") {
                    Task {
                        await ReminderManager.requestPermission()
                        next()
                    }
                }
                .buttonStyle(.borderedProminent)
 
                Button("Not now") { next() }
            }
            .tag(2)
 
            // 4. Diet
            OnboardingPage(
                systemImage: "leaf",
                title: "Any dietary needs?",
                message: "Recipe ideas will leave out meals that don't suit you. You can change this any time in Preferences."
            ) {
                VStack(spacing: 0) {
                    Toggle("Vegetarian", isOn: $vegetarian)
                    Divider().padding(.vertical, 8)
                    Toggle("Vegan", isOn: $vegan)
                    Divider().padding(.vertical, 8)
                    Toggle("Nut-free", isOn: $nutFree)
                    Divider().padding(.vertical, 8)
                    Toggle("Dairy-free", isOn: $dairyFree)
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .onChange(of: vegan) { _, isVegan in
                    if isVegan { vegetarian = true }
                }
 
                Button("Continue") { next() }
                    .buttonStyle(.borderedProminent)
            }
            .tag(3)
 
            // 5. Reminder time
            OnboardingPage(
                systemImage: "clock",
                title: "When should we remind you?",
                message: "Pick a time that suits your day, like before you plan dinner."
            ) {
                VStack(spacing: 12) {
                    DatePicker("Daily reminder", selection: reminderTime, displayedComponents: .hourAndMinute)
                    Picker("Warn me", selection: $warnDays) {
                        Text("On the day").tag(0)
                        Text("1 day before").tag(1)
                        Text("2 days").tag(2)
                        Text("3 days").tag(3)
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
 
                Button("Start using FreshSnap") {
                    auth.finishOnboarding()
                }
                .buttonStyle(.borderedProminent)
            }
            .tag(4)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
 
    private func next() {
        withAnimation {
            page = min(page + 1, lastPage)
        }
    }
}
 
// One onboarding page: icon, title, explanation, then its buttons or controls.
struct OnboardingPage<Content: View>: View {
    let systemImage: String
    let title: String
    let message: String
    @ViewBuilder let content: Content
 
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
 
            Image(systemName: systemImage)
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
 
            Text(title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
 
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
 
            Spacer()
 
            VStack(spacing: 12) {
                content
            }
            .controlSize(.large)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 56)   // room for the page dots
    }
}
