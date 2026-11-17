//
//  Badges.swift
//  FreshSnap
//
//  Created by Mack Low on 17/11/2026.
//

import SwiftUI

// FreshSnap – Week 9, Upgrade 4
// Streaks and badges on Profile. Everything is worked out from the food already
// saved, apart from how many times "I cooked this" was used, which is counted here.

extension AppSettings {
    private static func cookedKey(for userID: String) -> String { "cookedCount-\(userID)" }

    static func cookedCount(for userID: String) -> Int {
        UserDefaults.standard.integer(forKey: cookedKey(for: userID))
    }

    static func recordCooked(for userID: String) {
        UserDefaults.standard.set(cookedCount(for: userID) + 1, forKey: cookedKey(for: userID))
    }
}

struct Badge: Identifiable {
    let id: String
    let name: String
    let systemImage: String
    let howToEarn: String
    let earned: Bool
}

struct BadgesSection: View {
    let food: [FoodItem]          // this user's food
    let favouriteCount: Int
    let cookedCount: Int

    @Environment(\.dynamicTypeSize) private var textSize

    private var used: [FoodItem] { food.filter { $0.status == .used } }
    private var moneySaved: Double { used.reduce(0) { $0 + $1.price } }

    // MARK: No-waste streak

    // Days since food was last thrown away (or since the first food was added)
    private var streakDays: Int? {
        let calendar = Calendar.current
        let lastThrown = food.filter { $0.status == .thrownAway }.map(\.finishedDay).max()
        guard let start = lastThrown ?? food.map(\.addedDate).min() else { return nil }
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: start),
                                           to: calendar.startOfDay(for: .now)).day ?? 0
        return max(days, 0)
    }

    private var threwAwayToday: Bool {
        food.contains { $0.status == .thrownAway && Calendar.current.isDateInToday($0.finishedDay) }
    }

    // MARK: Badges

    private var badges: [Badge] {
        [
            Badge(id: "stocked", name: "Stocked up", systemImage: "cart.fill",
                  howToEarn: "Add 10 items to your fridge", earned: food.count >= 10),
            Badge(id: "first", name: "First save", systemImage: "leaf.fill",
                  howToEarn: "Use your first item before it goes off", earned: used.count >= 1),
            Badge(id: "warrior", name: "Waste warrior", systemImage: "shield.fill",
                  howToEarn: "Use 25 items", earned: used.count >= 25),
            Badge(id: "chef", name: "Chef", systemImage: "frying.pan.fill",
                  howToEarn: "Cook a recipe with \"I cooked this\"", earned: cookedCount >= 1),
            Badge(id: "saver", name: "Money saver", systemImage: "sterlingsign.circle.fill",
                  howToEarn: "Save £10", earned: moneySaved >= 10),
            Badge(id: "week", name: "Zero-waste week", systemImage: "flame.fill",
                  howToEarn: "Go 7 days without throwing food away", earned: (streakDays ?? 0) >= 7),
            Badge(id: "freezer", name: "Freezer fan", systemImage: "snowflake",
                  howToEarn: "Move something to the freezer", earned: food.contains { $0.frozenDate != nil }),
            Badge(id: "foodie", name: "Foodie", systemImage: "heart.fill",
                  howToEarn: "Save a favourite recipe", earned: favouriteCount >= 1)
        ]
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: textSize.isAccessibilitySize ? 220 : 96), spacing: 12)]
    }

    var body: some View {
        Section {
            // Streak
            if let streakDays {
                HStack(spacing: 12) {
                    Image(systemName: "flame.fill")
                        .font(.title)
                        .foregroundStyle(streakDays > 0 ? .orange : .secondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        if threwAwayToday {
                            Text("Streak reset today")
                                .font(.headline)
                            Text("Use everything tomorrow to start a new one.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(streakDays == 1 ? "1 day without wasting food" : "\(streakDays) days without wasting food")
                                .font(.headline)
                            Text("Keep going: don't throw anything away.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }

            // Badges
            let earnedCount = badges.filter(\.earned).count
            VStack(alignment: .leading, spacing: 12) {
                Text("\(earnedCount) of \(badges.count) badges earned")
                    .font(.subheadline.weight(.semibold))

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(badges) { badge in
                        BadgeTile(badge: badge)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Streaks and badges")
        } footer: {
            Text("Locked badges show how to earn them.")
        }
    }
}

private struct BadgeTile: View {
    let badge: Badge

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(badge.earned ? Color.accentColor.opacity(0.15) : Color(.tertiarySystemFill))
                    .frame(width: 52, height: 52)
                Image(systemName: badge.earned ? badge.systemImage : "lock.fill")
                    .font(.title3)
                    .foregroundStyle(badge.earned ? Color.accentColor : .secondary)
            }
            Text(badge.name)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
            if !badge.earned {
                Text(badge.howToEarn)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        // VoiceOver: "Chef, earned" or "Chef, locked. Cook a recipe…"
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(badge.earned ? "\(badge.name), earned" : "\(badge.name), locked. \(badge.howToEarn)")
    }
}
