import SwiftUI

struct RecipeRowView: View {
    let recipe: RecipeEntity
    let day: String
    let mealType: MealType
    let onRemove: () -> Void
    let onChangeMealType: (MealType) -> Void
    
    var body: some View {
        HStack {
            // Recipe image
            if let imageData = recipe.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
                    .frame(width: 50, height: 50)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            
            // Recipe details
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.title ?? "Untitled Recipe")
                    .font(.subheadline)
                    .lineLimit(2)
                
                if let ingredients = recipe.getIngredients(), !ingredients.isEmpty {
                    Text("\(ingredients.count) ingredients")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Display rating stars if recipe has a rating
                if recipe.rating > 0 {
                    HStack(spacing: 2) {
                        StarRatingView(rating: .constant(Float(recipe.rating)), interactive: false)
                    }
                }
            }
            
            Spacer()
            
            // Meal type selector for editing
            Menu {
                ForEach(MealType.allCases, id: \.self) { newMealType in
                    Button(action: {
                        onChangeMealType(newMealType)
                    }) {
                        HStack {
                            Text(newMealType.rawValue)
                            if newMealType == mealType {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.blue)
                    .font(.system(size: 18))
            }
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 18))
            }
        }
        .padding(.leading, 12)
        .padding(.vertical, 2)
    }
}

// Preview provider
struct RecipeRowView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock recipe for preview
        let recipe = RecipeEntity(context: PersistenceController.shared.container.viewContext)
        recipe.title = "Sample Recipe"
        recipe.rating = 4
        
        return RecipeRowView(
            recipe: recipe,
            day: "Monday",
            mealType: .dinner,
            onRemove: {},
            onChangeMealType: { _ in }
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
