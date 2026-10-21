//
//  FoodItem.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 21/10/2026.
//

import Foundation
import SwiftData
 
// FreshSnap – Week 5, Step 6
// One piece of food in the virtual fridge, saved on the phone with SwiftData.
// Replaces Xcode's template Item.swift.
 
enum FoodStatus: String, Codable {
    case inFridge
    case used
    case thrownAway
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
 
    var status: FoodStatus {
        get { FoodStatus(rawValue: statusRaw) ?? .inFridge }
        set { statusRaw = newValue.rawValue }
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
