//
//  FridgeView.swift
//  FreshSnap
//
//  Created by Mack Low on 06/11/2026.
//

import SwiftUI
import SwiftData

// FreshSnap – Week 5, Steps 8 to 10 (Week 7, Steps 1, 2 and 5; Week 8: search, Scan button, accessibility; Week 9: freezer)
// The virtual fridge: food you still have, with "Filter and ordering"
// (flow: ordering or filtering? -> order by name or use-by date / filter -> view products with changes).

enum FridgeOrder: String, CaseIterable, Identifiable {
    case useBy = "Use-by date"
    case name = "Name (A–Z)"
    case recentlyAdded = "Recently added"

    var id: Self { self }
}

enum FridgeFilter: Hashable {
    case all
    case expiringSoon
    case frozen
    case category(String)

    var title: String {
        switch self {
        case .all: return "All food"
        case .expiringSoon: return "Expiring soon"
        case .frozen: return "In the freezer"
        case .category(let name): return name
        }
    }
}

struct FridgeView: View {
    @Environment(AuthManager.self) private var auth
    @Query(sort: \FoodItem.expiryDate) private var allFood: [FoodItem]

    @AppStorage("fridgeOrder") private var order: FridgeOrder = .useBy   // remembered between visits
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filter: FridgeFilter = .all
    @State private var showingAddFood = false
    @State private var searchText = ""

    // Only this user's food that is still in the fridge.
    private var fridge: [FoodItem] {
        allFood.filter { $0.ownerID == auth.userID && $0.status == .inFridge }
    }

    // The fridge after the search, the chosen filter and order
    private var visibleFood: [FoodItem] {
        var filtered: [FoodItem]
        switch filter {
        case .all: filtered = fridge
        case .expiringSoon: filtered = fridge.filter { $0.daysLeft <= 2 }
        case .frozen: filtered = fridge.filter { $0.frozenDate != nil }
        case .category(let name): filtered = fridge.filter { $0.category == name }
        }

        let search = searchText.trimmingCharacters(in: .whitespaces)
        if !search.isEmpty {
            filtered = filtered.filter { $0.name.localizedCaseInsensitiveContains(search) }
        }

        switch order {
        case .useBy:
            return filtered.sorted { $0.expiryDate < $1.expiryDate }
        case .name:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .recentlyAdded:
            return filtered.sorted { $0.addedDate > $1.addedDate }
        }
    }

    // Categories that actually have food in them
    private var categoriesInFridge: [String] {
        FoodCategory.all.filter { category in fridge.contains { $0.category == category } }
    }

    // Changes whenever any food's name or date changes
    private var reminderKey: String {
        fridge.map { "\($0.name)|\($0.expiryDate.timeIntervalSince1970)" }.joined(separator: ",")
    }

    // Two columns normally; one column at the largest (accessibility) text sizes
    private var columns: [GridItem] {
        let count = textSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var body: some View {
        NavigationStack {
            Group {
                if fridge.isEmpty {
                    ContentUnavailableView {
                        Label("Your fridge is empty", systemImage: "refrigerator")
                    } description: {
                        Text("Scan a receipt or add food by hand.")
                    } actions: {
                        Button("Add food") { showingAddFood = true }
                            .buttonStyle(.borderedProminent)
                        // Tester feedback: a quick way to the Scan tab
                        Button("Scan your shopping") {
                            AppRouter.shared.selectedTab = .scan
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            toolbarRow
                            if filter != .all {
                                filterBar
                            }

                            if visibleFood.isEmpty {
                                if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                                    ContentUnavailableView {
                                        Label("No matches", systemImage: "magnifyingglass")
                                    } description: {
                                        Text("No food in your fridge matches \"\(searchText)\".")
                                    } actions: {
                                        Button("Clear search") { searchText = "" }
                                    }
                                } else {
                                    ContentUnavailableView {
                                        Label("Nothing matches", systemImage: "line.3.horizontal.decrease.circle")
                                    } description: {
                                        Text("No food in your fridge is \(filter.title.lowercased()).")
                                    } actions: {
                                        Button("Show all food") { filter = .all }
                                    }
                                }
                            } else {
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(visibleFood) { food in
                                        NavigationLink {
                                            FoodDetailView(food: food)
                                        } label: {
                                            FoodCard(food: food)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                                // Cards slide into place when the order, filter or fridge changes
                                // (no movement if the user has turned on Reduce Motion)
                                .animation(reduceMotion ? nil : .snappy, value: visibleFood.map(\.persistentModelID))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Fridge")
            // Tester feedback: search the fridge by name
            .searchable(text: $searchText, prompt: "Search your fridge")
            .profileButton()
            .sheet(isPresented: $showingAddFood) {
                AddProductView(ownerID: auth.userID)
            }
            .onChange(of: categoriesInFridge) { _, categories in
                // If the filtered category is now empty, go back to all food
                if case .category(let name) = filter, !categories.contains(name) {
                    filter = .all
                }
            }
            .task {
                await ReminderManager.requestPermission()
            }
            // Opened from a reminder: show food that's expiring soon
            .onAppear(perform: showExpiringSoonIfAsked)
            .onChange(of: AppRouter.shared.showExpiringSoon) { _, asked in
                if asked { showExpiringSoonIfAsked() }
            }
            // Reschedule reminders when food is added, edited, used or thrown away
            .task(id: reminderKey) {
                ReminderManager.scheduleReminders(for: fridge)
            }
        }
    }

    private func showExpiringSoonIfAsked() {
        guard AppRouter.shared.showExpiringSoon else { return }
        withAnimation(.snappy) { filter = .expiringSoon }
        AppRouter.shared.showExpiringSoon = false
    }

    // MARK: "Filter and ordering" on the left, add on the right (as in the wireframe)

    private var toolbarRow: some View {
        HStack {
            Menu {
                Section("Order by") {
                    Picker("Order by", selection: $order) {
                        ForEach(FridgeOrder.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.inline)
                }

                Section("Show") {
                    Picker("Show", selection: $filter) {
                        Text(FridgeFilter.all.title).tag(FridgeFilter.all)
                        Text(FridgeFilter.expiringSoon.title).tag(FridgeFilter.expiringSoon)
                        if fridge.contains(where: { $0.frozenDate != nil }) {
                            Text(FridgeFilter.frozen.title).tag(FridgeFilter.frozen)
                        }
                        ForEach(categoriesInFridge, id: \.self) { category in
                            Text(category).tag(FridgeFilter.category(category))
                        }
                    }
                    .pickerStyle(.inline)
                }
            } label: {
                Label("Filter and ordering",
                      systemImage: filter == .all
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill")
            }

            Spacer()

            Button {
                showingAddFood = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2)
            }
            .accessibilityLabel("Add food")
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    // Shows what's being viewed, with a way back to everything
    private var filterBar: some View {
        HStack {
            Text("Showing: \(filter.title) (\(visibleFood.count))")
                .font(.subheadline)
            Spacer()
            Button("Show all") {
                withAnimation(.snappy) { filter = .all }
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}

struct FoodCard: View {
    let food: FoodItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(food.name)
                .font(.headline)
                .lineLimit(2)
            Text(food.expiryText)
                .font(.subheadline)
                .foregroundStyle(food.daysLeft <= 1 ? .red : .secondary)
            if !food.amount.isEmpty {
                Text(food.amount)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if food.frozenDate != nil {
                Label("Frozen", systemImage: "snowflake")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        // VoiceOver reads the card as one item: "Chicken, Use tomorrow, 2 pack"
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens this food's details")
    }
}
