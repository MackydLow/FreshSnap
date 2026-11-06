//
//  MealDB.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 06/11/2026.
//

import Foundation
 
// FreshSnap – Week 6, Step 6
// Talks to TheMealDB, a free recipe API.
// Uses the free test key "1", allowed for development and education.
// API docs: https://www.themealdb.com/api.php
 
struct MealSummary: Identifiable, Hashable {
    let id: String
    let name: String
    let thumbnailURL: URL?
}
 
struct MealIngredient: Identifiable {
    let id = UUID()
    let name: String
    let measure: String
}
 
struct MealDetail {
    let id: String
    let name: String
    let category: String
    let area: String
    let imageURL: URL?
    let ingredients: [MealIngredient]
    let steps: [String]
    let youtubeURL: URL?
    let sourceURL: URL?
}
 
enum MealDB {
    private static let baseURL = "https://www.themealdb.com/api/json/v1/1/"
 
    // Meals that use one ingredient (filter.php gives only the name, photo and ID).
    static func meals(withIngredient ingredient: String) async throws -> [MealSummary] {
        let term = ingredient.lowercased()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")
        guard let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: baseURL + "filter.php?i=" + encoded) else { return [] }
 
        let json = try await fetchJSON(from: url)
        // "meals" is null (or text) when nothing is found
        guard let meals = json["meals"] as? [[String: Any]] else { return [] }
 
        return meals.compactMap { meal in
            guard let id = meal["idMeal"] as? String,
                  let name = meal["strMeal"] as? String else { return nil }
            return MealSummary(id: id, name: name, thumbnailURL: link(from: meal["strMealThumb"]))
        }
    }
 
    // The full recipe (lookup.php), loaded when the user opens it.
    static func meal(id: String) async throws -> MealDetail? {
        guard let url = URL(string: baseURL + "lookup.php?i=" + id) else { return nil }
        let json = try await fetchJSON(from: url)
        guard let meal = (json["meals"] as? [[String: Any]])?.first,
              let name = meal["strMeal"] as? String else { return nil }
 
        // Ingredients come as strIngredient1...20 with matching strMeasure1...20
        var ingredients: [MealIngredient] = []
        for number in 1...20 {
            let ingredient = (meal["strIngredient\(number)"] as? String ?? "")
                .trimmingCharacters(in: .whitespaces)
            guard !ingredient.isEmpty else { continue }
            let measure = (meal["strMeasure\(number)"] as? String ?? "")
                .trimmingCharacters(in: .whitespaces)
            ingredients.append(MealIngredient(name: ingredient, measure: measure))
        }
 
        return MealDetail(
            id: id,
            name: name,
            category: meal["strCategory"] as? String ?? "",
            area: meal["strArea"] as? String ?? "",
            imageURL: link(from: meal["strMealThumb"]),
            ingredients: ingredients,
            steps: steps(from: meal["strInstructions"] as? String ?? ""),
            youtubeURL: link(from: meal["strYoutube"]),
            sourceURL: link(from: meal["strSource"])
        )
    }
 
    // MARK: Turning fridge names into search words
 
    private static let ignoredWords: Set<String> = [
        "fresh", "loose", "semi", "skimmed", "whole", "mature", "mild", "large", "small",
        "medium", "british", "organic", "free", "range", "sliced", "smoked", "unsmoked",
        "pack", "extra", "finest", "value", "thick", "baby", "greek", "red", "green", "white"
    ]
 
    // UK words -> the words TheMealDB tends to use
    private static let replacements: [String: String] = [
        "yoghurt": "yogurt", "mince": "minced beef", "courgette": "zucchini",
        "aubergine": "aubergine", "prawns": "prawns"
    ]
 
    // "Chicken breasts" -> ["chicken breasts", "chicken breast", "breast", "chicken"]
    static func searchTerms(for foodName: String) -> [String] {
        let words = foodName.lowercased()
            .split { !$0.isLetter }
            .map(String.init)
            .filter { $0.count >= 3 && !ignoredWords.contains($0) }
            .map { replacements[$0] ?? $0 }
        guard let first = words.first, let last = words.last else { return [] }
 
        var terms: [String] = []
        if words.count > 1 {
            terms.append(words.joined(separator: " "))
            terms.append((words.dropLast() + [singular(last)]).joined(separator: " "))
        }
        terms += [first, singular(first), last, singular(last)]
 
        var seen: Set<String> = []
        return terms.filter { seen.insert($0).inserted }   // remove repeats, keep order
    }
 
    // The simple words used to spot fridge food in a recipe's ingredient list.
    static func keyWords(for foodName: String) -> Set<String> {
        Set(foodName.lowercased()
            .split { !$0.isLetter }
            .map(String.init)
            .filter { $0.count >= 3 && !ignoredWords.contains($0) }
            .map(singular))
    }
 
    static func singular(_ word: String) -> String {
        if word.hasSuffix("oes") { return String(word.dropLast(2)) }
        if word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
        if word.hasSuffix("s") && !word.hasSuffix("ss") { return String(word.dropLast()) }
        return word
    }
 
    // MARK: Helpers
 
    private static func fetchJSON(from url: URL) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
 
    // Turns a web address from the API into a URL (nil if empty)
    private static func link(from value: Any?) -> URL? {
        guard let text = value as? String, !text.isEmpty else { return nil }
        return URL(string: text)
    }
 
    // Splits the method into steps and removes "STEP 1" labels and numbering.
    private static func steps(from instructions: String) -> [String] {
        instructions
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { $0.replacingOccurrences(of: #"^(?i)(step\s*\d+[:.)]?\s*|\d+[.)]\s*)"#,
                                           with: "", options: .regularExpression) }
            .filter { !$0.isEmpty && $0.rangeOfCharacter(from: .letters) != nil }
    }
}
