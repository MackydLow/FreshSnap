//
//  OpenFoodFacts.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 30/10/2026.
//

import Foundation
 
// FreshSnap – Week 6, Step 2
// Looks up a barcode on Open Food Facts (free, open food database, no API key).
// API docs: https://openfoodfacts.github.io/documentation/docs/Product-Opener/api/
 
struct ProductInfo {
    let name: String
    let quantity: String     // e.g. "2 L", "500 g"
    let category: String     // one of FoodCategory.all
}
 
enum OpenFoodFacts {
    // Only the fields FreshSnap needs, to keep the download small.
    private struct Response: Decodable {
        let product: Product?
    }
 
    private struct Product: Decodable {
        let productName: String?
        let productNameEn: String?
        let quantity: String?
        let categoriesTags: [String]?
    }
 
    // Returns nil if the product isn't found or there's no internet.
    static func lookUp(barcode: String) async -> ProductInfo? {
        let digits = barcode.filter(\.isNumber)
        guard !digits.isEmpty,
              let url = URL(string: "https://world.openfoodfacts.org/api/v3/product/\(digits)?fields=product_name,product_name_en,quantity,categories_tags")
        else { return nil }
 
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        // Open Food Facts asks apps to identify themselves.
        request.setValue("FreshSnap/1.0 (iOS student project)", forHTTPHeaderField: "User-Agent")
 
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
 
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            guard let product = try decoder.decode(Response.self, from: data).product else { return nil }
 
            let name = [product.productNameEn, product.productName]
                .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty } ?? ""
            guard !name.isEmpty else { return nil }
 
            return ProductInfo(
                name: name,
                quantity: product.quantity ?? "",
                category: category(from: product.categoriesTags ?? [])
            )
        } catch {
            return nil
        }
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
 
