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
    @State private var currentRating: Float = 0.0
    @State private var selectedMealTypes: Set<MealType> = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Recipe image with enhanced styling
                if let imageData = recipe.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 280)
                        .overlay(
                            VStack {
                                Image(systemName: "photo")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                Text("No Image")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                        )
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(recipe.title ?? "Untitled Recipe")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Rating display
                    if recipe.hasRating {
                        StarDisplayView(rating: recipe.rating, starSize: 20, showRatingText: true)
                    }
                    
                    if let tags = recipe.getTags(), !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color.blue.opacity(0.15))
                                                .overlay(
                                                    Capsule()
                                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
                
                // Rating Input Section
                RatingInputSection(rating: $currentRating)
                    .onChange(of: currentRating) { _, newValue in
                        recipe.updateRating(newValue)
                    }
                
                // Meal Type Tags Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "tag")
                            .foregroundColor(.purple)
                            .font(.title2)
                        Text("Meal Type Tags")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    MealTypeTagSelector(
                        selectedMealTypes: $selectedMealTypes,
                        title: "Quick Tag for Meal Planning",
                        showTitle: false
                    )
                    .onChange(of: selectedMealTypes) { _, newValue in
                        recipe.setMealTypes(newValue)
                        try? viewContext.save()
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                )
                
                // Nutrition Facts Section with enhanced styling
                if let nutrition = nutritionInfo {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "chart.pie")
                                .foregroundColor(.orange)
                                .font(.title2)
                            Text("Nutrition Facts")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        NutritionDialRow(nutritionInfo: nutrition)
                            .frame(height: 140)
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )
                }
                
                if let ingredients = recipe.getIngredients(), !ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "list.bullet")
                                .foregroundColor(.green)
                                .font(.title2)
                            Text("Ingredients")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(ingredients.enumerated()), id: \.offset) { index, ingredient in
                                HStack(alignment: .top, spacing: 12) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                        .padding(.top, 8)
                                    
                                    Text(ingredient)
                                        .font(.body)
                                        .lineLimit(nil)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )
                }
                
                if let instructions = recipe.getInstructions(), !instructions.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "list.number")
                                .foregroundColor(.blue)
                                .font(.title2)
                            Text("Instructions")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        LazyVStack(alignment: .leading, spacing: 20) {
                            ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                                HStack(alignment: .top, spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 32, height: 32)
                                        
                                        Text("\(index + 1)")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.top, 2)
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(instruction)
                                            .font(.body)
                                            .lineLimit(nil)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )
                }
                
                if let sourceURL = recipe.sourceURL,
                   let url = URL(string: sourceURL) {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.blue)
                            Text("View Original Recipe")
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .foregroundColor(.blue)
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
            WeeklyPlanDaySelectionView(recipe: recipe)
                .environment(\.managedObjectContext, viewContext)
        }
        .onAppear {
            // Load nutrition info and current rating when view appears
            nutritionInfo = recipe.getNutritionInfo()
            currentRating = recipe.rating
            selectedMealTypes = recipe.getMealTypes()
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
