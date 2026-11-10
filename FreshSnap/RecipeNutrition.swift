//
//  RecipeNutrition.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 10/11/2026.
//

import SwiftUI
import FirebaseAILogic
 
// FreshSnap – Week 8, Extra 3
// Estimated nutrition per serving for recipes. TheMealDB has no nutrition data,
// so Gemini (through Firebase AI Logic) estimates it from the ingredient amounts.
// Clearly labelled as an estimate, unlike barcode nutrition, which is exact.
 
struct RecipeNutrition {
    let servings: Int
    let perServing: Nutrition
}
 
enum RecipeNutritionAI {
    private struct Reply: Decodable {
        let servings: Int?
        let calories: Double?
        let fat: Double?
        let saturatedFat: Double?
        let carbs: Double?
        let sugar: Double?
        let fibre: Double?
        let protein: Double?
        let salt: Double?
    }
 
    // Estimates already made while the app is open, so each recipe is only asked once
    private static var cache: [String: RecipeNutrition] = [:]
 
    static func estimate(for meal: MealDetail) async -> RecipeNutrition? {
        if let cached = cache[meal.id] { return cached }
 
        let ingredients = meal.ingredients.map {
            "- \($0.measure) \($0.name)".trimmingCharacters(in: .whitespaces)
        }
        let instructions = [
            "Estimate the nutrition of this recipe.",
            "Recipe: \(meal.name)",
            "Ingredients:"
        ] + ingredients + [
            "",
            "First estimate how many servings these amounts make. Then estimate the nutrition per serving.",
            "Reply with only a JSON object with these keys: servings (a whole number), calories (kcal), and fat, saturatedFat, carbs, sugar, fibre, protein and salt (all in grams).",
            "Example: {\"servings\": 4, \"calories\": 520, \"fat\": 22, \"saturatedFat\": 9, \"carbs\": 45, \"sugar\": 8, \"fibre\": 6, \"protein\": 32, \"salt\": 1.8}"
        ]
        let prompt = instructions.joined(separator: "\n")
 
        do {
            let ai = FirebaseAI.firebaseAI(backend: .googleAI())
            let model = ai.generativeModel(
                modelName: ReceiptAI.modelName,
                generationConfig: GenerationConfig(temperature: 0, responseMIMEType: "application/json")
            )
            let response = try await model.generateContent(prompt)
            guard let text = response.text else { return nil }
 
            let json = text
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let reply = try JSONDecoder().decode(Reply.self, from: Data(json.utf8))
 
            let nutrition = Nutrition(calories: reply.calories, fat: reply.fat,
                                      saturatedFat: reply.saturatedFat, carbs: reply.carbs,
                                      sugar: reply.sugar, fibre: reply.fibre,
                                      protein: reply.protein, salt: reply.salt)
            guard !nutrition.isEmpty else { return nil }
 
            let result = RecipeNutrition(servings: max(reply.servings ?? 1, 1), perServing: nutrition)
            cache[meal.id] = result
            return result
        } catch {
            print("RecipeNutritionAI failed: \(error)")
            return nil
        }
    }
}
 
// The section shown on View recipe
struct RecipeNutritionSection: View {
    let meal: MealDetail
 
    private enum EstimateState {
        case notAsked
        case estimating
        case done(RecipeNutrition)
        case failed
    }
 
    @State private var state: EstimateState = .notAsked
    @AppStorage(AppSettings.useAIKey) private var useAI = true
 
    var body: some View {
        Section {
            if !useAI {
                Text("Turn on \"Use AI features\" in Preferences to estimate nutrition for recipes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                switch state {
                case .notAsked:
                    Button {
                        Task { await estimate() }
                    } label: {
                        Label("Estimate nutrition", systemImage: "sparkles")
                    }
 
                case .estimating:
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Estimating from the ingredients…")
                            .foregroundStyle(.secondary)
                    }
 
                case .done(let result):
                    ServingRows(nutrition: result.perServing)
 
                case .failed:
                    Text("Couldn't estimate nutrition. Check your internet connection and try again.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Try again") {
                        Task { await estimate() }
                    }
                }
            }
        } header: {
            Text("Nutrition per serving")
        } footer: {
            if case .done(let result) = state {
                Text("AI estimate for about \(result.servings) \(result.servings == 1 ? "serving" : "servings"), based on the ingredient amounts. Use it as a rough guide only.")
            } else if useAI {
                Text("Uses AI to estimate nutrition from the ingredients.")
            }
        }
    }
 
    private func estimate() async {
        state = .estimating
        if let result = await RecipeNutritionAI.estimate(for: meal) {
            state = .done(result)
        } else {
            state = .failed
        }
    }
}
 
// Per-serving values in UK label order (no traffic lights, as those are per 100 g)
private struct ServingRows: View {
    let nutrition: Nutrition
 
    var body: some View {
        if let calories = nutrition.calories {
            LabeledContent("Energy", value: "\(Int(calories.rounded())) kcal")
        }
        row("Fat", nutrition.fat)
        row("of which saturates", nutrition.saturatedFat)
        row("Carbohydrate", nutrition.carbs)
        row("of which sugars", nutrition.sugar)
        row("Fibre", nutrition.fibre)
        row("Protein", nutrition.protein)
        row("Salt", nutrition.salt)
    }
 
    @ViewBuilder
    private func row(_ name: String, _ grams: Double?) -> some View {
        if let grams {
            LabeledContent(name, value: "\(grams.formatted(.number.precision(.fractionLength(0...1)))) g")
        }
    }
}
