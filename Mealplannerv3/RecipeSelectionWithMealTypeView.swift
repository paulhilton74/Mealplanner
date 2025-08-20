import SwiftUI
import CoreData

struct RecipeSelectionWithMealTypeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recipeManager = RecipeManager.shared
    @State private var searchText = ""
    @State private var isIngredientSearch = false
    @State private var ingredientSearchTerms: [String] = [""]
    @State private var selectedRecipeIds: Set<UUID> = []
    
    let selectedDay: String
    @State var selectedMealType: MealType
    let onSelectRecipe: (RecipeEntity) -> Void
    let onDone: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                // Meal type selector at the top
                VStack(spacing: 8) {
                    HStack {
                        Text("Meal Type:")
                            .font(.headline)
                        
                        Spacer()
                        
                        MealTypeSelector(selectedMealType: $selectedMealType, style: .segmented)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Divider()
                }
                
                VStack(spacing: 8) {
                    HStack {
                        if !isIngredientSearch {
                            RecipeSearchBar(text: $searchText)
                        } else {
                            Text("Search by Ingredients")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                        }
                        
                        Button(action: {
                            isIngredientSearch.toggle()
                            searchText = ""
                            if !isIngredientSearch {
                                ingredientSearchTerms = [""]
                            }
                        }) {
                            Text(isIngredientSearch ? "Regular Search" : "Ingredient Search")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    
                    if isIngredientSearch {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(0..<ingredientSearchTerms.count, id: \.self) { index in
                                    HStack {
                                        TextField("Ingredient \(index + 1)", text: $ingredientSearchTerms[index])
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                        
                                        if ingredientSearchTerms.count > 1 {
                                            Button(action: {
                                                ingredientSearchTerms.remove(at: index)
                                            }) {
                                                Image(systemName: "minus.circle.fill")
                                                    .foregroundColor(.red)
                                            }
                                        }
                                    }
                                }
                                
                                Button(action: {
                                    ingredientSearchTerms.append("")
                                }) {
                                    Label("Add Ingredient", systemImage: "plus.circle")
                                }
                                .padding(.top, 4)
                            }
                            .padding(.horizontal)
                        }
                        .frame(height: min(CGFloat(ingredientSearchTerms.count) * 44 + 44, 200))
                    }
                }
                .padding(.horizontal)
                
                List {
                    ForEach(filteredRecipes, id: \.id) { recipe in
                        Button(action: {
                            if let recipeId = recipe.id {
                                // Toggle selection state
                                if selectedRecipeIds.contains(recipeId) {
                                    selectedRecipeIds.remove(recipeId)
                                } else {
                                    selectedRecipeIds.insert(recipeId)
                                    // Call the onSelectRecipe callback
                                    onSelectRecipe(recipe)
                                }
                            }
                        }) {
                            HStack {
                                RecipeRow(recipe: recipe)
                                
                                Spacer()
                                
                                // Show selected meal type badge
                                VStack {
                                    MealTypeBadge(mealType: selectedMealType, size: .small)
                                        .font(.caption)
                                    
                                    // Show green checkmark if recipe is selected
                                    if let recipeId = recipe.id, selectedRecipeIds.contains(recipeId) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 18))
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Select Recipe for \(selectedDay)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDone()
                    }
                }
            }
            .onAppear {
                recipeManager.loadRecipes()
                
                // Load already selected recipes for this day and meal type
                let dayRecipesWithMealType = recipeManager.getRecipesForDay(selectedDay, mealType: selectedMealType.rawValue)
                selectedRecipeIds = Set(dayRecipesWithMealType.compactMap { $0.recipe.id })
            }
        }
    }
    
    var filteredRecipes: [RecipeEntity] {
        // First filter by meal type tags
        let mealTypeFilteredRecipes = recipeManager.recipes.filter { recipe in
            let mealTypeTags = recipe.getMealTypeTags()
            // Show recipe if it has the selected meal type tag, or if it has no meal type tags (untagged)
            return mealTypeTags.contains(selectedMealType) || mealTypeTags.isEmpty
        }
        
        if isIngredientSearch {
            // Filter by ingredients
            let validIngredients = ingredientSearchTerms.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            
            if validIngredients.isEmpty {
                return mealTypeFilteredRecipes
            }
            
            return mealTypeFilteredRecipes.filter { recipe in
                guard let recipeIngredients = recipe.getIngredients() else { return false }
                
                // Check if all search ingredients are in the recipe
                return validIngredients.allSatisfy { searchIngredient in
                    let searchTerm = searchIngredient.lowercased()
                    return recipeIngredients.contains { $0.lowercased().contains(searchTerm) }
                }
            }
        } else if searchText.isEmpty {
            return mealTypeFilteredRecipes
        } else {
            return mealTypeFilteredRecipes.filter { recipe in
                recipe.title?.localizedCaseInsensitiveContains(searchText) ?? false ||
                recipe.searchTerms?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
    }
}

struct RecipeSearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search recipes...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}
