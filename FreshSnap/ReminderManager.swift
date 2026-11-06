//
//  ReminderManager.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 21/10/2026.
//

import Foundation
import UserNotifications
import Observation
 
// FreshSnap – Week 5, Step 10 (Week 7: Settings, and tapping opens expiring food)
// One daily summary of food that needs using, instead of one alert per item.
// Scheduled on the phone (local notifications), so it works offline.
 
@MainActor
enum ReminderManager {
    static let daysAhead = 7             // keeps well under iOS's 64-notification limit
    // The reminder time and warning period come from Settings (Week 7)
 
    // Asks for permission. iOS only shows this pop-up once.
    static func requestPermission() async {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }
 
    // Replaces the next 7 days of reminders using the food currently in the fridge.
    static func scheduleReminders(for food: [FoodItem]) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (0..<daysAhead).map { "daily-\($0)" })
 
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
 
        for dayOffset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today),
                  let fireDate = calendar.date(bySettingHour: AppSettings.reminderHour,
                                               minute: AppSettings.reminderMinute, second: 0, of: day),
                  fireDate > .now else { continue }
 
            // Food that must be used within the chosen warning period
            let dueSoon = food.filter {
                let expiry = calendar.startOfDay(for: $0.expiryDate)
                let days = calendar.dateComponents([.day], from: day, to: expiry).day ?? 0
                return days >= 0 && days <= AppSettings.warnDays
            }
            guard !dueSoon.isEmpty else { continue }
 
            let content = UNMutableNotificationContent()
            content.title = "Use it before you lose it"
            content.body = summary(of: dueSoon)
            content.sound = .default
 
            let when = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            center.add(UNNotificationRequest(identifier: "daily-\(dayOffset)", content: content, trigger: trigger))
        }
    }
 
    // For testing: sends today's summary 5 seconds from now.
    static func sendTestReminder(for food: [FoodItem]) {
        let dueSoon = food.filter { $0.daysLeft <= AppSettings.warnDays }
 
        let content = UNMutableNotificationContent()
        content.title = "Use it before you lose it"
        content.body = dueSoon.isEmpty
            ? "Nothing needs using soon."
            : summary(of: dueSoon)
        content.sound = .default
 
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: "test", content: content, trigger: trigger))
    }
 
    // Removes all reminders, e.g. when the user logs out.
    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
 
    // "Your chicken and spinach need using soon."
    private static func summary(of items: [FoodItem]) -> String {
        let names = items.map(\.name)
        switch names.count {
        case 1:
            return "Your \(names[0]) needs using soon."
        case 2:
            return "Your \(names[0]) and \(names[1]) need using soon."
        default:
            return "Your \(names[0]), \(names[1]) and \(names.count - 2) more need using soon."
        }
    }
}
 
// The three tabs, so the app can switch tab by itself
enum AppTab: Hashable {
    case fridge, recipes, scan
}
 
// Lets parts of the app ask for a tab or view to open (e.g. from a reminder).
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()
 
    var selectedTab: AppTab = .fridge
    var showExpiringSoon = false
 
    func openExpiringSoon() {
        selectedTab = .fridge
        showExpiringSoon = true
    }
}
 
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
 
    // Shows reminders as a banner even while FreshSnap is open.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
 
    // Tapping a reminder opens the Fridge, filtered to food expiring soon.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        await MainActor.run {
            AppRouter.shared.openExpiringSoon()
        }
    }
}
