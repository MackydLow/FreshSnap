//
//  ReceiptReviewView.swift
//  FreshSnap
//
//  Created by Mack Low on 30/10/2026.
//

import SwiftUI
import SwiftData
 
// FreshSnap – Week 6, Steps 4 and 5 (Week 8: AI-suggested names)
// Review scan for receipts: check every item, fix names and dates,
// untick anything that isn't food, then add them all at once.
// (Flow: review the scan -> any changes? -> make the changes -> submit scan)
 
struct ReceiptReviewView: View {
    let ownerID: String
    @State var items: [ReceiptItem]
    var aiFailed = false
 
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
 
    private var chosen: [ReceiptItem] {
        items.filter(\.include)
    }
 
    private var canAdd: Bool {
        !chosen.isEmpty && chosen.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }
 
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Found \(items.count) items. Check the names and use-by dates, untick anything that isn't food, then add them. Dates are estimates, so check the packs.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if aiFailed {
                        Label("AI couldn't be reached, so names come from the dictionary only. Check them before adding.",
                              systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    } else if items.contains(where: { $0.nameSource == .ai }) {
                        Label("Some names were improved by AI. Check them before adding.", systemImage: "sparkles")
                            .font(.subheadline)
                    }
                }
 
                ForEach($items) { $item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button {
                                item.include.toggle()
                            } label: {
                                Image(systemName: item.include ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                            }
                            .buttonStyle(.borderless)
                            // VoiceOver: "Include Semi-skimmed milk, on"
                            .accessibilityLabel("Include \(item.name)")
                            .accessibilityValue(item.include ? "On" : "Off")
 
                            TextField("Product name", text: $item.name)
                                .font(.headline)
                        }
 
                        Text("On receipt: \(item.receiptText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
 
                        if item.nameSource == .ai {
                            Label("Name suggested by AI", systemImage: "sparkles")
                                .font(.caption)
                                .foregroundStyle(.tint)
                        }
 
                        if let note = item.note {
                            Label(note, systemImage: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
 
                        if item.include {
                            Text("Use-by estimate: \(item.estimateSource)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
 
                        if item.include {
                            DatePicker("Use by", selection: $item.expiryDate, displayedComponents: .date)
 
                            Picker("Category", selection: $item.category) {
                                ForEach(FoodCategory.all, id: \.self) { Text($0) }
                            }
                            .onChange(of: item.category) { _, newCategory in
                                let estimate = ShelfLife.estimate(forName: item.name, category: newCategory)
                                item.expiryDate = estimate.date
                                item.estimateSource = estimate.source
                            }
 
                            HStack {
                                Text(item.amount.isEmpty ? "No size on receipt" : item.amount)
                                Spacer()
                                Text(item.price, format: .currency(code: "GBP"))
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .opacity(item.include ? 1 : 0.5)
                }
                .onDelete { items.remove(atOffsets: $0) }
            }
            .navigationTitle("Review scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(chosen.count)") { addToFridge() }
                        .disabled(!canAdd)
                }
            }
        }
    }
 
    private func addToFridge() {
        for item in chosen {
            modelContext.insert(FoodItem(
                ownerID: ownerID,
                name: item.name.trimmingCharacters(in: .whitespaces),
                expiryDate: item.expiryDate,
                amount: item.amount,
                price: item.price,
                category: item.category
            ))
        }
        dismiss()
    }
}
