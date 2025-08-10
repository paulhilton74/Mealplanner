import SwiftUI

struct WeeklyPlanDaySelectionView: View {
    let recipe: RecipeEntity
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recipeManager = RecipeManager.shared
    @State private var selectedDay: String? = nil
    
    private let daysOfWeek = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add to Weekly Plan")
                        .font(.title2)
                        .bold()
                    
                    Text("Select which day to add \"\(recipe.title ?? "this recipe")\" to:")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                List {
                    ForEach(daysOfWeek, id: \.self) { day in
                        Button(action: {
                            selectedDay = day
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(day)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    let dayRecipes = recipeManager.getRecipesForDay(day)
                                    if dayRecipes.isEmpty {
                                        Text("No meals planned")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("\(dayRecipes.count) meal(s) planned")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if selectedDay == day {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 22))
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .listStyle(InsetGroupedListStyle())
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        if let day = selectedDay {
                            recipeManager.addRecipeToDay(recipe, day: day)
                            dismiss()
                        }
                    }
                    .disabled(selectedDay == nil)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    let context = PersistenceController.shared.container.viewContext
    let recipe = RecipeEntity(context: context)
    recipe.title = "Sample Recipe"
    
    return WeeklyPlanDaySelectionView(recipe: recipe)
        .environment(\.managedObjectContext, context)
}