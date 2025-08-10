import SwiftUI

struct WeeklyPlanView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var recipeManager = RecipeManager.shared
    @EnvironmentObject private var basketManager: ShoppingBasketManager
    @State private var showingRecipeSheet = false
    @State private var selectedDay: String? = "Monday"
    @State private var showingShoppingListAlert = false
    @State private var generatedListName = "Weekly Meal Plan"
    @State private var navigateToShoppingList = false
    @State private var showingManualEntrySheet = false
    @State private var manualMealTitle = ""
    @State private var manualMealIngredients = ""
    @State private var selectedRecipes: [RecipeEntity] = []
    @State private var refreshID = UUID()
    @State private var showingNutritionSummary = false
    
    // Days of the week starting with Sunday
    let daysOfWeek = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
    var body: some View {
        NavigationStack {
            VStack {
                // Weekly Nutrition Summary Card
                if !recipeManager.weeklyPlan.isEmpty {
                    WeeklyNutritionSummaryCard(
                        weeklyNutrition: calculateWeeklyNutrition(),
                        isExpanded: $showingNutritionSummary
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .animation(.easeInOut, value: showingNutritionSummary)
                }
                
                List {
                    ForEach(daysOfWeek, id: \.self) { day in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(day)
                                .font(.headline)
                                .padding(.vertical, 4)
                            
                            let dayRecipes = recipeManager.getRecipesForDay(day)
                            
                            if dayRecipes.isEmpty {
                                Button(action: {
                                    selectedDay = day
                                    showingRecipeSheet = true
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.blue)
                                        Text("Add Recipe")
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.vertical, 8)
                                }
                            } else {
                                ForEach(dayRecipes, id: \.id) { recipe in
                                    HStack {
                                        if let imageData = recipe.imageData, let uiImage = UIImage(data: imageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 60, height: 60)
                                                .cornerRadius(8)
                                        } else {
                                            Image(systemName: "photo")
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .padding()
                                                .frame(width: 60, height: 60)
                                                .background(Color.gray.opacity(0.2))
                                                .cornerRadius(8)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(recipe.title ?? "Untitled Recipe")
                                                .font(.subheadline)
                                                .lineLimit(2)
                                            
                                            if let ingredients = recipe.getIngredients(), !ingredients.isEmpty {
                                                Text("\(ingredients.count) ingredients")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            recipeManager.removeRecipeFromDay(recipe, day: day)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .font(.system(size: 22))
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                
                                // Add a single "Add Meal" button at the bottom of the day's recipes
                                Button(action: {
                                    selectedDay = day
                                    showingRecipeSheet = true
                                }) {
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
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(InsetGroupedListStyle())
                
                Button(action: {
                    generatedListName = "Weekly Meal Plan - \(formatDate(Date()))"
                    showingShoppingListAlert = true
                }) {
                    HStack {
                        Image(systemName: "cart.fill.badge.plus")
                        Text("Generate Shopping List")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom)
                .disabled(recipeManager.weeklyPlan.isEmpty)
                
                Button(action: {
                    // Explicitly set selectedDay to nil to force the picker to reset
                    print("Opening manual entry sheet, resetting selectedDay")
                    selectedDay = nil
                    showingManualEntrySheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.pencil")
                        Text("Add Manual Meal")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .id(refreshID)
            .navigationTitle("Weekly Meal Plan")
            .onAppear {
                recipeManager.loadRecipes()
                recipeManager.loadWeeklyPlan()
                print("WeeklyPlanView appeared - loaded recipes and weekly plan")
            }
            .sheet(isPresented: $showingRecipeSheet) {
                RecipeSelectionView(
                    selectedDay: selectedDay ?? "",
                    onSelectRecipe: { recipe in
                        if let day = selectedDay {
                            recipeManager.addRecipeToDay(recipe, day: day)
                        }
                    },
                    onDone: {
                        showingRecipeSheet = false
                    }
                )
                .environment(\.managedObjectContext, viewContext)
            }
            .alert("Create Shopping List", isPresented: $showingShoppingListAlert) {
                TextField("List Name", text: $generatedListName)
                
                Button("Cancel", role: .cancel) { }
                
                Button("Create") {
                    createShoppingList()
                    navigateToShoppingList = true
                }
            } message: {
                Text("Enter a name for your shopping list")
            }
            .navigationDestination(isPresented: $navigateToShoppingList) {
                ShoppingBasketView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingManualEntrySheet, onDismiss: {
                recipeManager.loadRecipes()
                recipeManager.loadWeeklyPlan()
                refreshID = UUID()
                print("Sheet dismissed - reloaded weekly plan and forced refresh")
            }) {
                NavigationView {
                    Form {
                        Section(header: Text("Meal Details")) {
                            TextField("Meal Title", text: $manualMealTitle)
                            
                            VStack(alignment: .leading) {
                                Text("Ingredients (one per line)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                TextEditor(text: $manualMealIngredients)
                                    .frame(minHeight: 100)
                            }
                        }
                        
                        Section(header: Text("Select Day")) {
                            Text("Currently selected: \(selectedDay ?? "None")")
                                .foregroundColor(.blue)
                                .font(.headline)
                                .padding(.bottom, 4)
                            
                            // Use a more direct approach with buttons for day selection
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(daysOfWeek, id: \.self) { day in
                                        Button(action: {
                                            selectedDay = day
                                            print("Selected day: \(day)")
                                        }) {
                                            Text(day)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(selectedDay == day ? Color.blue : Color.gray.opacity(0.2))
                                                .foregroundColor(selectedDay == day ? .white : .primary)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        
                        // Show already added meals for the selected day
                        if let day = selectedDay, !recipeManager.getRecipesForDay(day).isEmpty {
                            Section(header: Text("Already Added to \(day)")) {
                                ForEach(recipeManager.getRecipesForDay(day), id: \.id) { recipe in
                                    HStack {
                                        if recipe.isManualEntry {
                                            Image(systemName: "square.and.pencil")
                                                .foregroundColor(.orange)
                                        } else {
                                            Image(systemName: "checkmark.circle")
                                                .foregroundColor(.green)
                                        }
                                        Text(recipe.displayTitle())
                                            .font(.subheadline)
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("Manual Meal Entry")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Back") {
                                showingManualEntrySheet = false
                            }
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Add Meal") {
                                if addManualMeal() {
                                    print("Successfully added meal from toolbar button")
                                    // Clear the form for the next entry
                                    manualMealTitle = ""
                                    manualMealIngredients = ""
                                    
                                    // Update the UI to show the newly added recipe
                                    if let day = selectedDay {
                                        selectedRecipes = recipeManager.getRecipesForDay(day)
                                        print("Updated selectedRecipes for day: \(day) from toolbar button")
                                    }
                                    
                                    // Dismiss the sheet after adding the meal
                                    showingManualEntrySheet = false
                                } else {
                                    print("Failed to add meal from toolbar button")
                                }
                            }
                            .disabled(manualMealTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedDay == nil)
                            .font(.headline)
                            .foregroundColor(.orange)
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        Button(action: {
                            if addManualMeal() {
                                print("Successfully added meal from bottom button")
                                // Clear the form for the next entry
                                manualMealTitle = ""
                                manualMealIngredients = ""
                                
                                // Update the UI to show the newly added recipe
                                if let day = selectedDay {
                                    selectedRecipes = recipeManager.getRecipesForDay(day)
                                    print("Updated selectedRecipes for day: \(day) from bottom button")
                                }
                                
                                // Dismiss the sheet after adding the meal
                                showingManualEntrySheet = false
                            } else {
                                print("Failed to add meal from bottom button")
                            }
                        }) {
                            HStack {
                                Image(systemName: "fork.knife.circle.fill")
                                Text("Add Meal to \(selectedDay ?? "Plan")")
                                    .font(.headline)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(manualMealTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedDay == nil)
                        .padding()
                        .background(Color(UIColor.systemGroupedBackground))
                    }
                    .onAppear {
                        // If selectedDay is nil or not in the daysOfWeek array, set it to the first day
                        if selectedDay == nil || !daysOfWeek.contains(selectedDay!) {
                            selectedDay = daysOfWeek.first
                        }
                        
                        // Load the current recipes for the selected day
                        if let day = selectedDay {
                            selectedRecipes = recipeManager.getRecipesForDay(day)
                            print("Manual entry sheet appeared - loaded recipes for day: \(day)")
                        }
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func createShoppingList() {
        // Create a new shopping list
        _ = basketManager.createNewList(name: generatedListName)
        
        // Collect all ingredients from recipes in the weekly plan
        var ingredientCounts: [String: Int] = [:]
        
        for day in daysOfWeek {
            let recipes = recipeManager.getRecipesForDay(day)
            for recipe in recipes {
                if let ingredients = recipe.getIngredients() {
                    for ingredient in ingredients {
                        let cleanedIngredient = cleanIngredient(ingredient)
                        ingredientCounts[cleanedIngredient, default: 0] += 1
                    }
                }
            }
        }
        
        // Add ingredients to the shopping list
        for (ingredient, count) in ingredientCounts {
            // Determine category based on ingredient name
            let category = determineCategory(for: ingredient)
            
            // Format the ingredient name with count if more than 1
            let formattedName = count > 1 ? "\(count) x \(ingredient)" : ingredient
            
            // Add to shopping list
            basketManager.addItem(name: formattedName, quantity: 1, category: category)
        }
    }
    
    private func cleanIngredient(_ ingredient: String) -> String {
        // Remove quantities and units for better grouping
        // This is a simple implementation - could be improved with more sophisticated parsing
        return ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func determineCategory(for ingredient: String) -> String {
        let lowerIngredient = ingredient.lowercased()
        
        // Simple categorization logic
        if lowerIngredient.contains("chicken") || lowerIngredient.contains("beef") || 
           lowerIngredient.contains("pork") || lowerIngredient.contains("fish") ||
           lowerIngredient.contains("meat") {
            return "meat"
        } else if lowerIngredient.contains("milk") || lowerIngredient.contains("cheese") || 
                  lowerIngredient.contains("yogurt") || lowerIngredient.contains("cream") ||
                  lowerIngredient.contains("butter") {
            return "dairy"
        } else if lowerIngredient.contains("apple") || lowerIngredient.contains("banana") || 
                  lowerIngredient.contains("vegetable") || lowerIngredient.contains("fruit") ||
                  lowerIngredient.contains("lettuce") || lowerIngredient.contains("tomato") ||
                  lowerIngredient.contains("onion") || lowerIngredient.contains("potato") {
            return "produce"
        } else if lowerIngredient.contains("bread") || lowerIngredient.contains("roll") || 
                  lowerIngredient.contains("bun") || lowerIngredient.contains("pastry") {
            return "bakery"
        } else if lowerIngredient.contains("frozen") || lowerIngredient.contains("ice cream") {
            return "frozen"
        } else {
            return "pantry"
        }
    }
    
    private func addManualMeal() -> Bool {
        guard let day = selectedDay, !manualMealTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("ERROR: Day or meal title is empty")
            print("Selected day: \(selectedDay ?? "nil")")
            print("Meal title: \(manualMealTitle)")
            return false
        }
        
        print("Starting to add manual meal: \(manualMealTitle) for day: \(day)")
        let context = viewContext
        
        // Create a new recipe entity
        let newRecipe = RecipeEntity(context: context)
        newRecipe.id = UUID()
        newRecipe.dateAdded = Date() // Set the date added
        
        // Set the title with MANUAL: prefix
        newRecipe.title = "MANUAL:" + manualMealTitle
        
        // Add a generic image for manual entries
        if let genericImage = UIImage(systemName: "fork.knife.circle.fill")?.withTintColor(.orange, renderingMode: .alwaysOriginal) {
            // Create a larger version of the image with background
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300))
            let finalImage = renderer.image { ctx in
                // Fill background
                UIColor.systemGray6.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
                
                // Draw the image in the center
                let imageRect = CGRect(x: 50, y: 50, width: 200, height: 200)
                genericImage.draw(in: imageRect)
            }
            
            // Convert to data and save
            if let imageData = finalImage.jpegData(compressionQuality: 0.8) {
                newRecipe.imageData = imageData
            }
        }
        
        // Process ingredients
        let ingredientLines = manualMealIngredients
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if !ingredientLines.isEmpty {
            // Store ingredients in the searchTerms field for manual entries
            newRecipe.searchTerms = ingredientLines.joined(separator: "\n")
            
            // Also store as JSON in ingredientsString for consistency
            if let ingredientsData = try? JSONEncoder().encode(ingredientLines) {
                newRecipe.ingredientsString = String(data: ingredientsData, encoding: .utf8)
            }
        } else {
            // Even if no ingredients, we need to set an empty array
            if let ingredientsData = try? JSONEncoder().encode([String]()) {
                newRecipe.ingredientsString = String(data: ingredientsData, encoding: .utf8)
            }
        }
        
        // Set instructionsString which is required (set to empty array)
        if let instructionsData = try? JSONEncoder().encode([String]()) {
            newRecipe.instructionsString = String(data: instructionsData, encoding: .utf8)
        }
        
        // Set tagsString to empty array if it's required
        if let tagsData = try? JSONEncoder().encode([String]()) {
            newRecipe.tagsString = String(data: tagsData, encoding: .utf8)
        }
        
        print("Created manual meal: \(newRecipe.displayTitle()) with \(ingredientLines.count) ingredients for day: \(day)")
        
        // Save the context first to ensure the recipe exists
        do {
            try context.save()
            print("Manual meal saved to database: \(newRecipe.displayTitle()), ID: \(newRecipe.id?.uuidString ?? "unknown")")
            
            // Use RecipeManager to add the recipe to the day
            recipeManager.addRecipeToDay(newRecipe, day: day)
            print("Added recipe to day \(day) using RecipeManager")
            
            // Force refresh the view immediately
            refreshID = UUID()
            print("Forced view refresh with new ID")
            
            return true
            
        } catch {
            print("Error saving manual meal: \(error)")
            return false
        }
    }
    
    // Calculate weekly nutrition information
    private func calculateWeeklyNutrition() -> WeeklyNutritionSummary {
        var totalCalories: Double = 0
        var totalFat: Double = 0
        var totalCarbs: Double = 0
        var totalProtein: Double = 0
        var mealCount: Int = 0
        var dailyNutrition: [String: DailyNutritionSummary] = [:]
        
        // Calculate totals for each day
        for day in daysOfWeek {
            let dayRecipes = recipeManager.getRecipesForDay(day)
            var dayCalories: Double = 0
            var dayFat: Double = 0
            var dayCarbs: Double = 0
            var dayProtein: Double = 0
            
            for recipe in dayRecipes {
                let nutrition = recipe.getNutritionInfo()
                dayCalories += nutrition.calories
                dayFat += nutrition.fat
                dayCarbs += nutrition.carbs
                dayProtein += nutrition.protein
                mealCount += 1
            }
            
            // Store daily totals
            dailyNutrition[day] = DailyNutritionSummary(
                calories: dayCalories,
                fat: dayFat,
                carbs: dayCarbs,
                protein: dayProtein,
                mealCount: dayRecipes.count
            )
            
            // Add to weekly totals
            totalCalories += dayCalories
            totalFat += dayFat
            totalCarbs += dayCarbs
            totalProtein += dayProtein
        }
        
        // Calculate daily averages
        let daysWithMeals = dailyNutrition.values.filter { $0.mealCount > 0 }.count
        let dailyAvgCalories = daysWithMeals > 0 ? totalCalories / Double(daysWithMeals) : 0
        let dailyAvgFat = daysWithMeals > 0 ? totalFat / Double(daysWithMeals) : 0
        let dailyAvgCarbs = daysWithMeals > 0 ? totalCarbs / Double(daysWithMeals) : 0
        let dailyAvgProtein = daysWithMeals > 0 ? totalProtein / Double(daysWithMeals) : 0
        
        // Calculate per meal averages
        let mealAvgCalories = mealCount > 0 ? totalCalories / Double(mealCount) : 0
        let mealAvgFat = mealCount > 0 ? totalFat / Double(mealCount) : 0
        let mealAvgCarbs = mealCount > 0 ? totalCarbs / Double(mealCount) : 0
        let mealAvgProtein = mealCount > 0 ? totalProtein / Double(mealCount) : 0
        
        return WeeklyNutritionSummary(
            totalCalories: totalCalories,
            totalFat: totalFat,
            totalCarbs: totalCarbs,
            totalProtein: totalProtein,
            dailyAvgCalories: dailyAvgCalories,
            dailyAvgFat: dailyAvgFat,
            dailyAvgCarbs: dailyAvgCarbs,
            dailyAvgProtein: dailyAvgProtein,
            mealAvgCalories: mealAvgCalories,
            mealAvgFat: mealAvgFat,
            mealAvgCarbs: mealAvgCarbs,
            mealAvgProtein: mealAvgProtein,
            mealCount: mealCount,
            dailyNutrition: dailyNutrition
        )
    }
}

// Structure to hold nutrition summary for a day
struct DailyNutritionSummary {
    let calories: Double
    let fat: Double
    let carbs: Double
    let protein: Double
    let mealCount: Int
}

// Structure to hold weekly nutrition summary
struct WeeklyNutritionSummary {
    let totalCalories: Double
    let totalFat: Double
    let totalCarbs: Double
    let totalProtein: Double
    
    let dailyAvgCalories: Double
    let dailyAvgFat: Double
    let dailyAvgCarbs: Double
    let dailyAvgProtein: Double
    
    let mealAvgCalories: Double
    let mealAvgFat: Double
    let mealAvgCarbs: Double
    let mealAvgProtein: Double
    
    let mealCount: Int
    let dailyNutrition: [String: DailyNutritionSummary]
}

// Card to display weekly nutrition summary
struct WeeklyNutritionSummaryCard: View {
    let weeklyNutrition: WeeklyNutritionSummary
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack {
            HStack {
                Text("Weekly Nutrition Summary")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    isExpanded.toggle()
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            if isExpanded {
                VStack(spacing: 16) {
                    // Daily Average Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily Average")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 16) {
                            NutritionDial(
                                value: weeklyNutrition.dailyAvgCalories,
                                maxValue: 2500, // Daily recommended value
                                unit: "kcal",
                                label: "Calories",
                                colorThresholds: (good: 500, ok: 800)
                            )
                            
                            NutritionDial(
                                value: weeklyNutrition.dailyAvgFat,
                                maxValue: 70, // Daily recommended value
                                unit: "g",
                                label: "Fat",
                                colorThresholds: (good: 15, ok: 30)
                            )
                            
                            NutritionDial(
                                value: weeklyNutrition.dailyAvgCarbs,
                                maxValue: 300, // Daily recommended value
                                unit: "g",
                                label: "Carbs",
                                colorThresholds: (good: 60, ok: 100)
                            )
                            
                            NutritionDial(
                                value: weeklyNutrition.dailyAvgProtein,
                                maxValue: 50, // Daily recommended value
                                unit: "g",
                                label: "Protein",
                                colorThresholds: (good: 30, ok: 20) // For protein, higher is better
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Per Meal Average Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Per Meal Average")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                NutritionInfoRow(label: "Calories", value: weeklyNutrition.mealAvgCalories, unit: "kcal")
                                NutritionInfoRow(label: "Fat", value: weeklyNutrition.mealAvgFat, unit: "g")
                                NutritionInfoRow(label: "Carbs", value: weeklyNutrition.mealAvgCarbs, unit: "g")
                                NutritionInfoRow(label: "Protein", value: weeklyNutrition.mealAvgProtein, unit: "g")
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Total Meals")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text("\(weeklyNutrition.mealCount)")
                                    .font(.title)
                                    .fontWeight(.bold)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 12)
            } else {
                // Compact summary when collapsed
                HStack(spacing: 16) {
                    NutritionSummaryItem(
                        value: weeklyNutrition.dailyAvgCalories,
                        unit: "kcal",
                        label: "Daily Avg"
                    )
                    
                    Divider()
                    
                    NutritionSummaryItem(
                        value: weeklyNutrition.mealAvgCalories,
                        unit: "kcal",
                        label: "Per Meal"
                    )
                    
                    Divider()
                    
                    NutritionSummaryItem(
                        value: Double(weeklyNutrition.mealCount),
                        unit: "meals",
                        label: "Total"
                    )
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// Helper view for nutrition info row
struct NutritionInfoRow: View {
    let label: String
    let value: Double
    let unit: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(Int(value)) \(unit)")
                .fontWeight(.medium)
        }
    }
}

// Helper view for compact nutrition summary
struct NutritionSummaryItem: View {
    let value: Double
    let unit: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(Int(value))")
                .font(.headline)
                .fontWeight(.bold)
            
            Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WeeklyPlanView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            WeeklyPlanView()
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        }
    }
}
