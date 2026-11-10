//
//  OpenFoodFacts.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 30/10/2026.
//

import Foundation
 
// FreshSnap – Week 6, Step 2 (Week 8, Extra 2: nutrition)
// Looks up a barcode on Open Food Facts (free, open food database, no API key).
// API docs: https://openfoodfacts.github.io/documentation/docs/Product-Opener/api/
 
struct ProductInfo {
    let name: String
    let quantity: String        // e.g. "2 L", "500 g"
    let category: String        // one of FoodCategory.all
    let nutrition: Nutrition?   // per 100 g, if Open Food Facts has it
}
 
enum OpenFoodFacts {
    // Returns nil if the product isn't found or there's no internet.
    static func lookUp(barcode: String) async -> ProductInfo? {
        let digits = barcode.filter(\.isNumber)
        // Only the fields FreshSnap needs, to keep the download small
        guard !digits.isEmpty,
              let url = URL(string: "https://world.openfoodfacts.org/api/v3/product/\(digits)?fields=product_name,product_name_en,quantity,categories_tags,nutriments")
        else { return nil }
 
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        // Open Food Facts asks apps to identify themselves.
        request.setValue("FreshSnap/1.0 (iOS student project)", forHTTPHeaderField: "User-Agent")
 
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let product = json["product"] as? [String: Any]
            else { return nil }
 
            let name = [product["product_name_en"], product["product_name"]]
                .compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty } ?? ""
            guard !name.isEmpty else { return nil }
 
            let nutriments = product["nutriments"] as? [String: Any]
 
            return ProductInfo(
                name: name,
                quantity: product["quantity"] as? String ?? "",
                category: category(from: product["categories_tags"] as? [String] ?? []),
                nutrition: nutrition(from: nutriments)
            )
        } catch {
            return nil
        }
    }
 
    // Reads the per-100 g values, e.g. "proteins_100g": 3.4
    private static func nutrition(from nutriments: [String: Any]?) -> Nutrition? {
        guard let nutriments else { return nil }
 
        func value(_ key: String) -> Double? {
            if let number = nutriments[key] as? NSNumber { return number.doubleValue }
            if let text = nutriments[key] as? String { return Double(text) }
            return nil
        }
 
        let result = Nutrition(
            calories: value("energy-kcal_100g"),
            fat: value("fat_100g"),
            saturatedFat: value("saturated-fat_100g"),
            carbs: value("carbohydrates_100g"),
            sugar: value("sugars_100g"),
            fibre: value("fiber_100g"),
            protein: value("proteins_100g"),
            salt: value("salt_100g")
        )
        return result.isEmpty ? nil : result
    }
 
    // Turns Open Food Facts tags like "en:dairies" into FreshSnap's categories.
    // Not perfect, which is why the user checks it on the Review scan screen.
    private static func category(from tags: [String]) -> String {
        let text = tags.joined(separator: " ")
        let rules: [(category: String, words: [String])] = [
            ("Frozen", ["frozen"]),
            ("Meat and fish", ["meat", "poultr", "chicken", "beef", "pork", "fish", "seafood"]),
            ("Fruit and veg", ["fruit", "vegetable", "salad"]),
            ("Dairy and eggs", ["dair", "milk", "cheese", "yogurt", "yoghurt", "egg"]),
            ("Bakery", ["bread", "bakery", "pastr", "cake"]),
            ("Cupboard", ["cereal", "pasta", "rice", "sauce", "canned", "snack", "biscuit", "spread", "condiment"])
        ]
        for rule in rules where rule.words.contains(where: { text.contains($0) }) {
            return rule.category
        }
        return "Other"
    }
}
 
