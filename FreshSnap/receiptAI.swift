//
//  receiptAI.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 10/11/2026.
//

import Foundation
import FirebaseAILogic
 
// FreshSnap – Week 8, Extra 1
// AI fallback for receipt names, using Google's Gemini through Firebase AI Logic
// (free on the Spark plan with the Gemini Developer API).
// The dictionary runs first; AI then tidies every name, finds the amount, and spots
// lines that aren't products. Only the item lines are sent – never the receipt photo.
 
enum ReceiptAI {
    // A fast, low-cost model. If the console shows a "model not found" error,
    // check the current model list in the Firebase AI Logic docs and change it here.
    static let modelName = "gemini-3.5-flash-lite"
 
    enum Outcome {
        case improved   // AI replied and was applied
        case failed     // no internet, AI unavailable or an unexpected reply
    }
 
    private struct Suggestion: Decodable {
        let line: Int
        let name: String
        let amount: String?
        let category: String
        let type: String        // "food", "not food" or "not an item"
    }
 
    static func improve(_ items: [ReceiptItem]) async -> (items: [ReceiptItem], outcome: Outcome) {
        guard !items.isEmpty else { return (items, .improved) }
 
        // e.g. "1. RED ONION 3PACK MINIMUM 0.85 (our guess: Red onion)"
        let lines = items.enumerated()
            .map { "\($0.offset + 1). \($0.element.receiptText) (our guess: \($0.element.name))" }
            .joined(separator: "\n")
 
        // Built line by line, so Xcode's automatic indenting can't break it
        let instructions = [
            "You are tidying lines from a UK supermarket receipt for a food-tracking app.",
            "",
            "For each numbered line, reply with:",
            "- \"name\": the short, plain product name a shopper would say, in sentence case. Expand abbreviations. Remove store names, prices, sizes, product codes, VAT letters and receipt filler such as MINIMUM, APPROX, EACH, LOOSE or CLASS 1. Use the plural for multi-packs of fruit and veg.",
            "- \"amount\": the size or pack if shown (e.g. \"2 L\", \"400 g\", \"3 pack\"), otherwise \"\".",
            "- \"category\": one of: \(FoodCategory.all.joined(separator: ", ")).",
            "- \"type\": \"food\" for food or drink; \"not food\" for things like carrier bags, cleaning products or phone top-ups; \"not an item\" for offers, discounts and loyalty prices (e.g. lines starting CC, \"ANY 3 FOR £3\", \"CLUBCARD PRICE\", \"2 FOR £5\").",
            "",
            "Examples:",
            "\"SS MLK 2L 1.15 A\" -> {\"name\": \"Semi-skimmed milk\", \"amount\": \"2 L\", \"category\": \"Dairy and eggs\", \"type\": \"food\"}",
            "\"RED ONION 3PACK MINIMUM 0.85\" -> {\"name\": \"Red onions\", \"amount\": \"3 pack\", \"category\": \"Fruit and veg\", \"type\": \"food\"}",
            "\"TUNNOCKS CARAMEL WAF 0.99\" -> {\"name\": \"Tunnock's caramel wafers\", \"amount\": \"\", \"category\": \"Cupboard\", \"type\": \"food\"}",
            "\"CC ANY 3 FOR £3\" -> {\"name\": \"Offer\", \"amount\": \"\", \"category\": \"Other\", \"type\": \"not an item\"}",
            "",
            "Reply with only a JSON array, one object per line, each with a \"line\" number.",
            ""
        ]
        let prompt = instructions.joined(separator: "\n") + "\n" + lines
 
        do {
            let ai = FirebaseAI.firebaseAI(backend: .googleAI())
            let model = ai.generativeModel(
                modelName: modelName,
                generationConfig: GenerationConfig(temperature: 0, responseMIMEType: "application/json")
            )
            let response = try await model.generateContent(prompt)
            guard let text = response.text else {
                print("ReceiptAI: the reply had no text")
                return (items, .failed)
            }
 
            // Remove ```json fences in case the model adds them
            let json = text
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let suggestions = try JSONDecoder().decode([Suggestion].self, from: Data(json.utf8))
 
            var improved = items
            for suggestion in suggestions where (1...items.count).contains(suggestion.line) {
                var item = improved[suggestion.line - 1]
                let type = suggestion.type.lowercased()
 
                if type == "not an item" {
                    item.include = false
                    item.note = "Looks like an offer or discount line, not a product."
                } else if type == "not food" {
                    item.include = false
                    item.note = "Doesn't look like food."
                }
 
                let name = suggestion.name.trimmingCharacters(in: .whitespaces)
                if type == "food", !name.isEmpty, name.lowercased() != item.name.lowercased() {
                    item.name = name
                    item.nameSource = .ai
                }
 
                if let amount = suggestion.amount?.trimmingCharacters(in: .whitespaces),
                   !amount.isEmpty, item.amount.isEmpty {
                    item.amount = amount
                }
 
                if FoodCategory.all.contains(suggestion.category) {
                    item.category = suggestion.category
                }
 
                // New name or category -> new use-by estimate
                let estimate = ShelfLife.estimate(forName: item.name, category: item.category)
                item.expiryDate = estimate.date
                item.estimateSource = estimate.source
 
                improved[suggestion.line - 1] = item
            }
            return (improved, .improved)
        } catch {
            // Printed in Xcode's console, to help find out why AI didn't work
            print("ReceiptAI failed: \(error)")
            return (items, .failed)
        }
    }
}
