import SwiftUI
import CoreData

struct SavedRecipesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var recipeManager = RecipeManager.shared
    @State private var showingDeleteAlert = false
    @State private var recipeToDelete: RecipeEntity? = nil
    @State private var recipeToEdit: RecipeEntity? = nil
    @State private var showingEditSheet = false
    @State private var searchText = ""
    @State private var isIngredientSearch = false
    @State private var ingredientSearchTerms: [String] = [""]
    
    var body: some View {
        VStack {
            VStack(spacing: 8) {
                HStack {
                    if !isIngredientSearch {
                        SearchBar(text: $searchText)
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
            
            if recipeManager.recipes.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No Recipes Found")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Add recipes using the Recipe Extractor")
                        .foregroundColor(.gray)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredRecipes, id: \.id) { recipe in
                        NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                            RecipeRow(recipe: recipe)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                recipeToDelete = recipe
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            Button {
                                recipeToEdit = recipe
                                showingEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("My Recipes")
        .onAppear {
            recipeManager.loadRecipes()
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Recipe"),
                message: Text("Are you sure you want to delete this recipe? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    if let recipe = recipeToDelete {
                        recipeManager.deleteRecipe(recipe)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showingEditSheet, onDismiss: {
            recipeManager.loadRecipes()
        }) {
            if let recipe = recipeToEdit {
                EditRecipeView(recipe: recipe)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
    
    var filteredRecipes: [RecipeEntity] {
        if isIngredientSearch {
            // Filter by ingredients
            let validIngredients = ingredientSearchTerms.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            
            if validIngredients.isEmpty {
                return recipeManager.recipes
            }
            
            return recipeManager.recipes.filter { recipe in
                guard let recipeIngredients = recipe.getIngredients() else { return false }
                
                // Check if all search ingredients are in the recipe
                return validIngredients.allSatisfy { searchIngredient in
                    let searchTerm = searchIngredient.lowercased()
                    return recipeIngredients.contains { $0.lowercased().contains(searchTerm) }
                }
            }
        } else if searchText.isEmpty {
            return recipeManager.recipes
        } else {
            return recipeManager.recipes.filter { recipe in
                recipe.title?.localizedCaseInsensitiveContains(searchText) ?? false ||
                recipe.searchTerms?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
    }
}

struct RecipeRow: View {
    let recipe: RecipeEntity
    
    var body: some View {
        HStack(spacing: 15) {
            if let imageData = recipe.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
                    .frame(width: 80, height: 80)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title ?? "Untitled Recipe")
                    .font(.headline)
                    .lineLimit(2)
                
                if let ingredients = recipe.getIngredients(), !ingredients.isEmpty {
                    Text("\(ingredients.count) ingredients")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                if let date = recipe.dateAdded {
                    Text("Added \(date, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if recipe.hasRating {
                    CompactStarRating(rating: recipe.rating)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search recipes", text: $text)
                .disableAutocorrection(true)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct SavedRecipesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SavedRecipesView()
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        }
    }
} 