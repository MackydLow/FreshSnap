//
//  FoodDeatilView.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 21/10/2026.
//

import SwiftUI
import SwiftData
 
// FreshSnap – Week 5, Step 9 (Week 7, Step 1: Edit, Delete and confirm Thrown away)
// The Food item screen: details, then "Product used or thrown away?"
// Used adds the price to money saved; both take the food out of the fridge.
// Delete is for mistakes, and doesn't count as waste.
 
struct FoodDetailView: View {
    let food: FoodItem
 
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
 
    @State private var showingEdit = false
    @State private var confirmingThrowAway = false
    @State private var confirmingDelete = false
 
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
                    confirmingThrowAway = true
                } label: {
                    Label("Thrown away", systemImage: "trash")
                }
            } footer: {
                Text("Marking food as used adds its price to your money saved.")
            }
 
            Section {
                Button("Delete", role: .destructive) {
                    confirmingDelete = true
                }
            } footer: {
                Text("Use Delete for food added by mistake or scanned twice. It won't count as wasted food.")
            }
        }
        .navigationTitle("Food item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditFoodView(food: food)
        }
        .confirmationDialog("Throw away \(food.name)?",
                            isPresented: $confirmingThrowAway,
                            titleVisibility: .visible) {
            Button("Thrown away", role: .destructive) { finish(.thrownAway) }
        } message: {
            Text("This counts as wasted food in your stats.")
        }
        .confirmationDialog("Delete \(food.name)?",
                            isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteFood() }
        } message: {
            Text("It will be removed completely and won't count as waste.")
        }
    }
 
    // Saves the choice (SwiftData saves automatically) and goes back to the fridge.
    private func finish(_ status: FoodStatus) {
        food.status = status
        dismiss()
    }
 
    // Go back first, then delete once this screen has closed,
    // so it never tries to show food that no longer exists.
    private func deleteFood() {
        let context = modelContext
        let item = food
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            context.delete(item)
        }
    }
}
 
// MARK: - Edit food (Week 7)
 
struct EditFoodView: View {
    let food: FoodItem
    @Environment(\.dismiss) private var dismiss
 
    @State private var name: String
    @State private var expiryDate: Date
    @State private var amount: String
    @State private var priceText: String
    @State private var category: String
 
    init(food: FoodItem) {
        self.food = food
        _name = State(initialValue: food.name)
        _expiryDate = State(initialValue: food.expiryDate)
        _amount = State(initialValue: food.amount)
        _priceText = State(initialValue: food.price > 0 ? String(format: "%.2f", food.price) : "")
        _category = State(initialValue: food.category)
    }
 
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
                }
            }
            .navigationTitle("Edit food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
 
    // Only changes the food when Save is tapped; Cancel leaves it as it was.
    private func save() {
        let cleanedPrice = priceText
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
 
        food.name = name.trimmingCharacters(in: .whitespaces)
        food.expiryDate = expiryDate
        food.amount = amount.trimmingCharacters(in: .whitespaces)
        food.price = Double(cleanedPrice) ?? 0
        food.category = category
        dismiss()
    }
}
