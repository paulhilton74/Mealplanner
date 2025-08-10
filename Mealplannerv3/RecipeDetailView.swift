import SwiftUI

struct RecipeDetailView: View {
    let recipe: RecipeEntity
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var recipeManager = RecipeManager.shared
    @State private var showingDeleteAlert = false
    @State private var showingEditSheet = false
    @State private var showingWeeklyPlannerSheet = false
    @State private var nutritionInfo: NutritionInfo?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let imageData = recipe.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(height: uiImage.size.height > 0 ? min(300, uiImage.size.height) : 300)
                        .clipped()
                        .cornerRadius(12)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.title ?? "Untitled Recipe")
                        .font(.title)
                        .bold()
                    
                    if let tags = recipe.getTags(), !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                
                // Nutrition Facts Section
                if let nutrition = nutritionInfo {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nutrition Facts")
                            .font(.headline)
                        
                        NutritionDialRow(nutritionInfo: nutrition)
                            .frame(height: 120)
                            .padding(.vertical, 8)
                    }
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                if let ingredients = recipe.getIngredients(), !ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ingredients")
                            .font(.headline)
                        
                        ForEach(ingredients, id: \.self) { ingredient in
                            HStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                Text(ingredient)
                            }
                        }
                    }
                }
                
                if let instructions = recipe.getInstructions(), !instructions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instructions")
                            .font(.headline)
                        
                        ForEach(Array(instructions.enumerated()), id: \.element) { index, instruction in
                            HStack(alignment: .top) {
                                Text("\(index + 1).")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text(instruction)
                            }
                            .padding(.bottom, 8)
                        }
                    }
                }
                
                if let sourceURL = recipe.sourceURL,
                   let url = URL(string: sourceURL) {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "link")
                            Text("View Original Recipe")
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                if let date = recipe.dateAdded {
                    Text("Added on \(date, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        showingWeeklyPlannerSheet = true
                    }) {
                        Label("Add to Weekly Planner", systemImage: "calendar.badge.plus")
                    }
                    
                    Button(action: {
                        showingEditSheet = true
                    }) {
                        Label("Edit Recipe", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: {
                        showingDeleteAlert = true
                    }) {
                        Label("Delete Recipe", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Recipe"),
                message: Text("Are you sure you want to delete this recipe? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    recipeManager.deleteRecipe(recipe)
                    dismiss()
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showingEditSheet) {
            EditRecipeView(recipe: recipe)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingWeeklyPlannerSheet) {
            WeeklyPlannerSelectionView(recipe: recipe)
                .environment(\.managedObjectContext, viewContext)
        }
        .onAppear {
            // Load nutrition info when view appears
            nutritionInfo = recipe.getNutritionInfo()
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}

struct RecipeDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        let recipe = RecipeEntity(context: context)
        recipe.title = "Sample Recipe"
        
        return NavigationView {
            RecipeDetailView(recipe: recipe)
                .environment(\.managedObjectContext, context)
        }
    }
}
