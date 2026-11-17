//
//  FoodItem.swift
//  FreshSnap
//
//  Created by Mack Low on 21/10/2026.
//

import Foundation
import SwiftData

// FreshSnap – Week 5, Step 6 (Week 8: nutrition; Week 9: finished and frozen dates)
// One piece of food in the virtual fridge, saved on the phone with SwiftData.
// Replaces Xcode's template Item.swift.

enum FoodStatus: String, Codable {
    case inFridge
    case used
    case thrownAway
}

// Nutrition per 100 g, from Open Food Facts (Week 8, Extra 2)
struct Nutrition: Equatable {
    var calories: Double?
    var fat: Double?
    var saturatedFat: Double?
    var carbs: Double?
    var sugar: Double?
    var fibre: Double?
    var protein: Double?
    var salt: Double?

    var isEmpty: Bool {
        [calories, fat, saturatedFat, carbs, sugar, fibre, protein, salt].allSatisfy { $0 == nil }
    }
}

enum FoodCategory {
    static let all = ["Fruit and veg", "Meat and fish", "Dairy and eggs", "Bakery", "Cupboard", "Frozen", "Other"]
}

@Model
final class FoodItem {
    var ownerID: String      // Firebase user ID, so each account has its own fridge
    var name: String
    var expiryDate: Date
    var amount: String       // e.g. "2 pack", "500 g"
    var price: Double        // used for money saved (0 if unknown)
    var category: String
    var statusRaw: String    // stored as text; use `status` below in code
    var addedDate: Date

    // When the food was used or thrown away (Week 9), for the weekly impact chart.
    // nil for food still in the fridge, and for food finished before this was added.
    var finishedDate: Date? = nil

    // When the food was moved to the freezer (Week 9), nil if it hasn't been.
    var frozenDate: Date? = nil

    // Nutrition per 100 g (Week 8). Optional, so existing food updates automatically.
    var calories: Double? = nil
    var fat: Double? = nil
    var saturatedFat: Double? = nil
    var carbs: Double? = nil
    var sugar: Double? = nil
    var fibre: Double? = nil
    var protein: Double? = nil
    var salt: Double? = nil

    // All the nutrition values together, or nil if there are none
    var nutrition: Nutrition? {
        get {
            let values = Nutrition(calories: calories, fat: fat, saturatedFat: saturatedFat,
                                   carbs: carbs, sugar: sugar, fibre: fibre, protein: protein, salt: salt)
            return values.isEmpty ? nil : values
        }
        set {
            calories = newValue?.calories
            fat = newValue?.fat
            saturatedFat = newValue?.saturatedFat
            carbs = newValue?.carbs
            sugar = newValue?.sugar
            fibre = newValue?.fibre
            protein = newValue?.protein
            salt = newValue?.salt
        }
    }

    // Setting the status also records when the food was finished
    var status: FoodStatus {
        get { FoodStatus(rawValue: statusRaw) ?? .inFridge }
        set {
            statusRaw = newValue.rawValue
            finishedDate = newValue == .inFridge ? nil : .now
        }
    }

    // The day it was finished, or the day it was added for older food
    var finishedDay: Date {
        finishedDate ?? addedDate
    }

    init(ownerID: String,
         name: String,
         expiryDate: Date,
         amount: String = "",
         price: Double = 0,
         category: String = "Other") {
        self.ownerID = ownerID
        self.name = name
        self.expiryDate = expiryDate
        self.amount = amount
        self.price = price
        self.category = category
        self.statusRaw = FoodStatus.inFridge.rawValue
        self.addedDate = .now
    }

    // Whole days from today until the use-by date (negative = expired).
    var daysLeft: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let expiry = calendar.startOfDay(for: expiryDate)
        return calendar.dateComponents([.day], from: today, to: expiry).day ?? 0
    }

    var expiryText: String {
        switch daysLeft {
        case ..<0: return "Expired"
        case 0: return "Use today"
        case 1: return "Use tomorrow"
        default: return "Use by \(expiryDate.formatted(.dateTime.day().month()))"
        }
    }
}
