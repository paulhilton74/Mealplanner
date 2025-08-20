import Foundation
import SwiftUI

class RecipeExtractorService {
    // No API key needed as we're using local extractors
    // Removed GoogleCloudVisionService dependency
    
    init() {
        // No initialization needed
    }
    
    func extractRecipe(from urlString: String) async throws -> (title: String, ingredients: [String], instructions: [String], images: [String]) {
        guard let url = URL(string: urlString) else {
            throw RecipeParsingError.invalidFormat
        }
        
        // Fetch HTML content
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw RecipeParsingError.noData
        }
        
        // Try JSON-LD extractor first
        let jsonLDExtractor = JSONLDExtractor()
        if let recipeData = await jsonLDExtractor.parse(html: html, from: url) {
            print("Successfully extracted recipe using JSON-LD format")
            return recipeData
        }
        
        // If JSON-LD fails, try Microdata extractor
        let microdataExtractor = MicrodataExtractor()
        if let recipeData = await microdataExtractor.parse(html: html, from: url) {
            print("Successfully extracted recipe using Microdata format")
            return recipeData
        }
        
        // If both extractors fail, throw an error
        throw RecipeParsingError.missingRequiredData
    }
    
    // Modified method to extract recipe from image data - disabled since using iOS Vision framework in AddRecipeView
    func extractRecipeFromImage(_ imageData: Data) async throws -> Recipe {
        // This method is no longer used - recipe extraction from images is handled directly in AddRecipeView
        // using iOS Vision framework instead of Google Cloud Vision API
        
        // Return a default recipe structure
        return Recipe(
            title: "Recipe from Image",
            ingredients: ["Please use the Add Recipe view for image extraction"],
            instructions: ["Image extraction is handled in the Add Recipe interface"],
            images: [],
            url: ""
        )
    }
}
