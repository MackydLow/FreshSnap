//
//  RecipeDetailView.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 06/11/2026.
//

import SwiftUI
 
// FreshSnap – Week 6, Step 6
// View recipe: photo, ingredients (marking what's in your fridge), method and video.
 
struct RecipeDetailView: View {
    let meal: MealSummary
    let fridgeNames: [String]
 
    @State private var detail: MealDetail?
    @State private var failed = false
 
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
