import Foundation
import SwiftUI

class RecipeExtractorService {
    // No API key needed as we're using local extractors
    private let googleCloudVisionService = GoogleCloudVisionService()
    
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
    
    // Modified method to extract recipe from image data - more lenient with requirements
    func extractRecipeFromImage(_ imageData: Data) async throws -> Recipe {
        do {
            let (title, ingredients, instructions) = try await googleCloudVisionService.extractRecipeFromImage(imageData)
            
            // Use default values if fields are empty
            let recipeTitle = title.isEmpty ? "Recipe from Image" : title
            let recipeIngredients = ingredients.isEmpty ? ["No ingredients detected. Please add manually."] : ingredients
            let recipeInstructions = instructions.isEmpty ? ["No instructions detected. Please add manually."] : instructions
            
            print("Extracted recipe - Title: \(recipeTitle), Ingredients: \(recipeIngredients.count), Instructions: \(recipeInstructions.count)")
            
            // Create and return a Recipe object - always return something even if fields are empty
            return Recipe(
                title: recipeTitle,
                ingredients: recipeIngredients,
                instructions: recipeInstructions,
                images: [],
                url: ""
            )
        } catch let error as VisionAPIError {
            // For specific Vision API errors, we'll still throw them so they can be handled appropriately
            print("Vision API Error: \(error)")
            throw error
        } catch {
            // For other errors, we'll create a minimal recipe object rather than failing
            print("General error extracting recipe from image: \(error)")
            
            // Create a minimal recipe that can be edited
            return Recipe(
                title: "Recipe from Image",
                ingredients: ["No ingredients detected. Please add manually."],
                instructions: ["No instructions detected. Please add manually."],
                images: [],
                url: ""
            )
        }
    }
}
