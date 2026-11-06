//
//  ShelfLife.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 30/10/2026.
//

import Foundation
 
// FreshSnap – Week 6, Steps 2 and 5
// Estimates a use-by date when there's no printed date (barcodes and receipts).
// 1. USDA FoodKeeper guidance for that product, if it's found
// 2. Otherwise, an average for the food's category
 
struct ShelfLifeEstimate {
    let date: Date
    let source: String      // shown on Review scan, e.g. "FoodKeeper (Milk), 7 days"
}
 
enum ShelfLife {
    static func estimate(forName name: String, category: String) -> ShelfLifeEstimate {
        if let match = FoodKeeper.match(name: name, category: category) {
            return ShelfLifeEstimate(
                date: date(inDays: match.days),
                source: "FoodKeeper (\(match.entryName)), \(dayText(match.days))"
            )
        }
 
        let days = estimatedDays(forCategory: category)
        return ShelfLifeEstimate(
            date: date(inDays: days),
            source: "\(category) average, \(dayText(days))"
        )
    }
 
    static func estimatedDays(forCategory category: String) -> Int {
        switch category {
        case "Meat and fish": return 2
        case "Fruit and veg": return 5
        case "Dairy and eggs": return 7
        case "Bakery": return 4
        case "Frozen": return 90
        case "Cupboard": return 180
        default: return 7
        }
    }
 
    static func estimatedUseBy(forCategory category: String) -> Date {
        date(inDays: estimatedDays(forCategory: category))
    }
 
    private static func date(inDays days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now
    }
 
    private static func dayText(_ days: Int) -> String {
        days == 1 ? "1 day" : "\(days) days"
    }
}
