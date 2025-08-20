import SwiftUI
import CoreData

struct MealTypeRecipeSelectionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recipeManager = RecipeManager.shared
    @State private var searchText = ""
    @State private var isIngredientSearch = false
    @State private var ingredientSearchTerms: [String] = [""]
    @State private var selectedMealTypeFilter: MealType?
    
    let selectedDay: String
    let preselectedMealType: MealType // The meal type from the column they clicked
    let onSelectRecipe: (RecipeEntity) -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                // Meal type filter with ALL option
                VStack(spacing: 12) {
                    Text("Adding to \(preselectedMealType.rawValue) on \(selectedDay)")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text("Filter recipes by meal type:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    // Meal type filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // All recipes button
                            Button(action: {
                                withAnimation(.easeInOut) {
                                    selectedMealTypeFilter = nil
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "list.bullet")
                                        .font(.system(size: 10))
                                    Text("ALL")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(selectedMealTypeFilter == nil ? Color.gray : Color.clear)
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                        )
                                )
                                .foregroundColor(selectedMealTypeFilter == nil ? .white : .gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Meal type buttons
                            ForEach(MealType.allCases, id: \.self) { mealType in
                                Button(action: {
                                    withAnimation(.easeInOut) {
                                        selectedMealTypeFilter = selectedMealTypeFilter == mealType ? nil : mealType
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: mealType.icon)
                                            .font(.system(size: 10))
                                        Text(mealType.rawValue)
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(selectedMealTypeFilter == mealType ? mealType.color : Color.clear)
                                            .overlay(
                                                Capsule()
                                                    .stroke(mealType.color.opacity(0.5), lineWidth: 1)
                                            )
                                    )
                                    .foregroundColor(selectedMealTypeFilter == mealType ? .white : mealType.color)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Divider()
                }
                
                // Search bar
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
                
                // Recipe list
                List {
                    if filteredRecipes.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 32))
                                .foregroundColor(.gray)
                            Text("No recipes found")
                                .font(.headline)
                                .foregroundColor(.gray)
                            if let filter = selectedMealTypeFilter {
                                Text("No \(filter.rawValue.lowercased()) recipes match your search")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("Try adjusting your search criteria")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(filteredRecipes, id: \.id) { recipe in
                            Button(action: {
                                // Add meal type tag to recipe if it doesn't have it
                                recipe.addMealTypeTag(preselectedMealType)
                                
                                // Save the context
                                try? viewContext.save()
                                
                                onSelectRecipe(recipe)
                                dismiss()
                            }) {
                                HStack {
                                    RecipeRow(recipe: recipe)
                                    
                                    Spacer()
                                    
                                    VStack(spacing: 4) {
                                        // Show existing meal type tags
                                        let mealTypeTags = recipe.getMealTypeTags()
                                        if !mealTypeTags.isEmpty {
                                            HStack(spacing: 4) {
                                                ForEach(mealTypeTags.prefix(2), id: \.self) { mealType in
                                                    MealTypeBadge(mealType: mealType, size: .small)
                                                }
                                                if mealTypeTags.count > 2 {
                                                    Text("+\(mealTypeTags.count - 2)")
                                                        .font(.caption2)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                        } else {
                                            Text("Untagged")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }
                                        
                                        // Show that it will be added to the preselected meal type
                                        HStack(spacing: 2) {
                                            Image(systemName: "plus")
                                                .font(.caption2)
                                                .foregroundColor(preselectedMealType.color)
                                            MealTypeBadge(mealType: preselectedMealType, size: .small)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Add Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                recipeManager.loadRecipes()
                // Default to showing recipes for the preselected meal type
                selectedMealTypeFilter = preselectedMealType
            }
        }
    }
    
    var filteredRecipes: [RecipeEntity] {
        var recipes = recipeManager.recipes
        
        // Filter by meal type if a filter is selected
        if let mealTypeFilter = selectedMealTypeFilter {
            recipes = recipes.filter { recipe in
                let mealTypeTags = recipe.getMealTypeTags()
                // Show recipe if it has the selected meal type tag, or if it has no meal type tags (for ALL)
                return mealTypeTags.contains(mealTypeFilter) || (mealTypeFilter == selectedMealTypeFilter && mealTypeTags.isEmpty)
            }
        }
        
        // Apply search filters
        if isIngredientSearch {
            // Filter by ingredients
            let validIngredients = ingredientSearchTerms.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            
            if !validIngredients.isEmpty {
                recipes = recipes.filter { recipe in
                    guard let recipeIngredients = recipe.getIngredients() else { return false }
                    
                    // Check if all search ingredients are in the recipe
                    return validIngredients.allSatisfy { searchIngredient in
                        let searchTerm = searchIngredient.lowercased()
                        return recipeIngredients.contains { $0.lowercased().contains(searchTerm) }
                    }
                }
            }
        } else if !searchText.isEmpty {
            recipes = recipes.filter { recipe in
                recipe.title?.localizedCaseInsensitiveContains(searchText) ?? false ||
                recipe.searchTerms?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
        
        return recipes
    }
}
