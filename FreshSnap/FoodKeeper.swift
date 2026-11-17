//
//  FoodKeeper.swift
//  FreshSnap
//
//  Created by Mack Low on 06/11/2026.
//

import Foundation

// FreshSnap – Week 6, Step 5 (Week 9: freezer times)
// Reads the USDA FoodKeeper data (foodkeeper.json, bundled in the app, public domain)
// and finds how long a product keeps. Works offline.
// Source: https://catalog.data.gov/dataset/fsis-foodkeeper-data

enum FoodKeeper {
    struct Entry {
        let name: String
        let words: Set<String>      // name, subtitle and keywords, simplified for matching
        let nameWordCount: Int
        let fridgeDays: Int?
        let pantryDays: Int?
        let freezerDays: Int?
    }

    struct Match {
        let entryName: String
        let days: Int
    }

    // Loaded once, the first time it's needed. Empty if the file is missing.
    static let entries: [Entry] = load()

    // MARK: Finding a product

    // UK words -> the US words FoodKeeper uses
    private static let ukToUS: [String: String] = [
        "courgette": "zucchini", "courgettes": "zucchini", "aubergine": "eggplant",
        "coriander": "cilantro", "prawn": "shrimp", "prawns": "shrimp",
        "mince": "ground", "minced": "ground", "crisps": "chips",
        "biscuit": "cookie", "biscuits": "cookies", "rocket": "arugula",
        "yoghurt": "yogurt", "double": "heavy", "sweetcorn": "corn",
        "gammon": "ham", "rashers": "bacon", "streaky": "bacon", "swede": "rutabaga"
    ]

    // Words that don't help identify the food
    private static let ignoredWords: Set<String> = [
        "fresh", "loose", "pack", "large", "small", "medium", "british", "organic",
        "free", "range", "the", "and", "with", "semi", "skimmed", "whole", "sliced",
        "mature", "mild", "extra", "finest", "value", "smoked", "unsmoked"
    ]

    // Penalised unless the scanned name also says them, so raw chicken
    // doesn't match "cooked chicken".
    private static let cautionWords = ["cooked", "canned", "dried", "frozen", "leftover", "commercial", "mix"]

    static func match(name: String, category: String) -> Match? {
        guard let entry = bestEntry(for: name) else { return nil }

        // Where the food is kept depends on its category
        let days: Int?
        switch category {
        case "Frozen": days = entry.freezerDays ?? entry.fridgeDays
        case "Cupboard": days = entry.pantryDays ?? entry.fridgeDays
        default: days = entry.fridgeDays ?? entry.pantryDays
        }

        guard let days else { return nil }
        return Match(entryName: entry.name, days: days)
    }

    // Freezer time only (Week 9: Move to freezer). nil if FoodKeeper has no freezer time.
    static func freezerMatch(name: String) -> Match? {
        guard let entry = bestEntry(for: name), let days = entry.freezerDays else { return nil }
        return Match(entryName: entry.name, days: days)
    }

    // The FoodKeeper product that best matches a food name
    private static func bestEntry(for name: String) -> Entry? {
        let nameWords = Set(
            words(in: name)
                .map { ukToUS[$0] ?? $0 }
                .filter { !ignoredWords.contains($0) }
                .map(stem)
        )
        guard !nameWords.isEmpty else { return nil }

        var best: (entry: Entry, score: Double)?
        for entry in entries {
            var score = Double(nameWords.intersection(entry.words).count)
            guard score > 0 else { continue }

            for word in cautionWords where entry.words.contains(word) && !nameWords.contains(word) {
                score -= 0.5
            }

            if let current = best {
                // Higher score wins; on a tie, the simpler (shorter) FoodKeeper name wins
                let better = score > current.score
                    || (score == current.score && entry.nameWordCount < current.entry.nameWordCount)
                if better { best = (entry, score) }
            } else {
                best = (entry, score)
            }
        }

        guard let entry = best?.entry, (best?.score ?? 0) > 0 else { return nil }
        return entry
    }

    // MARK: Reading the file

    private static func load() -> [Entry] {
        // The file is a list of "sheets"; the "Product" sheet holds the foods.
        // Each row is a list of one-field dictionaries, e.g. [{"Name": "Milk"}, {"Refrigerate_Min": 1}, ...]
        guard let url = Bundle.main.url(forResource: "foodkeeper", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sheets = json["sheets"] as? [[String: Any]],
              let products = sheets.first(where: { ($0["name"] as? String) == "Product" }),
              let rows = products["data"] as? [[[String: Any]]]
        else { return [] }

        return rows.compactMap { row in
            var fields: [String: Any] = [:]
            for cell in row {
                fields.merge(cell) { _, new in new }
            }

            guard let name = fields["Name"] as? String else { return nil }
            let subtitle = fields["Name_subtitle"] as? String ?? ""
            let keywords = fields["Keywords"] as? String ?? ""

            return Entry(
                name: subtitle.isEmpty ? name : "\(name) (\(subtitle))",
                words: Set(words(in: "\(name) \(subtitle) \(keywords)").map(stem)),
                nameWordCount: words(in: name).count,
                fridgeDays: days(in: fields, prefix: "Refrigerate") ?? days(in: fields, prefix: "DOP_Refrigerate"),
                pantryDays: days(in: fields, prefix: "Pantry") ?? days(in: fields, prefix: "DOP_Pantry"),
                freezerDays: days(in: fields, prefix: "Freeze") ?? days(in: fields, prefix: "DOP_Freeze")
            )
        }
    }

    // Uses the shortest recommended time (Min), the safer choice for food.
    private static func days(in fields: [String: Any], prefix: String) -> Int? {
        guard let minimum = number(fields["\(prefix)_Min"]),
              let metric = (fields["\(prefix)_Metric"] as? String)?.lowercased() else { return nil }

        let daysPerUnit: Double
        if metric.hasPrefix("day") { daysPerUnit = 1 }
        else if metric.hasPrefix("week") { daysPerUnit = 7 }
        else if metric.hasPrefix("month") { daysPerUnit = 30 }
        else if metric.hasPrefix("year") { daysPerUnit = 365 }
        else { return nil }

        let result = Int((minimum * daysPerUnit).rounded())
        return result > 0 ? result : nil
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text) }
        return nil
    }

    // MARK: Simplifying words

    // nonisolated: simple text functions that are safe to use from anywhere
    nonisolated private static func words(in text: String) -> [String] {
        text.lowercased()
            .split { !$0.isLetter }
            .map(String.init)
            .filter { $0.count >= 3 }
    }

    // "tomatoes" -> "tomato", "berries" -> "berry", "eggs" -> "egg"
    nonisolated private static func stem(_ word: String) -> String {
        if word.hasSuffix("oes") { return String(word.dropLast(2)) }
        if word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
        if word.hasSuffix("s") && !word.hasSuffix("ss") { return String(word.dropLast()) }
        return word
    }
}
