import SwiftUI
import PhotosUI

struct EditRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var recipe: RecipeEntity
    
    @State private var title: String
    @State private var ingredients: [String]
    @State private var instructions: [String]
    @State private var tags: [String]
    @State private var selectedImageData: Data?
    @State private var selectedItem: PhotosPickerItem?
    @State private var nutritionInfo: NutritionInfo
    @State private var showingNutritionSheet = false
    
    init(recipe: RecipeEntity) {
        self.recipe = recipe
        _title = State(initialValue: recipe.title ?? "")
        _ingredients = State(initialValue: recipe.getIngredients() ?? [])
        _instructions = State(initialValue: recipe.getInstructions() ?? [])
        _tags = State(initialValue: recipe.getTags() ?? [])
        _selectedImageData = State(initialValue: recipe.imageData)
        _nutritionInfo = State(initialValue: recipe.getNutritionInfo())
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Recipe Details")) {
                    TextField("Recipe Title", text: $title)
                    
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        if let selectedImageData = selectedImageData,
                           let uiImage = UIImage(data: selectedImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                        } else {
                            Label("Select Image", systemImage: "photo")
                        }
                    }
                    .onChange(of: selectedItem) { _, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                selectedImageData = data
                            }
                        }
                    }
                }
                
                Section(header: Text("Nutrition Information")) {
                    Button(action: {
                        showingNutritionSheet = true
                    }) {
                        HStack {
                            Text("Edit Nutrition Facts")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    NutritionDialRow(nutritionInfo: nutritionInfo)
                        .frame(height: 100)
                        .padding(.vertical, 8)
                }
                
                Section(header: Text("Ingredients")) {
                    ForEach(ingredients.indices, id: \.self) { index in
                        HStack {
                            TextField("Ingredient \(index + 1)", text: $ingredients[index])
                            if ingredients.count > 1 {
                                Button(action: { ingredients.remove(at: index) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    Button("Add Ingredient") {
                        ingredients.append("")
                    }
                }
                
                Section(header: Text("Instructions")) {
                    ForEach(instructions.indices, id: \.self) { index in
                        HStack {
                            TextField("Step \(index + 1)", text: $instructions[index])
                            if instructions.count > 1 {
                                Button(action: { instructions.remove(at: index) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    Button("Add Step") {
                        instructions.append("")
                    }
                }
                
                Section(header: Text("Tags")) {
                    ForEach(tags.indices, id: \.self) { index in
                        HStack {
                            TextField("Tag \(index + 1)", text: $tags[index])
                            if tags.count > 1 {
                                Button(action: { tags.remove(at: index) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    Button("Add Tag") {
                        tags.append("")
                    }
                }
            }
            .navigationTitle("Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveRecipe()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showingNutritionSheet) {
                NutritionEditorView(nutritionInfo: $nutritionInfo)
            }
        }
    }
    
    private func saveRecipe() {
        recipe.title = title
        recipe.imageData = selectedImageData
        
        // Filter out empty items
        let filteredIngredients = ingredients.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let filteredInstructions = instructions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let filteredTags = tags.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        // Convert arrays to JSON strings
        if let ingredientsData = try? JSONEncoder().encode(filteredIngredients) {
            recipe.ingredientsString = String(data: ingredientsData, encoding: .utf8)
        }
        
        if let instructionsData = try? JSONEncoder().encode(filteredInstructions) {
            recipe.instructionsString = String(data: instructionsData, encoding: .utf8)
        }
        
        if let tagsData = try? JSONEncoder().encode(filteredTags) {
            recipe.tagsString = String(data: tagsData, encoding: .utf8)
        }
        
        let searchableText = [title] + filteredIngredients + filteredTags
        let searchTerms = searchableText.joined(separator: " ")
        
        // Save the search terms first
        recipe.searchTerms = searchTerms
        
        // Then save the nutrition information separately
        // This will properly handle adding it to the search terms
        recipe.setNutritionInfo(nutritionInfo)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving recipe: \(error)")
        }
    }
}

// View for editing nutrition information
struct NutritionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var nutritionInfo: NutritionInfo
    
    // Local state for editing
    @State private var calories: String = ""
    @State private var fat: String = ""
    @State private var carbs: String = ""
    @State private var protein: String = ""
    
    init(nutritionInfo: Binding<NutritionInfo>) {
        self._nutritionInfo = nutritionInfo
        _calories = State(initialValue: String(format: "%.0f", nutritionInfo.wrappedValue.calories))
        _fat = State(initialValue: String(format: "%.1f", nutritionInfo.wrappedValue.fat))
        _carbs = State(initialValue: String(format: "%.1f", nutritionInfo.wrappedValue.carbs))
        _protein = State(initialValue: String(format: "%.1f", nutritionInfo.wrappedValue.protein))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Nutrition Facts (per serving)")) {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("Calories", text: $calories)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Fat (g)")
                        Spacer()
                        TextField("Fat", text: $fat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Carbs (g)")
                        Spacer()
                        TextField("Carbs", text: $carbs)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Protein (g)")
                        Spacer()
                        TextField("Protein", text: $protein)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
                
                Section {
                    Button("Reset to Estimated Values") {
                        // Generate new values based on ingredients
                        let generatedInfo = nutritionInfo
                        calories = String(format: "%.0f", generatedInfo.calories)
                        fat = String(format: "%.1f", generatedInfo.fat)
                        carbs = String(format: "%.1f", generatedInfo.carbs)
                        protein = String(format: "%.1f", generatedInfo.protein)
                    }
                }
            }
            .navigationTitle("Edit Nutrition Facts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveNutritionInfo()
                    }
                }
            }
        }
    }
    
    private func saveNutritionInfo() {
        // Convert text fields to doubles with fallbacks
        let caloriesValue = Double(calories) ?? nutritionInfo.calories
        let fatValue = Double(fat) ?? nutritionInfo.fat
        let carbsValue = Double(carbs) ?? nutritionInfo.carbs
        let proteinValue = Double(protein) ?? nutritionInfo.protein
        
        // Update the binding
        nutritionInfo = NutritionInfo(
            calories: caloriesValue,
            fat: fatValue,
            carbs: carbsValue,
            protein: proteinValue
        )
        
        dismiss()
    }
} 