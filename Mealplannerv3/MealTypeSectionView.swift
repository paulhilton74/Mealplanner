import SwiftUI

struct MealTypeSectionView: View {
    let mealType: MealType
    let recipes: [RecipeEntity]
    let day: String
    let recipeManager: RecipeManager
    let onAddRecipe: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Meal type header with badge
            HStack {
                MealTypeBadge(mealType: mealType, size: .medium)
                
                Spacer()
                
                Button(action: onAddRecipe) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                }
            }
            .padding(.vertical, 2)
            
            // Recipes for this meal type
            ForEach(recipes, id: \.id) { recipe in
                RecipeRowView(
                    recipe: recipe,
                    day: day,
                    mealType: mealType,
                    onRemove: {
                        recipeManager.removeRecipeFromDay(recipe, day: day, mealType: mealType.rawValue)
                    },
                    onChangeMealType: { newMealType in
                        recipeManager.updateMealType(for: recipe, day: day, newMealType: newMealType.rawValue)
                    }
                )
            }
        }
        .padding(.bottom, 4)
    }
}

// Preview provider
struct MealTypeSectionView_Previews: PreviewProvider {
    static var previews: some View {
        // Create mock recipes for preview
        let context = PersistenceController.shared.container.viewContext
        let recipe1 = RecipeEntity(context: context)
        recipe1.title = "Breakfast Recipe"
        recipe1.rating = 4
        
        let recipe2 = RecipeEntity(context: context)
        recipe2.title = "Another Breakfast Recipe"
        recipe2.rating = 5
        
        return MealTypeSectionView(
            mealType: .breakfast,
            recipes: [recipe1, recipe2],
            day: "Monday",
            recipeManager: RecipeManager.shared,
            onAddRecipe: {}
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
