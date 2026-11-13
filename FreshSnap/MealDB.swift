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
 
struct MealIngredient: Identifiable, Codable {
    var id = UUID()
    let name: String
    let measure: String
}
 
struct MealDetail: Codable {
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
 
// The diet choices from Settings
struct DietNeeds: Equatable {
    var vegetarian = false
    var vegan = false
    var nutFree = false
    var dairyFree = false
 
    var isEmpty: Bool { !vegetarian && !vegan && !nutFree && !dairyFree }
 
    // e.g. "Vegetarian, nut-free"
    var summary: String {
        var parts: [String] = []
        if vegan { parts.append("vegan") } else if vegetarian { parts.append("vegetarian") }
        if nutFree { parts.append("nut-free") }
        if dairyFree && !vegan { parts.append("dairy-free") }
        let text = parts.joined(separator: ", ")
        return text.prefix(1).uppercased() + text.dropFirst()
    }
 
    static var current: DietNeeds {
        let defaults = UserDefaults.standard
        return DietNeeds(
            vegetarian: defaults.bool(forKey: AppSettings.vegetarianKey),
            vegan: defaults.bool(forKey: AppSettings.veganKey),
            nutFree: defaults.bool(forKey: AppSettings.nutFreeKey),
            dairyFree: defaults.bool(forKey: AppSettings.dairyFreeKey)
        )
    }
}
 
enum MealDB {
    private static let baseURL = "https://www.themealdb.com/api/json/v1/1/"
 
    // Full recipes already downloaded while the app is open
    private static var detailCache: [String: MealDetail] = [:]
 
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
        if let cached = detailCache[id] { return cached }
 
        // Saved on the phone from an earlier visit: instant, and works offline
        if let file = savedFile(for: id),
           let data = try? Data(contentsOf: file),
           let saved = try? JSONDecoder().decode(MealDetail.self, from: data) {
            detailCache[id] = saved
            return saved
        }
 
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
 
        let detail = MealDetail(
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
        detailCache[id] = detail
        if let file = savedFile(for: id), let data = try? JSONEncoder().encode(detail) {
            try? data.write(to: file)
        }
        return detail
    }
 
    // MARK: Saved recipes (Week 8)
 
    // A folder in the app's cache, which iOS can clear if the phone runs low on space
    private static var savedFolder: URL? {
        guard let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("recipes", isDirectory: true) else { return nil }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
 
    private static func savedFile(for id: String) -> URL? {
        savedFolder?.appendingPathComponent("\(id).json")
    }
 
    // The most recently saved recipes, for when there's no internet
    static func savedRecipes(limit: Int = 20) -> [MealSummary] {
        guard let folder = savedFolder,
              let files = try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.contentModificationDateKey]) else { return [] }
 
        let newestFirst = files.sorted {
            let first = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let second = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return first > second
        }
 
        return newestFirst.prefix(limit).compactMap { file in
            guard let data = try? Data(contentsOf: file),
                  let meal = try? JSONDecoder().decode(MealDetail.self, from: data) else { return nil }
            return MealSummary(id: meal.id, name: meal.name, thumbnailURL: meal.imageURL)
        }
    }
 
    // MARK: Diet checks
 
    private static let meatCategories: Set<String> = ["beef", "chicken", "lamb", "pork", "seafood", "goat"]
 
    private static let meatAndFishWords = [
        "chicken", "beef", "pork", "lamb", "mutton", "bacon", "ham", "sausage", "turkey",
        "duck", "goat", "veal", "venison", "chorizo", "salami", "pancetta", "prosciutto",
        "pepperoni", "mince", "steak", "meat", "fish", "salmon", "tuna", "cod", "haddock",
        "mackerel", "sardine", "anchov", "prawn", "shrimp", "mussel", "clam", "oyster",
        "crab", "lobster", "squid", "scallop", "gelatin", "lard", "suet", "oxtail", "liver"
    ]
 
    private static let animalProductWords = ["egg", "honey", "mayonnaise", "ghee"]
 
    private static let dairyWords = [
        "milk", "butter", "cheese", "cream", "yogurt", "yoghurt", "parmesan", "mozzarella",
        "cheddar", "feta", "ricotta", "mascarpone", "paneer", "creme fraiche", "crème fraîche",
        "buttermilk", "custard", "ghee", "gruyere", "brie", "halloumi"
    ]
 
    // Plant milks and creams that are fine for dairy-free and vegan diets
    private static let plantWords = ["coconut", "almond milk", "oat milk", "soy", "soya", "rice milk", "peanut butter", "cocoa butter", "vegan"]
 
    private static let nutWords = [
        "nut", "almond", "peanut", "cashew", "walnut", "pecan", "hazelnut", "pistachio",
        "macadamia", "brazil", "praline", "marzipan", "frangipane", "satay", "nutella", "pesto"
    ]
 
    // Words that contain "nut" but aren't nuts
    private static let notNuts = ["nutmeg", "coconut", "butternut", "doughnut", "donut"]
 
    // True if the recipe suits every diet need that's switched on
    static func suits(_ meal: MealDetail, _ diet: DietNeeds) -> Bool {
        let ingredients = meal.ingredients.map { $0.name.lowercased() }
 
        func contains(_ words: [String], ignoring exceptions: [String] = []) -> Bool {
            ingredients.contains { ingredient in
                guard !exceptions.contains(where: { ingredient.contains($0) }) else { return false }
                return words.contains { ingredient.contains($0) }
            }
        }
 
        if diet.vegetarian || diet.vegan {
            if meatCategories.contains(meal.category.lowercased()) { return false }
            if contains(meatAndFishWords) { return false }
        }
        if diet.vegan {
            if contains(animalProductWords, ignoring: ["eggplant"]) { return false }
            if contains(dairyWords, ignoring: plantWords) { return false }
        }
        if diet.dairyFree && contains(dairyWords, ignoring: plantWords) { return false }
        if diet.nutFree && contains(nutWords, ignoring: notNuts) { return false }
        return true
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
 
    // nonisolated: a simple text function that is safe to use from anywhere
    nonisolated static func singular(_ word: String) -> String {
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
