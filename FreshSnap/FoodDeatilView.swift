//
//  FoodDeatilView.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 21/10/2026.
//

import SwiftUI
import SwiftData
 
// FreshSnap – Week 5, Step 9
// The Food item screen: details, then "Product used or thrown away?"
// Used adds the price to money saved; both take the food out of the fridge.
 
struct FoodDetailView: View {
    let food: FoodItem
    @Environment(\.dismiss) private var dismiss
 
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(food.name)
                        .font(.title.bold())
                    Text(food.expiryText)
                        .font(.headline)
                        .foregroundStyle(food.daysLeft <= 1 ? .red : .secondary)
                }
                .padding(.vertical, 4)
            }
 
            Section("Details") {
                LabeledContent("Use-by date", value: food.expiryDate.formatted(date: .long, time: .omitted))
                if !food.amount.isEmpty {
                    LabeledContent("Amount", value: food.amount)
                }
                LabeledContent("Category", value: food.category)
                LabeledContent("Price paid",
                               value: food.price > 0 ? food.price.formatted(.currency(code: "GBP")) : "Not added")
                LabeledContent("Added", value: food.addedDate.formatted(date: .abbreviated, time: .omitted))
            }
 
            Section {
                Button {
                    finish(.used)
                } label: {
                    Label("Used", systemImage: "checkmark.circle")
                }
 
                Button(role: .destructive) {
                    finish(.thrownAway)
                } label: {
                    Label("Thrown away", systemImage: "trash")
                }
            } footer: {
                Text("Marking food as used adds its price to your money saved.")
            }
        }
        .navigationTitle("Food item")
        .navigationBarTitleDisplayMode(.inline)
    }
 
    // Saves the choice (SwiftData saves automatically) and goes back to the fridge.
    private func finish(_ status: FoodStatus) {
        food.status = status
        dismiss()
    }
}
