import SwiftUI

struct MealTypeColumnView: View {
    let mealType: MealType
    let recipes: [RecipeEntity]
    let day: String
    let recipeManager: RecipeManager
    let onAddRecipe: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Meal type header with badge and + button
            HStack {
                MealTypeBadge(mealType: mealType, size: .small)
                
                Spacer()
                
                Button(action: onAddRecipe) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(mealType.color)
                        .font(.system(size: 16))
                }
            }
            .frame(width: 140) // Fixed width for consistent columns
            
            // Recipe cards for this meal type
            if recipes.isEmpty {
                // Empty state
                RoundedRectangle(cornerRadius: 8)
                    .fill(mealType.lightColor)
                    .stroke(mealType.color.opacity(0.3), lineWidth: 1)
                    .frame(width: 140, height: 60)
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: "plus")
                                .foregroundColor(mealType.color.opacity(0.6))
                                .font(.system(size: 16))
                            Text("Add \(mealType.rawValue)")
                                .font(.caption)
                                .foregroundColor(mealType.color.opacity(0.7))
                        }
                    )
                    .onTapGesture {
                        onAddRecipe()
                    }
            } else {
                // Recipe cards
                ForEach(recipes, id: \.id) { recipe in
                    MealTypeRecipeCard(
                        recipe: recipe,
                        mealType: mealType,
                        day: day,
                        onRemove: {
                            recipeManager.removeRecipeFromDay(recipe, day: day, mealType: mealType.rawValue)
                        }
                    )
                }
            }
        }
    }
}

struct MealTypeRecipeCard: View {
    let recipe: RecipeEntity
    let mealType: MealType
    let day: String
    let onRemove: () -> Void
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Recipe image or placeholder
            Group {
                if let imageData = recipe.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(mealType.lightColor)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(mealType.color.opacity(0.6))
                                .font(.system(size: 20))
                        )
                }
            }
            .frame(width: 140, height: 80)
            .clipped()
            .cornerRadius(8)
            
            // Recipe title
            Text(recipe.title ?? "Untitled Recipe")
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .frame(width: 140, alignment: .leading)
                .foregroundColor(.primary)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .contextMenu {
            Button(role: .destructive, action: {
                showingDeleteAlert = true
            }) {
                Label("Remove from \(day)", systemImage: "trash")
            }
        }
        .alert("Remove Recipe", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                onRemove()
            }
        } message: {
            Text("Remove \"\(recipe.title ?? "this recipe")\" from \(mealType.rawValue) on \(day)?")
        }
    }
}

// Preview provider
struct MealTypeColumnView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 12) {
            // Empty column
            MealTypeColumnView(
                mealType: .breakfast,
                recipes: [],
                day: "Monday",
                recipeManager: RecipeManager.shared,
                onAddRecipe: {}
            )
            
            // Column with recipes - using empty array for preview
            MealTypeColumnView(
                mealType: .lunch,
                recipes: [],
                day: "Monday", 
                recipeManager: RecipeManager.shared,
                onAddRecipe: {}
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
