//
//  SettingsView.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 06/11/2026.
//

import SwiftUI
import SwiftData
import UserNotifications
 
// FreshSnap – Week 7, Step 3
// Settings (app map: Profile -> Settings -> Reminders, Diet, Privacy).
// Choices are saved on the phone and remembered between launches.
 
// The saved settings, readable from anywhere in the app.
enum AppSettings {
    static let reminderHourKey = "reminderHour"
    static let reminderMinuteKey = "reminderMinute"
    static let warnDaysKey = "warnDaysBefore"
    static let vegetarianKey = "dietVegetarian"
    static let veganKey = "dietVegan"
    static let nutFreeKey = "dietNutFree"
    static let dairyFreeKey = "dietDairyFree"
 
    static var reminderHour: Int {
        UserDefaults.standard.object(forKey: reminderHourKey) as? Int ?? 9
    }
 
    static var reminderMinute: Int {
        UserDefaults.standard.object(forKey: reminderMinuteKey) as? Int ?? 0
    }
 
    // Warn about food with this many days or fewer left (1 = the day before)
    static var warnDays: Int {
        UserDefaults.standard.object(forKey: warnDaysKey) as? Int ?? 1
    }
}
 
struct SettingsView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.openURL) private var openURL
    @Query private var allFood: [FoodItem]
 
    @AppStorage(AppSettings.reminderHourKey) private var reminderHour = 9
    @AppStorage(AppSettings.reminderMinuteKey) private var reminderMinute = 0
    @AppStorage(AppSettings.warnDaysKey) private var warnDays = 1
 
    @AppStorage(AppSettings.vegetarianKey) private var vegetarian = false
    @AppStorage(AppSettings.veganKey) private var vegan = false
    @AppStorage(AppSettings.nutFreeKey) private var nutFree = false
    @AppStorage(AppSettings.dairyFreeKey) private var dairyFree = false
 
    @State private var notificationsAllowed = true
 
    private var fridge: [FoodItem] {
        allFood.filter { $0.ownerID == auth.userID && $0.status == .inFridge }
    }
 
    // The reminder time as a Date for the time picker
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
        Form {
            // MARK: Reminders
            Section {
                if !notificationsAllowed {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Notifications are off for FreshSnap", systemImage: "bell.slash")
                            .foregroundStyle(.red)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                    }
                }
 
                DatePicker("Daily reminder", selection: reminderTime, displayedComponents: .hourAndMinute)
 
                Picker("Warn me", selection: $warnDays) {
                    Text("On the day").tag(0)
                    Text("1 day before").tag(1)
                    Text("2 days before").tag(2)
                    Text("3 days before").tag(3)
                }
 
                Button("Send a test reminder") {
                    ReminderManager.sendTestReminder(for: fridge)
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text("One summary a day, only when food needs using. The test reminder arrives in 5 seconds.")
            }
 
            // MARK: Diet
            Section {
                Toggle("Vegetarian", isOn: $vegetarian)
                Toggle("Vegan", isOn: $vegan)
                Toggle("Nut-free", isOn: $nutFree)
                Toggle("Dairy-free", isOn: $dairyFree)
            } header: {
                Text("Diet")
            } footer: {
                Text("Recipe ideas will leave out meals that don't suit these needs. Always check ingredients yourself if you have an allergy.")
            }
 
            // MARK: Privacy
            Section {
                Label("Receipt photos are read on your phone, then discarded. They're never saved or uploaded.",
                      systemImage: "doc.text.viewfinder")
                Label("Your fridge, money saved and settings are stored only on this iPhone.",
                      systemImage: "iphone")
                Label("Your name, email and password are handled by Firebase so you can log in.",
                      systemImage: "person.badge.key")
                Label("Barcodes and food names are sent to Open Food Facts and TheMealDB to look up products and recipes.",
                      systemImage: "network")
            } header: {
                Text("Privacy")
            }
            .font(.subheadline)
        }
        .navigationTitle("Settings")
        .task {
            await checkNotifications()
        }
        // Reschedule straight away when the time or warning changes
        .onChange(of: reminderHour) { ReminderManager.scheduleReminders(for: fridge) }
        .onChange(of: reminderMinute) { ReminderManager.scheduleReminders(for: fridge) }
        .onChange(of: warnDays) { ReminderManager.scheduleReminders(for: fridge) }
        // Vegan food is always vegetarian too
        .onChange(of: vegan) { _, isVegan in
            if isVegan { vegetarian = true }
        }
    }
 
    private func checkNotifications() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsAllowed = settings.authorizationStatus != .denied
    }
}
