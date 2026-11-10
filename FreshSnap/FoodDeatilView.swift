//
//  FoodDeatilView.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 21/10/2026.
//

import SwiftUI
import SwiftData
 
// FreshSnap – Week 5, Step 9 (Week 7: Edit, Delete, confirm Thrown away; Week 8: nutrition)
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
 
            // Nutrition (Week 8)
            if let nutrition = food.nutrition {
                Section {
                    NutritionRows(nutrition: nutrition)
                } header: {
                    Text("Nutrition per 100 g")
                } footer: {
                    Text("From Open Food Facts. Ratings use the UK's front-of-pack guidance for food.")
                }
            } else {
                Section("Nutrition") {
                    Text("Nutrition is shown for food added by scanning its barcode.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
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
 
// MARK: - Nutrition rows (Week 8, Extra 2)
 
// UK front-of-pack traffic lights for food, per 100 g
enum TrafficLight {
    case low, medium, high
 
    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
 
    var colour: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
 
    // Low at or below the first number, high above the second
    static func rating(_ grams: Double, low: Double, high: Double) -> TrafficLight {
        if grams <= low { return .low }
        if grams > high { return .high }
        return .medium
    }
}
 
// The values in the same order as a UK food label
struct NutritionRows: View {
    let nutrition: Nutrition
 
    var body: some View {
        if let calories = nutrition.calories {
            LabeledContent("Energy", value: "\(Int(calories.rounded())) kcal")
        }
        row("Fat", nutrition.fat, rating: { .rating($0, low: 3, high: 17.5) })
        row("of which saturates", nutrition.saturatedFat, rating: { .rating($0, low: 1.5, high: 5) })
        row("Carbohydrate", nutrition.carbs)
        row("of which sugars", nutrition.sugar, rating: { .rating($0, low: 5, high: 22.5) })
        row("Fibre", nutrition.fibre)
        row("Protein", nutrition.protein)
        row("Salt", nutrition.salt, rating: { .rating($0, low: 0.3, high: 1.5) })
    }
 
    @ViewBuilder
    private func row(_ name: String, _ grams: Double?,
                     rating: ((Double) -> TrafficLight)? = nil) -> some View {
        if let grams {
            HStack {
                Text(name)
                Spacer()
                Text("\(grams.formatted(.number.precision(.fractionLength(0...1)))) g")
                    .foregroundStyle(.secondary)
                if let light = rating?(grams) {
                    // Shown in words as well as colour, for accessibility
                    Text(light.label)
                        .font(.caption.bold())
                        .foregroundStyle(light.colour)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(light.colour.opacity(0.15), in: Capsule())
                }
            }
            // VoiceOver reads the row as one line: "of which sugars, 82 g, High"
            .accessibilityElement(children: .combine)
        }
    }
}
