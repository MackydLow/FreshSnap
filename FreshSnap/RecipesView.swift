//
//  RecipesView.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 06/11/2026.
//

import SwiftUI
import SwiftData

// FreshSnap – Week 6, Step 6 (Week 7: diet filter; Week 9: all recipes shown, chips filter, more recipes)
// The Recipes tab: meal ideas from TheMealDB using food that needs eating first.
// Flow: view recipes -> filter by ingredients -> click on recipe to view it.

struct RecipeResult: Identifiable {
    let meal: MealSummary
    var uses: [String]          // fridge food this meal uses
    var soonestDaysLeft: Int    // how urgent that food is

    var id: String { meal.id }
}

struct RecipesView: View {
    @Environment(AuthManager.self) private var auth
    @Query(sort: \FoodItem.expiryDate) private var allFood: [FoodItem]

    // Week 9: every recipe for the fridge is loaded; chips only filter them
    @State private var selected: Set<String> = []          // food names
    @State private var allResults: [RecipeResult] = []
    @State private var isLoading = false
    @State private var loadingMessage = "Finding recipes…"
    @State private var failed = false

    // Diet choices from Preferences; changing them reloads the recipes
    @AppStorage(AppSettings.vegetarianKey) private var vegetarian = false
    @AppStorage(AppSettings.veganKey) private var vegan = false
    @AppStorage(AppSettings.nutFreeKey) private var nutFree = false
    @AppStorage(AppSettings.dairyFreeKey) private var dairyFree = false

    private var diet: DietNeeds {
        DietNeeds(vegetarian: vegetarian, vegan: vegan, nutFree: nutFree, dairyFree: dairyFree)
    }

    private let maxFoodsSearched = 25   // soonest-expiring foods searched
    private let maxDietChecks = 80      // recipes checked behind the scenes for the diet

    @Environment(\.dynamicTypeSize) private var textSize

    // Two columns normally; one column at the largest (accessibility) text sizes
    private var columns: [GridItem] {
        let count = textSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    private var fridge: [FoodItem] {
        allFood.filter { $0.ownerID == auth.userID && $0.status == .inFridge }
    }

    // One chip per food name (two packs of chicken make one chip), soonest first
    private struct FoodChip {
        let name: String
        let expiryText: String
    }

    private var foodNames: [FoodChip] {
        var seen: Set<String> = []
        var chips: [FoodChip] = []
        for food in fridge where seen.insert(food.name).inserted {
            chips.append(FoodChip(name: food.name, expiryText: food.expiryText))
        }
        return chips
    }

    // The recipes shown: all of them, or only those using every chosen food
    private var shownResults: [RecipeResult] {
        guard !selected.isEmpty else { return allResults }
        return allResults.filter { selected.isSubset(of: Set($0.uses)) }
    }

    // Reload only when the fridge or diet changes; tapping chips filters instantly
    private var loadKey: String {
        foodNames.prefix(maxFoodsSearched).map(\.name).joined(separator: "|") + "#" + diet.summary
    }

    var body: some View {
        NavigationStack {
            Group {
                if fridge.isEmpty {
                    ContentUnavailableView(
                        "No food in your fridge",
                        systemImage: "fork.knife",
                        description: Text("Add food to see meal ideas that use it up.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            filterChips
                            recipeGrid
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Recipes")
            .profileButton()
            // Week 9: favourite recipes
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        FavouritesView()
                    } label: {
                        Label("Favourites", systemImage: "heart")
                    }
                }
            }
            .task(id: loadKey) {
                await loadRecipes()
            }
            // Drop filters for food that has left the fridge
            .onChange(of: foodNames.map(\.name)) { _, names in
                selected.formIntersection(names)
            }
        }
    }

    // MARK: Filter chips

    private var filterChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Filter by food")
                    .font(.headline)
                Spacer()
                if !selected.isEmpty {
                    Button("Clear") {
                        withAnimation { selected.removeAll() }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(foodNames, id: \.name) { food in
                        let isOn = selected.contains(food.name)
                        Button {
                            withAnimation {
                                if isOn { selected.remove(food.name) } else { selected.insert(food.name) }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(food.name).font(.subheadline.weight(.semibold))
                                Text(food.expiryText).font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(isOn ? .accentColor : .gray)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                        .accessibilityHint(isOn ? "Stops filtering recipes by this food"
                                                : "Only shows recipes that use this food")
                    }
                }
                .padding(.horizontal)
            }

            Text(selected.isEmpty
                 ? "Showing recipes for everything in your fridge, using food that expires soonest first. Tap food to filter."
                 : "Showing recipes that use \(selected.count == 1 ? "this food" : "all of these foods").")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if !diet.isEmpty {
                Label("Only showing meals that are: \(diet.summary.lowercased())", systemImage: "leaf")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: Results

    @ViewBuilder
    private var recipeGrid: some View {
        if isLoading {
            ProgressView(loadingMessage)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if failed {
            ContentUnavailableView {
                Label("Couldn't load recipes", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Finding new recipes needs an internet connection.")
            } actions: {
                Button("Try again") { Task { await loadRecipes() } }
            }

            // Recipes kept on the phone still open offline
            let saved = MealDB.savedRecipes()
            if !saved.isEmpty {
                Text("Recent recipes available offline")
                    .font(.headline)
                    .padding(.horizontal)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(saved) { meal in
                        NavigationLink {
                            RecipeDetailView(meal: meal, fridgeNames: fridge.map(\.name))
                        } label: {
                            RecipeCard(result: RecipeResult(meal: meal, uses: [], soonestDaysLeft: 0))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        } else if allResults.isEmpty {
            ContentUnavailableView("No recipes found", systemImage: "fork.knife",
                                   description: Text(diet.isEmpty
                                       ? "There are no recipes for the food in your fridge yet."
                                       : "No recipes for your fridge food suit your diet."))
        } else if shownResults.isEmpty {
            ContentUnavailableView {
                Label("No recipes use all of these", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text("Try filtering by fewer foods.")
            } actions: {
                Button("Clear filters") { withAnimation { selected.removeAll() } }
            }
        } else {
            Text(shownResults.count == 1 ? "1 recipe" : "\(shownResults.count) recipes")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(shownResults) { result in
                    NavigationLink {
                        RecipeDetailView(meal: result.meal, fridgeNames: fridge.map(\.name))
                    } label: {
                        RecipeCard(result: result)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: Loading

    private func loadRecipes() async {
        let foods = fridge
        var urgency: [String: Int] = [:]                   // soonest days left for each name
        for food in foods {
            urgency[food.name] = min(urgency[food.name] ?? .max, food.daysLeft)
        }
        let names = Array(foodNames.prefix(maxFoodsSearched).map(\.name))
        guard !names.isEmpty else {
            allResults = []
            return
        }

        isLoading = true
        loadingMessage = "Finding recipes…"
        failed = false
        var found: [String: RecipeResult] = [:]
        var anySucceeded = false

        // Week 9: every food is searched at the same time, so loading stays quick
        // even with more searches per food.
        let results = await withTaskGroup(of: (name: String, meals: [MealSummary], reached: Bool).self) { group in
            for name in names {
                group.addTask {
                    let plan = await MealDB.searchPlan(for: name)
                    var meals: [MealSummary] = []
                    var reached = false

                    // Combine every main search word (e.g. "chicken breast" and "chicken")
                    for term in plan.main {
                        if let fetched = try? await MealDB.meals(withIngredient: term) {
                            reached = true
                            meals += fetched
                        }
                    }
                    // Only try the fallback words if nothing was found
                    if meals.isEmpty {
                        for term in plan.fallback {
                            if let fetched = try? await MealDB.meals(withIngredient: term) {
                                reached = true
                                meals += fetched
                                if !fetched.isEmpty { break }
                            }
                        }
                    }
                    return (name, meals, reached)
                }
            }

            var collected: [(name: String, meals: [MealSummary], reached: Bool)] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        for result in results {
            if result.reached { anySucceeded = true }
            let daysLeft = urgency[result.name] ?? 0
            for meal in result.meals {
                if var existing = found[meal.id] {
                    if !existing.uses.contains(result.name) { existing.uses.append(result.name) }
                    existing.soonestDaysLeft = min(existing.soonestDaysLeft, daysLeft)
                    found[meal.id] = existing
                } else {
                    found[meal.id] = RecipeResult(meal: meal, uses: [result.name], soonestDaysLeft: daysLeft)
                }
            }
        }

        // Meals using the most fridge food first, then the most urgent food
        var ranked = found.values.sorted {
            if $0.uses.count != $1.uses.count { return $0.uses.count > $1.uses.count }
            if $0.soonestDaysLeft != $1.soonestDaysLeft { return $0.soonestDaysLeft < $1.soonestDaysLeft }
            return $0.meal.name < $1.meal.name
        }

        // Diet: open each recipe behind the scenes and check its ingredients.
        // Recipes that can't be checked are left out, to be safe.
        let needs = diet
        if !needs.isEmpty {
            loadingMessage = "Checking recipes suit your diet…"
            let toCheck = Array(ranked.prefix(maxDietChecks))
            var suitableIDs: Set<String> = []

            // Check 10 recipes at a time (saved recipes are instant), then keep the original order
            for start in stride(from: 0, to: toCheck.count, by: 10) {
                let batch = toCheck[start..<min(start + 10, toCheck.count)].map(\.meal.id)
                let ids = await withTaskGroup(of: String?.self) { group in
                    for id in batch {
                        group.addTask {
                            guard let detail = try? await MealDB.meal(id: id),
                                  await MealDB.suits(detail, needs) else { return nil }
                            return id
                        }
                    }
                    var passed: [String] = []
                    for await id in group {
                        if let id { passed.append(id) }
                    }
                    return passed
                }
                suitableIDs.formUnion(ids)
            }
            ranked = toCheck.filter { suitableIDs.contains($0.meal.id) }
        }

        allResults = ranked
        failed = !anySucceeded
        isLoading = false
    }
}

struct RecipeCard: View {
    let result: RecipeResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: result.meal.thumbnailURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color(.secondarySystemBackground)
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)

            Text(result.meal.name)
                .font(.headline)
                .lineLimit(2)

            if !result.uses.isEmpty {
                Text("Uses: \(result.uses.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // VoiceOver reads the card as one item: "Chicken pasta, Uses: chicken, spinach"
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the recipe")
    }
}
