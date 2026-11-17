//
//  Favourites.swift
//  FreshSnap
//
//  Created by Mack Low on 17/11/2026.
//


import SwiftUI
import SwiftData
 
// FreshSnap – Week 9, Upgrade 3
// Favourite recipes: tap ♡ on a recipe to save it. The whole recipe is stored
// on the phone, so favourites always open offline. Each account has its own.
 
@Model
final class FavouriteRecipe {
    var ownerID: String          // Firebase user ID
    var mealID: String           // TheMealDB's ID for the recipe
    var name: String
    var thumbnailText: String    // web address of the photo
    var savedDate: Date
    var detailData: Data?        // the full recipe, so it works offline
 
    init(ownerID: String, detail: MealDetail) {
        self.ownerID = ownerID
        self.mealID = detail.id
        self.name = detail.name
        self.thumbnailText = detail.imageURL?.absoluteString ?? ""
        self.savedDate = .now
        self.detailData = try? JSONEncoder().encode(detail)
    }
 
    var summary: MealSummary {
        MealSummary(id: mealID, name: name, thumbnailURL: URL(string: thumbnailText))
    }
 
    var detail: MealDetail? {
        guard let detailData else { return nil }
        return try? JSONDecoder().decode(MealDetail.self, from: detailData)
    }
}
 
// The Favourites screen, opened from the ♡ button on the Recipes tab
struct FavouritesView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FavouriteRecipe.savedDate, order: .reverse) private var allFavourites: [FavouriteRecipe]
    @Query private var allFood: [FoodItem]
 
    private var favourites: [FavouriteRecipe] {
        allFavourites.filter { $0.ownerID == auth.userID }
    }
 
    private var fridgeNames: [String] {
        allFood.filter { $0.ownerID == auth.userID && $0.status == .inFridge }.map(\.name)
    }
 
    var body: some View {
        Group {
            if favourites.isEmpty {
                ContentUnavailableView(
                    "No favourites yet",
                    systemImage: "heart",
                    description: Text("Tap ♡ at the top of a recipe to save it here. Favourites open even without internet.")
                )
            } else {
                List {
                    ForEach(favourites) { favourite in
                        NavigationLink {
                            RecipeDetailView(meal: favourite.summary, fridgeNames: fridgeNames)
                        } label: {
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: favourite.thumbnailText)) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Color(.secondarySystemBackground)
                                }
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .accessibilityHidden(true)
 
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(favourite.name)
                                        .font(.headline)
                                    Text("Saved \(favourite.savedDate.formatted(.dateTime.day().month()))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            modelContext.delete(favourites[index])
                        }
                    }
                }
            }
        }
        .navigationTitle("Favourites")
    }
}
