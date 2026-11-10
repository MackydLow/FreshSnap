//
//  RecipeDetailView.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 06/11/2026.
//

import SwiftUI
import SwiftData
 
// FreshSnap – Week 6, Step 6 (Week 7: "I cooked this"; Week 8: nutrition estimate)
// View recipe: photo, ingredients (marking what's in your fridge), method and video.
// "I cooked this" marks the fridge food used in the recipe as Used.
 
struct RecipeDetailView: View {
    let meal: MealSummary
    let fridgeNames: [String]
 
    @State private var detail: MealDetail?
    @State private var failed = false
    @State private var showingCooked = false
    @State private var cookedMessage: String?
 
    // Words from fridge food, used to spot ingredients you already have
    private var fridgeWords: Set<String> {
        fridgeNames.reduce(into: Set<String>()) { $0.formUnion(MealDB.keyWords(for: $1)) }
    }
 
    var body: some View {
        Group {
            if let detail {
                recipe(detail)
            } else if failed {
                ContentUnavailableView {
                    Label("Couldn't load this recipe", systemImage: "wifi.exclamationmark")
                } description: {
                    Text("Recipes need an internet connection.")
                } actions: {
                    Button("Try again") { Task { await load() } }
                }
            } else {
                ProgressView("Loading recipe…")
            }
        }
        .navigationTitle(meal.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showingCooked) {
            if let detail {
                CookedThisView(ingredientNames: detail.ingredients.map(\.name)) { saved in
                    // Wait for the checklist to finish closing before showing the message
                    Task {
                        try? await Task.sleep(for: .seconds(0.5))
                        cookedMessage = saved > 0
                            ? "Nice cooking! \(saved.formatted(.currency(code: "GBP"))) of food used up."
                            : "Nice cooking! Your fridge has been updated."
                    }
                }
            }
        }
        .alert(cookedMessage ?? "", isPresented: Binding(
            get: { cookedMessage != nil },
            set: { if !$0 { cookedMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        }
    }
 
    private func recipe(_ detail: MealDetail) -> some View {
        List {
            Section {
                AsyncImage(url: detail.imageURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Color(.secondarySystemBackground).frame(height: 200)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .listRowInsets(EdgeInsets())
                .accessibilityHidden(true)
 
                VStack(alignment: .leading, spacing: 4) {
                    Text(detail.name)
                        .font(.title2.bold())
                    Text([detail.category, detail.area].filter { !$0.isEmpty }.joined(separator: " · "))
                        .foregroundStyle(.secondary)
                }
            }
 
            Section("Ingredients") {
                ForEach(detail.ingredients) { ingredient in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(ingredient.name)
                            if !ingredient.measure.isEmpty {
                                Text(ingredient.measure)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if inFridge(ingredient.name) {
                            Label("In your fridge", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
 
            Section("Method") {
                ForEach(Array(detail.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.headline)
                            .foregroundStyle(.tint)
                        Text(step)
                    }
                    .padding(.vertical, 2)
                }
            }
 
            // Estimated nutrition (Week 8, Extra 3)
            RecipeNutritionSection(meal: detail)
 
            Section {
                Button {
                    showingCooked = true
                } label: {
                    Label("I cooked this", systemImage: "frying.pan")
                        .font(.headline)
                }
            } footer: {
                Text("Marks the food you used as Used, and adds it to your money saved.")
            }
 
            Section {
                if let youtube = detail.youtubeURL {
                    Link(destination: youtube) {
                        Label("Watch on YouTube", systemImage: "play.rectangle")
                    }
                }
                if let source = detail.sourceURL {
                    Link(destination: source) {
                        Label("Original recipe", systemImage: "safari")
                    }
                }
            } footer: {
                Text("Recipe from TheMealDB.")
            }
        }
    }
 
    private func inFridge(_ ingredient: String) -> Bool {
        !MealDB.keyWords(for: ingredient).isDisjoint(with: fridgeWords)
    }
 
    private func load() async {
        failed = false
        do {
            detail = try await MealDB.meal(id: meal.id)
            failed = detail == nil
        } catch {
            failed = true
        }
    }
}
 
// MARK: - I cooked this (Week 7)
 
struct CookedThisView: View {
    let ingredientNames: [String]
    let onDone: (Double) -> Void     // passes back the money saved
 
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.expiryDate) private var allFood: [FoodItem]
 
    @State private var ticked: Set<PersistentIdentifier> = []
    @State private var hasPreTicked = false
 
    private var fridge: [FoodItem] {
        allFood.filter { $0.ownerID == auth.userID && $0.status == .inFridge }
    }
 
    private var recipeWords: Set<String> {
        ingredientNames.reduce(into: Set<String>()) { $0.formUnion(MealDB.keyWords(for: $1)) }
    }
 
    // Fridge food that matches the recipe's ingredients
    private var inRecipe: [FoodItem] {
        fridge.filter { !MealDB.keyWords(for: $0.name).isDisjoint(with: recipeWords) }
    }
 
    private var otherFood: [FoodItem] {
        let matched = Set(inRecipe.map(\.persistentModelID))
        return fridge.filter { !matched.contains($0.persistentModelID) }
    }
 
    var body: some View {
        NavigationStack {
            List {
                if inRecipe.isEmpty {
                    Section {
                        Text("None of your fridge food matched this recipe's ingredients. Tick anything you used below.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Food from your fridge in this recipe") {
                        ForEach(inRecipe) { food in row(for: food) }
                    }
                }
 
                if !otherFood.isEmpty {
                    Section("Other food in your fridge") {
                        ForEach(otherFood) { food in row(for: food) }
                    }
                }
            }
            .navigationTitle("What did you use?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Mark as used") { markAsUsed() }
                        .disabled(ticked.isEmpty)
                }
            }
            .onAppear {
                // Tick the matching food once, when the list first opens
                guard !hasPreTicked else { return }
                hasPreTicked = true
                ticked = Set(inRecipe.map(\.persistentModelID))
            }
        }
    }
 
    private func row(for food: FoodItem) -> some View {
        let isTicked = ticked.contains(food.persistentModelID)
        return Button {
            if isTicked {
                ticked.remove(food.persistentModelID)
            } else {
                ticked.insert(food.persistentModelID)
            }
        } label: {
            HStack {
                Image(systemName: isTicked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isTicked ? Color.accentColor : .secondary)
                VStack(alignment: .leading) {
                    Text(food.name)
                        .foregroundStyle(.primary)
                    Text(food.expiryText)
                        .font(.caption)
                        .foregroundStyle(food.daysLeft <= 1 ? .red : .secondary)
                }
                Spacer()
                if food.price > 0 {
                    Text(food.price, format: .currency(code: "GBP"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityAddTraits(isTicked ? .isSelected : [])
    }
 
    private func markAsUsed() {
        let used = fridge.filter { ticked.contains($0.persistentModelID) }
        let saved = used.reduce(0) { $0 + $1.price }
        for food in used {
            food.status = .used
        }
        dismiss()
        onDone(saved)
    }
}
