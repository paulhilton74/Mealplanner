import Foundation
import SwiftSoup

protocol RecipeExtractor {
    func parse(html: String, from url: URL) -> (title: String, ingredients: [String], instructions: [String], images: [String])?
}

struct BBCGoodFoodExtractor: RecipeExtractor {
    func parse(html: String, from url: URL) -> (title: String, ingredients: [String], instructions: [String], images: [String])? {
        do {
            let doc = try SwiftSoup.parse(html)
            
            // 1) Title from <h1>
            guard let h1 = try doc.select("h1").first() else {
                return nil
            }
            let title = try h1.text()
            
            // 2) Ingredients from <section id="recipe-ingredients">
            guard let ingredientsSection = try doc.select("section#recipe-ingredients").first() else {
                return nil
            }
            let ingredientLis = try ingredientsSection.select("li")
            let ingredients = try ingredientLis.map { try $0.text() }
            
            // 3) Instructions from <section id="recipe-method">
            guard let methodSection = try doc.select("section#recipe-method").first() else {
                return nil
            }
            let methodLis = try methodSection.select("li")
            let instructions = try methodLis.map { try $0.text() }
            
            // 4) Parse images from meta tags and recipe content
            var images: [String] = []
            if let ogImage = try doc.select("meta[property=og:image]").first() {
                if let imageUrl = try? ogImage.attr("content") {
                    images.append(imageUrl)
                }
            }
            
            return (title, ingredients, instructions, images)
            
        } catch {
            print("BBC Good Food parse error: \(error)")
            return nil
        }
    }
}

struct AllRecipesExtractor: RecipeExtractor {
    func parse(html: String, from url: URL) -> (title: String, ingredients: [String], instructions: [String], images: [String])? {
        do {
            let doc = try SwiftSoup.parse(html)
            
            // Title in <h1 class="headline heading-content">
            guard let titleElement = try doc.select("h1.headline.heading-content").first() else {
                return nil
            }
            let title = try titleElement.text()
            
            // Ingredients in <span class="ingredients-item-name">
            let ingredientSpans = try doc.select("span.ingredients-item-name")
            let ingredients = try ingredientSpans.map { try $0.text() }
            
            // Instructions in <li class="instructions-section-item">
            let instructionItems = try doc.select("li.instructions-section-item")
            let instructions = try instructionItems.map { try $0.text() }
            
            // Parse images from meta tags
            var images: [String] = []
            if let ogImage = try doc.select("meta[property=og:image]").first() {
                if let imageUrl = try? ogImage.attr("content") {
                    images.append(imageUrl)
                }
            }
            
            return (title, ingredients, instructions, images)
        } catch {
            print("AllRecipes parse error: \(error)")
            return nil
        }
    }
}