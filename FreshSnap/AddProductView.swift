//
//  AddProductView.swift
//  FreshSnap
//
//  Created by Mack Low on 21/10/2026.
//

import SwiftUI
import SwiftData
 
// FreshSnap – Week 5, Step 7 (Week 6: also the Review scan screen)
// Manual add: product, use-by date, amount, then Add (submit).
 
struct AddProductView: View {
    let ownerID: String
    let title: String
    let note: String?
    let nutrition: Nutrition?
 
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
 
    @State private var name: String
    @State private var expiryDate: Date
    @State private var amount: String
    @State private var priceText = ""
    @State private var category: String
 
    // Empty for manual add; pre-filled when opened as the Review scan screen.
    init(ownerID: String,
         title: String = "Add food",
         note: String? = nil,
         name: String = "",
         expiryDate: Date? = nil,
         amount: String = "",
         category: String = "Other",
         nutrition: Nutrition? = nil) {
        self.ownerID = ownerID
        self.title = title
        self.note = note
        self.nutrition = nutrition
        _name = State(initialValue: name)
        _expiryDate = State(initialValue: expiryDate
            ?? Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now)
        _amount = State(initialValue: amount)
        _category = State(initialValue: category)
    }
 
    var body: some View {
        NavigationStack {
            Form {
                if let note {
                    Section {
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
 
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
 
                if let nutrition {
                    Section {
                        NutritionRows(nutrition: nutrition)
                    } header: {
                        Text("Nutrition per 100 g")
                    } footer: {
                        Text("From Open Food Facts. Saved with this food.")
                    }
                }
            }
            .navigationTitle(title)
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
        food.nutrition = nutrition
        modelContext.insert(food)
        dismiss()
    }
}
