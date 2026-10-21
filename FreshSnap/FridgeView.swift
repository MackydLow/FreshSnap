import SwiftUI
import SwiftData
 
// FreshSnap – Week 5, Steps 8 and 9
// The virtual fridge: food you still have, soonest use-by date first.
 
struct FridgeView: View {
    @Environment(AuthManager.self) private var auth
    @Query(sort: \FoodItem.expiryDate) private var allFood: [FoodItem]
    @State private var showingAddFood = false
 
    // Only this user's food that is still in the fridge.
    private var fridge: [FoodItem] {
        allFood.filter { $0.ownerID == auth.userID && $0.status == .inFridge }
    }
 
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
 
    var body: some View {
        NavigationStack {
            Group {
                if fridge.isEmpty {
                    ContentUnavailableView {
                        Label("Your fridge is empty", systemImage: "refrigerator")
                    } description: {
                        Text("Scan a receipt or add food by hand.")
                    } actions: {
                        Button("Add food") { showingAddFood = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        HStack {
                            Spacer()
                            Button {
                                showingAddFood = true
                            } label: {
                                Label("Add food", systemImage: "plus")
                            }
                        }
                        .padding(.horizontal)
 
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(fridge) { food in
                                NavigationLink {
                                    FoodDetailView(food: food)
                                } label: {
                                    FoodCard(food: food)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Fridge")
            .profileButton()
            .sheet(isPresented: $showingAddFood) {
                AddProductView(ownerID: auth.userID)
            }
        }
    }
}
 
struct FoodCard: View {
    let food: FoodItem
 
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(food.name)
                .font(.headline)
                .lineLimit(2)
            Text(food.expiryText)
                .font(.subheadline)
                .foregroundStyle(food.daysLeft <= 1 ? .red : .secondary)
            if !food.amount.isEmpty {
                Text(food.amount)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
