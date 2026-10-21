//
//  AddProductView.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 21/10/2026.
//

import SwiftUI
import SwiftData
 
// FreshSnap – Week 5, Step 7
// Manual add: product, use-by date, amount, then Add (submit).
 
struct AddProductView: View {
    let ownerID: String
 
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
 
    @State private var name = ""
    @State private var expiryDate = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
    @State private var amount = ""
    @State private var priceText = ""
    @State private var category = "Other"
 
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Product name", text: $name)
                    DatePicker("Use-by date", selection: $expiryDate, displayedComponents: .date)
                    TextField("Amount, e.g. 2 pack or 500 g", text: $amount)
                }
 
                Section {
                    TextField("Price paid (optional)", text: $priceText)
                        .keyboardType(.decimalPad)
                    Picker("Category", selection: $category) {
                        ForEach(FoodCategory.all, id: \.self) { Text($0) }
                    }
                } footer: {
                    Text("The price is used to work out how much money you've saved.")
                }
            }
            .navigationTitle("Add food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
 
    private func save() {
        let cleanedPrice = priceText
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
 
        let food = FoodItem(
            ownerID: ownerID,
            name: name.trimmingCharacters(in: .whitespaces),
            expiryDate: expiryDate,
            amount: amount.trimmingCharacters(in: .whitespaces),
            price: Double(cleanedPrice) ?? 0,
            category: category
        )
        modelContext.insert(food)
        dismiss()
    }
}
