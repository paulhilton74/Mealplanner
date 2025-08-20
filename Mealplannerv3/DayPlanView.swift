import SwiftUI

struct DayPlanView: View {
    let day: String
    let recipeManager: RecipeManager
    let onSelectDay: (String, MealType) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(day)
                .font(.headline)
                .padding(.vertical, 4)
            
            let mealTypesForDay = recipeManager.getMealTypesForDay(day)
            
            // Horizontal layout for meal types
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(MealType.allCases, id: \.self) { mealType in
                        MealTypeColumnView(
                            mealType: mealType,
                            recipes: mealTypesForDay[mealType.rawValue] ?? [],
                            day: day,
                            recipeManager: recipeManager,
                            onAddRecipe: {
                                onSelectDay(day, mealType)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddMealMenuView: View {
    let day: String
    let onSelectDay: (String, MealType) -> Void
    
    var body: some View {
        Menu {
            ForEach(MealType.allCases, id: \.self) { mealType in
                Button(action: {
                    onSelectDay(day, mealType)
                }) {
                    HStack {
                        Text(mealType.rawValue)
                        Spacer()
                        Text(mealType.icon)
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.blue)
                Text("Add Meal")
                    .foregroundColor(.blue)
            }
            .padding(.vertical, 8)
        }
    }
}

// Preview provider
struct DayPlanView_Previews: PreviewProvider {
    static var previews: some View {
        DayPlanView(
            day: "Monday",
            recipeManager: RecipeManager.shared,
            onSelectDay: { _, _ in }
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
