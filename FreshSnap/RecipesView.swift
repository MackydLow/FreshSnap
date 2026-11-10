//
//  RecipesView.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 06/11/2026.
//

import SwiftUI
import SwiftData
 
// FreshSnap – Week 6, Step 6 (Week 7: diet filter)
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
 
    @State private var selected: Set<PersistentIdentifier> = []
    @State private var chosenDefaults = false
    @State private var results: [RecipeResult] = []
    @State private var isLoading = false
    @State private var loadingMessage = "Finding recipes…"
    @State private var failed = false
 
    // Diet choices from Settings; changing them reloads the recipes
    @AppStorage(AppSettings.vegetarianKey) private var vegetarian = false
    @AppStorage(AppSettings.veganKey) private var vegan = false
    @AppStorage(AppSettings.nutFreeKey) private var nutFree = false
    @AppStorage(AppSettings.dairyFreeKey) private var dairyFree = false
 
    private var diet: DietNeeds {
        DietNeeds(vegetarian: vegetarian, vegan: vegan, nutFree: nutFree, dairyFree: dairyFree)
    }
 
    private let maxDietChecks = 30   // recipes checked behind the scenes per search
 
    private let maxIngredients = 5
    @Environment(\.dynamicTypeSize) private var textSize
 
    // Two columns normally; one column at the largest (accessibility) text sizes
    private var columns: [GridItem] {
        let count = textSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }
 
    private var fridge: [FoodItem] {
        allFood.filter { $0.ownerID == auth.userID && $0.status == .inFridge }
    }
 
    private var chosenFood: [FoodItem] {
        fridge.filter { selected.contains($0.persistentModelID) }
    }
 
    // Changes whenever the selection or diet changes, which reloads the recipes
    private var selectionKey: String {
        chosenFood.map(\.name).sorted().joined(separator: "|") + "#" + diet.summary
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
                            ingredientPicker
                            recipeGrid
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Recipes")
            .profileButton()
            .onAppear(perform: chooseDefaultsIfNeeded)
            .task(id: selectionKey) {
                await loadRecipes()
            }
        }
    }
 
    // MARK: Filter by ingredients
 
    private var ingredientPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Use up")
                .font(.headline)
                .padding(.horizontal)
 
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(fridge) { food in
                        let isOn = selected.contains(food.persistentModelID)
                        Button {
                            toggle(food)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(food.name).font(.subheadline.weight(.semibold))
                                Text(food.expiryText).font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(isOn ? .accentColor : .gray)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                        .accessibilityHint(isOn ? "Removes this food from the recipe search"
                                                : "Adds this food to the recipe search")
                    }
                }
                .padding(.horizontal)
            }
 
            Text("Food that needs using in the next two days is chosen for you. Tap to change, up to \(maxIngredients).")
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
        if selected.isEmpty {
            ContentUnavailableView("Choose some food", systemImage: "hand.tap",
                                   description: Text("Tap food above to find meals that use it."))
        } else if isLoading {
            ProgressView(loadingMessage)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if failed {
            ContentUnavailableView {
                Label("Couldn't load recipes", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Recipes need an internet connection.")
            } actions: {
                Button("Try again") { Task { await loadRecipes() } }
            }
        } else if results.isEmpty {
            ContentUnavailableView("No recipes found", systemImage: "fork.knife",
                                   description: Text(diet.isEmpty
                                       ? "Try choosing different or fewer foods."
                                       : "No recipes using this food suit your diet. Try choosing different foods."))
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(results) { result in
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
 
    // MARK: Actions
 
    // First visit: pick food expiring within two days, or the three soonest.
    private func chooseDefaultsIfNeeded() {
        guard !chosenDefaults, !fridge.isEmpty else { return }
        chosenDefaults = true
        let urgent = fridge.filter { $0.daysLeft <= 2 }
        let picks = urgent.isEmpty ? Array(fridge.prefix(3)) : Array(urgent.prefix(maxIngredients))
        selected = Set(picks.map(\.persistentModelID))
    }
 
    private func toggle(_ food: FoodItem) {
        let id = food.persistentModelID
        if selected.contains(id) {
            selected.remove(id)
        } else if selected.count < maxIngredients {
            selected.insert(id)
        }
    }
 
    private func loadRecipes() async {
        let foods = chosenFood
        guard !foods.isEmpty else {
            results = []
            return
        }
 
        isLoading = true
        loadingMessage = "Finding recipes…"
        failed = false
        var found: [String: RecipeResult] = [:]
        var anySucceeded = false
 
        for food in foods {
            // Try the full name first, then simpler words, until meals are found
            for term in MealDB.searchTerms(for: food.name) {
                do {
                    let meals = try await MealDB.meals(withIngredient: term)
                    anySucceeded = true
                    guard !meals.isEmpty else { continue }
 
                    for meal in meals {
                        if var existing = found[meal.id] {
                            existing.uses.append(food.name)
                            existing.soonestDaysLeft = min(existing.soonestDaysLeft, food.daysLeft)
                            found[meal.id] = existing
                        } else {
                            found[meal.id] = RecipeResult(meal: meal, uses: [food.name],
                                                          soonestDaysLeft: food.daysLeft)
                        }
                    }
                    break
                } catch {
                    continue
                }
            }
        }
 
        // Meals using the most chosen food first, then the most urgent food
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
            var suitable: [RecipeResult] = []
            for result in ranked.prefix(maxDietChecks) {
                if let detail = try? await MealDB.meal(id: result.meal.id),
                   MealDB.suits(detail, needs) {
                    suitable.append(result)
                }
            }
            ranked = suitable
        }
 
        results = ranked
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
 
            Text("Uses: \(result.uses.joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // VoiceOver reads the card as one item: "Chicken pasta, Uses: chicken, spinach"
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the recipe")
    }
}
