import Foundation
import CoreData

// Struct to hold nutrition information
struct NutritionInfo: Codable {
    var calories: Double
    var fat: Double
    var carbs: Double
    var protein: Double
    
    // Default values based on typical serving
    static let defaultValues = NutritionInfo(
        calories: 350,
        fat: 12,
        carbs: 45,
        protein: 15
    )
}

extension RecipeEntity {
    func getIngredients() -> [String]? {
        // For manual entries, we'll use a special tag in the searchTerms field
        // to store the ingredients as a newline-separated string
        if isManualEntry, let searchTerms = self.searchTerms {
            return searchTerms.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        
        // Fall back to the original implementation for regular recipes
        guard let ingredientsString = self.ingredientsString,
              let data = ingredientsString.data(using: .utf8) else {
            return nil
        }
        
        return try? JSONDecoder().decode([String].self, from: data)
    }
    
    func getInstructions() -> [String]? {
        guard let instructionsString = self.instructionsString,
              let data = instructionsString.data(using: .utf8) else {
            return nil
        }
        
        return try? JSONDecoder().decode([String].self, from: data)
    }
    
    func getTags() -> [String]? {
        guard let tagsString = self.tagsString,
              let data = tagsString.data(using: .utf8) else {
            return nil
        }
        
        return try? JSONDecoder().decode([String].self, from: data)
    }
    
    // Add a computed property for manual entries
    @objc var isManualEntry: Bool {
        get {
            // Use the title as a marker by checking if it has a special prefix
            // This avoids having to modify the Core Data model
            return title?.hasPrefix("MANUAL:") ?? false
        }
        set {
            if newValue && !(title?.hasPrefix("MANUAL:") ?? false) {
                // Add prefix for manual entries
                title = "MANUAL:" + (title ?? "")
            } else if !newValue && (title?.hasPrefix("MANUAL:") ?? false) {
                // Remove prefix for non-manual entries
                title = title?.replacingOccurrences(of: "MANUAL:", with: "")
            }
        }
    }
    
    // Helper method to get the display title (without the MANUAL: prefix)
    func displayTitle() -> String {
        if let title = title, title.hasPrefix("MANUAL:") {
            return String(title.dropFirst(7))
        }
        return title ?? "Untitled Recipe"
    }
    
    // MARK: - Nutrition Information
    
    // Store nutrition info in the searchTerms field with a special prefix
    private static let nutritionPrefix = "NUTRITION:"
    
    func getNutritionInfo() -> NutritionInfo {
        // Check if we have stored nutrition info
        if let searchTerms = self.searchTerms,
           searchTerms.contains(RecipeEntity.nutritionPrefix),
           let range = searchTerms.range(of: RecipeEntity.nutritionPrefix),
           let data = searchTerms[range.upperBound...].data(using: .utf8) {
            
            // Try to decode the nutrition info
            if let nutritionInfo = try? JSONDecoder().decode(NutritionInfo.self, from: data) {
                return nutritionInfo
            }
        }
        
        // If no nutrition info is stored, generate some based on ingredients
        return generateNutritionInfo()
    }
    
    func setNutritionInfo(_ nutritionInfo: NutritionInfo) {
        // Encode the nutrition info
        guard let data = try? JSONEncoder().encode(nutritionInfo),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }
        
        // Store in searchTerms with our prefix
        if var searchTerms = self.searchTerms {
            // Remove any existing nutrition info
            if let range = searchTerms.range(of: RecipeEntity.nutritionPrefix) {
                if let endRange = searchTerms[range.upperBound...].range(of: "\n") {
                    searchTerms.removeSubrange(range.lowerBound..<endRange.upperBound)
                } else {
                    searchTerms.removeSubrange(range.lowerBound...)
                }
            }
            
            // Add the new nutrition info
            searchTerms += "\n\(RecipeEntity.nutritionPrefix)\(jsonString)"
            self.searchTerms = searchTerms
        } else {
            // Create new searchTerms with just the nutrition info
            self.searchTerms = "\(RecipeEntity.nutritionPrefix)\(jsonString)"
        }
    }
    
    // Generate nutrition info based on ingredients
    private func generateNutritionInfo() -> NutritionInfo {
        // This is a simplified approach - in a real app, you would use a food database
        // to look up actual nutritional values for ingredients
        
        guard let ingredients = getIngredients(), !ingredients.isEmpty else {
            return NutritionInfo.defaultValues
        }
        
        // Base values
        var calories: Double = 0
        var fat: Double = 0
        var carbs: Double = 0
        var protein: Double = 0
        
        // Simple estimation based on ingredient count and keywords
        let ingredientCount = Double(ingredients.count)
        
        // Base values per ingredient
        calories = 100 * ingredientCount
        fat = 3 * ingredientCount
        carbs = 12 * ingredientCount
        protein = 5 * ingredientCount
        
        // Adjust based on keywords in ingredients
        for ingredient in ingredients {
            let lowercased = ingredient.lowercased()
            
            // High fat ingredients
            if lowercased.contains("oil") || lowercased.contains("butter") || 
               lowercased.contains("cream") || lowercased.contains("cheese") {
                fat += 5
                calories += 45
            }
            
            // High carb ingredients
            if lowercased.contains("sugar") || lowercased.contains("flour") || 
               lowercased.contains("rice") || lowercased.contains("pasta") || 
               lowercased.contains("bread") || lowercased.contains("potato") {
                carbs += 15
                calories += 60
            }
            
            // High protein ingredients
            if lowercased.contains("chicken") || lowercased.contains("beef") || 
               lowercased.contains("pork") || lowercased.contains("fish") || 
               lowercased.contains("egg") || lowercased.contains("tofu") || 
               lowercased.contains("bean") {
                protein += 10
                calories += 40
            }
        }
        
        // Normalize values to reasonable ranges
        calories = min(max(calories, 150), 1200)
        fat = min(max(fat, 3), 50)
        carbs = min(max(carbs, 10), 150)
        protein = min(max(protein, 5), 60)
        
        return NutritionInfo(
            calories: calories,
            fat: fat,
            carbs: carbs,
            protein: protein
        )
    }
} 