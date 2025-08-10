import SwiftUI
import Vision
import CoreData
import Foundation

class RecipeManager: ObservableObject {
    static let shared = RecipeManager()
    
    @Published var recipes: [RecipeEntity] = []
    @Published var mealPlans: [NSManagedObject] = []
    @Published var weeklyPlan: [String: [RecipeEntity]] = [:]
    
    private let persistence = PersistenceController.shared
    
    private init() {
        loadRecipes()
        loadMealPlans()
        loadWeeklyPlan()
    }
    
    func loadRecipes() {
        let request = NSFetchRequest<RecipeEntity>(entityName: "RecipeEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \RecipeEntity.title, ascending: true)]
        
        do {
            recipes = try persistence.container.viewContext.fetch(request)
        } catch {
            print("Error loading recipes: \(error)")
        }
    }
    
    func loadMealPlans() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "MealPlan")
        let dateSort = NSSortDescriptor(key: "date", ascending: true)
        request.sortDescriptors = [dateSort]
        
        do {
            mealPlans = try persistence.container.viewContext.fetch(request)
        } catch {
            print("Error loading meal plans: \(error)")
        }
    }
    
    func loadWeeklyPlan() {
        let request = NSFetchRequest<WeeklyPlanEntity>(entityName: "WeeklyPlanEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "dayOfWeek", ascending: true)]
        
        do {
            let planEntities = try persistence.container.viewContext.fetch(request)
            
            // Group recipes by day
            var planByDay: [String: [RecipeEntity]] = [:]
            
            for entity in planEntities {
                guard let day = entity.dayOfWeek, let recipe = entity.recipe else { continue }
                if planByDay[day] == nil {
                    planByDay[day] = []
                }
                planByDay[day]?.append(recipe)
            }
            
            weeklyPlan = planByDay
        } catch {
            print("Error loading weekly plan: \(error)")
        }
    }
    
    func getRecipesForDay(_ day: String) -> [RecipeEntity] {
        return weeklyPlan[day] ?? []
    }
    
    func addRecipeToDay(_ recipe: RecipeEntity, day: String) {
        let context = persistence.container.viewContext
        
        // Create a new weekly plan entity
        let planEntity = WeeklyPlanEntity(context: context)
        planEntity.id = UUID()
        planEntity.dayOfWeek = day
        planEntity.recipe = recipe
        
        // Update the in-memory model
        if weeklyPlan[day] == nil {
            weeklyPlan[day] = []
        }
        weeklyPlan[day]?.append(recipe)
        
        do {
            try context.save()
            objectWillChange.send()
        } catch {
            print("Error adding recipe to day: \(error)")
            context.rollback()
        }
    }
    
    func removeRecipeFromDay(_ recipe: RecipeEntity, day: String) {
        let context = persistence.container.viewContext
        
        // Find and delete the corresponding WeeklyPlanEntity
        let request = NSFetchRequest<WeeklyPlanEntity>(entityName: "WeeklyPlanEntity")
        request.predicate = NSPredicate(format: "dayOfWeek == %@ AND recipe == %@", day, recipe)
        
        do {
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            
            // Update the in-memory model
            weeklyPlan[day]?.removeAll { $0.id == recipe.id }
            if weeklyPlan[day]?.isEmpty == true {
                weeklyPlan[day] = nil
            }
            
            try context.save()
            objectWillChange.send()
        } catch {
            print("Error removing recipe from day: \(error)")
            context.rollback()
        }
    }
    
    // Legacy method for backward compatibility
    func assignRecipe(_ recipe: RecipeEntity, toDay day: String) {
        // First remove any existing recipes for this day
        let existingRecipes = weeklyPlan[day] ?? []
        for existingRecipe in existingRecipes {
            removeRecipeFromDay(existingRecipe, day: day)
        }
        
        // Then add the new recipe
        addRecipeToDay(recipe, day: day)
    }
    
    // Legacy method for backward compatibility
    func removeRecipe(fromDay day: String) {
        let existingRecipes = weeklyPlan[day] ?? []
        for existingRecipe in existingRecipes {
            removeRecipeFromDay(existingRecipe, day: day)
        }
    }
    
    func saveRecipe(title: String, ingredients: [String], instructions: [String], tags: [String], imageData: Data? = nil, sourceURL: String? = nil) {
        let context = persistence.container.viewContext
        let recipe = RecipeEntity(context: context)
        
        recipe.id = UUID()
        recipe.title = title
        recipe.dateAdded = Date()
        
        // Convert arrays to JSON strings
        if let ingredientsData = try? JSONEncoder().encode(ingredients) {
            recipe.ingredientsString = String(data: ingredientsData, encoding: .utf8)
        }
        
        if let instructionsData = try? JSONEncoder().encode(instructions) {
            recipe.instructionsString = String(data: instructionsData, encoding: .utf8)
        }
        
        if let tagsData = try? JSONEncoder().encode(tags) {
            recipe.tagsString = String(data: tagsData, encoding: .utf8)
        }
        recipe.imageData = imageData
        recipe.sourceURL = sourceURL
        
        // Create searchable terms
        let searchableText = [title] + ingredients + tags
        recipe.searchTerms = searchableText.joined(separator: " ")
        
        do {
            try context.save()
            loadRecipes()
        } catch {
            print("Error saving recipe: \(error)")
        }
    }
    
    func deleteRecipe(_ recipe: RecipeEntity) {
        let context = persistence.container.viewContext
        context.delete(recipe)
        
        do {
            try context.save()
            loadRecipes()
        } catch {
            print("Error deleting recipe: \(error)")
            context.rollback()
        }
    }
    
    func saveMealPlan(recipe: RecipeEntity, date: Date) {
        let context = persistence.container.viewContext
        let mealPlan = NSEntityDescription.insertNewObject(forEntityName: "MealPlan", into: context)
        
        mealPlan.setValue(UUID(), forKey: "id")
        mealPlan.setValue(date, forKey: "date")
        mealPlan.setValue(recipe, forKey: "recipe")
        
        do {
            try context.save()
            loadMealPlans()
        } catch {
            print("Error saving meal plan: \(error)")
            context.rollback()
        }
    }
    
    func getMealPlan(for date: Date) -> NSManagedObject? {
        return mealPlans.first { 
            if let mealPlanDate = ($0.value(forKey: "date") as? Date) {
                return Calendar.current.isDate(mealPlanDate, inSameDayAs: date)
            }
            return false
        }
    }
    
    func getPlannedDates() -> Set<Date> {
        return Set(mealPlans.compactMap { $0.value(forKey: "date") as? Date })
    }
    
    func extractRecipeFromURL(_ urlString: String) async throws -> (title: String, ingredients: [String], instructions: [String], images: [(url: URL, title: String?)]) {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotParseResponse)
        }
        
        var title = ""
        var ingredients: [String] = []
        var instructions: [String] = []
        var images: [(url: URL, title: String?)] = []
        
        // Common patterns for recipe websites
        let titlePatterns = [
            "\"name\":\\s*\"([^\"]+)\"",
            "<meta\\s+property=\"og:title\"\\s+content=\"([^\"]+)\"",
            "<meta\\s+name=\"title\"\\s+content=\"([^\"]+)\"",
            "<h1[^>]*>([^<]+)</h1>",
            "<title[^>]*>([^<|]+)(?:\\s*\\|[^<]*)?</title>"
        ]
        
        // Try to extract title
        for pattern in titlePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: htmlString, options: [], range: NSRange(htmlString.startIndex..., in: htmlString)),
               let titleRange = Range(match.range(at: 1), in: htmlString) {
                title = String(htmlString[titleRange])
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&#39;", with: "'")
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty { break }
            }
        }
        
        // Extract all possible recipe images
        let imagePatterns = [
            // Schema.org recipe image
            "\"image\":\\s*\"([^\"]+)\"",
            // OpenGraph image
            "<meta\\s+property=\"og:image\"\\s+content=\"([^\"]+)\"",
            // Recipe-specific images
            "<img[^>]+class=\"[^\"]*recipe[^\"]*\"[^>]+src=\"([^\"]+)\"[^>]*alt=\"([^\"]+)\"",
            "<img[^>]+class=\"[^\"]*recipe[^\"]*\"[^>]+src=\"([^\"]+)\"",
            // General content images
            "<img[^>]+src=\"([^\"]+)\"[^>]*alt=\"([^\"]+)\"[^>]*>",
            "<img[^>]+src=\"([^\"]+)\"[^>]*>"
        ]
        
        for pattern in imagePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let matches = regex.matches(in: htmlString, options: [], range: NSRange(htmlString.startIndex..., in: htmlString))
                
                for match in matches {
                    if let urlRange = Range(match.range(at: 1), in: htmlString) {
                        let urlString = String(htmlString[urlRange])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if let url = URL(string: urlString) ?? URL(string: urlString, relativeTo: url)?.absoluteURL {
                            var imageTitle: String? = nil
                            if match.numberOfRanges > 2,
                               let titleRange = Range(match.range(at: 2), in: htmlString) {
                                imageTitle = String(htmlString[titleRange])
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                            
                            // Only add unique images
                            if !images.contains(where: { $0.url == url }) {
                                images.append((url: url, title: imageTitle))
                            }
                        }
                    }
                }
            }
        }
        
        // Filter out non-recipe related images
        images = images.filter { image in
            let imageString = (image.url.lastPathComponent + (image.title ?? "")).lowercased()
            return imageString.contains("recipe") || 
                   imageString.contains("food") || 
                   imageString.contains("dish") ||
                   imageString.contains("meal") ||
                   title.lowercased().contains(where: { imageString.contains($0) })
        }
        
        // Try to extract ingredients
        let ingredientPatterns = [
            "\"recipeIngredient\":\\s*\\[(.*?)\\]",
            "<li[^>]*class=\"[^\"]*ingredient[^\"]*\"[^>]*>([^<]+)</li>",
            "<div[^>]*class=\"[^\"]*ingredient[^\"]*\"[^>]*>([^<]+)</div>",
            "<ul[^>]*class=\"[^\"]*ingredients[^\"]*\"[^>]*>(.*?)</ul>"
        ]
        
        for pattern in ingredientPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let matches = regex.matches(in: htmlString, options: [], range: NSRange(htmlString.startIndex..., in: htmlString))
                
                if pattern.contains("recipeIngredient") {
                    // Handle JSON-LD format
                    if let match = matches.first,
                       let range = Range(match.range(at: 1), in: htmlString) {
                        let jsonString = String(htmlString[range])
                        ingredients = jsonString
                            .components(separatedBy: ",")
                            .map { $0.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                    }
                } else if pattern.contains("ul") {
                    // Handle list format
                    if let match = matches.first,
                       let range = Range(match.range(at: 1), in: htmlString) {
                        let listContent = String(htmlString[range])
                        let itemRegex = try? NSRegularExpression(pattern: "<li[^>]*>([^<]+)</li>", options: [.caseInsensitive])
                        if let itemMatches = itemRegex?.matches(in: listContent, options: [], range: NSRange(listContent.startIndex..., in: listContent)) {
                            for itemMatch in itemMatches {
                                if let itemRange = Range(itemMatch.range(at: 1), in: listContent) {
                                    let ingredient = String(listContent[itemRange])
                                        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                                        .trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !ingredient.isEmpty && !ingredients.contains(ingredient) {
                                        ingredients.append(ingredient)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Handle individual items
                    for match in matches {
                        if let range = Range(match.range(at: 1), in: htmlString) {
                            let ingredient = String(htmlString[range])
                                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            if !ingredient.isEmpty && !ingredients.contains(ingredient) {
                                ingredients.append(ingredient)
                            }
                        }
                    }
                }
                
                if !ingredients.isEmpty { break }
            }
        }
        
        // Try to extract instructions
        let instructionPatterns = [
            "\"recipeInstructions\":\\s*\\[(.*?)\\]",
            "<li[^>]*class=\"[^\"]*instruction[^\"]*\"[^>]*>([^<]+)</li>",
            "<div[^>]*class=\"[^\"]*instruction[^\"]*\"[^>]*>([^<]+)</div>",
            "<ol[^>]*class=\"[^\"]*instructions[^\"]*\"[^>]*>(.*?)</ol>"
        ]
        
        for pattern in instructionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let matches = regex.matches(in: htmlString, options: [], range: NSRange(htmlString.startIndex..., in: htmlString))
                
                if pattern.contains("recipeInstructions") {
                    // Handle JSON-LD format
                    if let match = matches.first,
                       let range = Range(match.range(at: 1), in: htmlString) {
                        let jsonString = String(htmlString[range])
                        instructions = jsonString
                            .components(separatedBy: "},")
                            .compactMap { instruction -> String? in
                                if let textRange = instruction.range(of: "\"text\":\"([^\"]+)\"", options: .regularExpression) {
                                    return String(instruction[textRange])
                                        .replacingOccurrences(of: "\"text\":\"", with: "")
                                        .replacingOccurrences(of: "\"", with: "")
                                        .trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                                return nil
                            }
                            .filter { !$0.isEmpty }
                    }
                } else if pattern.contains("ol") {
                    // Handle ordered list format
                    if let match = matches.first,
                       let range = Range(match.range(at: 1), in: htmlString) {
                        let listContent = String(htmlString[range])
                        let itemRegex = try? NSRegularExpression(pattern: "<li[^>]*>([^<]+)</li>", options: [.caseInsensitive])
                        if let itemMatches = itemRegex?.matches(in: listContent, options: [], range: NSRange(listContent.startIndex..., in: listContent)) {
                            for itemMatch in itemMatches {
                                if let itemRange = Range(itemMatch.range(at: 1), in: listContent) {
                                    let instruction = String(listContent[itemRange])
                                        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                                        .trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !instruction.isEmpty && !instructions.contains(instruction) {
                                        instructions.append(instruction)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Handle individual items
                    for match in matches {
                        if let range = Range(match.range(at: 1), in: htmlString) {
                            let instruction = String(htmlString[range])
                                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            if !instruction.isEmpty && !instructions.contains(instruction) {
                                instructions.append(instruction)
                            }
                        }
                    }
                }
                
                if !instructions.isEmpty { break }
            }
        }
        
        return (title, ingredients, instructions, images)
    }
    
    func extractTextFromImage(_ imageData: Data) async throws -> (ingredients: [String], instructions: [String]) {
        guard let cgImage = UIImage(data: imageData)?.cgImage else {
            throw NSError(domain: "RecipeManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        
        try requestHandler.perform([request])
        
        guard let observations = request.results else {
            return ([], [])
        }
        
        let recognizedText = observations.compactMap { $0.topCandidates(1).first?.string }
        
        var ingredients: [String] = []
        var instructions: [String] = []
        var isInIngredientSection = false
        var isInInstructionSection = false
        
        for line in recognizedText {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty { continue }
            
            // Check for section headers
            let lowerLine = trimmedLine.lowercased()
            if lowerLine.contains("ingredient") {
                isInIngredientSection = true
                isInInstructionSection = false
                continue
            } else if lowerLine.contains("instruction") || lowerLine.contains("direction") || lowerLine.contains("method") {
                isInIngredientSection = false
                isInInstructionSection = true
                continue
            }
            
            // Process line based on current section
            if isInIngredientSection {
                ingredients.append(trimmedLine)
            } else if isInInstructionSection {
                instructions.append(trimmedLine)
            } else {
                // If no section is identified, try to guess based on content
                if trimmedLine.first?.isNumber == true || trimmedLine.contains("cup") || trimmedLine.contains("tbsp") || 
                   trimmedLine.contains("tsp") || trimmedLine.contains("oz") || trimmedLine.contains("gram") {
                    ingredients.append(trimmedLine)
                } else if trimmedLine.contains(".") || trimmedLine.contains("Step") {
                    instructions.append(trimmedLine)
                }
            }
        }
        
        return (ingredients, instructions)
    }
    
    func saveWeeklyPlan(_ weeklyPlan: [Int: RecipeEntity]) {
        let context = persistence.container.viewContext
        
        // Get the start of the current week (Monday)
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Make Monday the first day
        let today = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        
        // Delete existing meal plans for this week
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "MealPlan")
        let startOfWeek = calendar.startOfDay(for: weekStart)
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
        
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfWeek as NSDate, endOfWeek as NSDate)
        
        do {
            let existingPlans = try context.fetch(fetchRequest)
            existingPlans.forEach { context.delete($0) }
        } catch {
            print("Error fetching existing meal plans: \(error)")
        }
        
        // Save new meal plans
        for (dayIndex, recipe) in weeklyPlan {
            let mealPlan = NSEntityDescription.insertNewObject(forEntityName: "MealPlan", into: context)
            let dayDate = calendar.date(byAdding: .day, value: dayIndex, to: weekStart)!
            
            mealPlan.setValue(UUID(), forKey: "id")
            mealPlan.setValue(dayDate, forKey: "date")
            mealPlan.setValue(recipe, forKey: "recipe")
        }
        
        do {
            try context.save()
            loadMealPlans()
        } catch {
            print("Error saving weekly plan: \(error)")
            context.rollback()
        }
    }
    
    func loadCurrentWeekPlan() -> [Int: RecipeEntity] {
        var weeklyPlan: [Int: RecipeEntity] = [:]
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Make Monday the first day
        
        let today = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        let startOfWeek = calendar.startOfDay(for: weekStart)
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "MealPlan")
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfWeek as NSDate, endOfWeek as NSDate)
        
        do {
            let mealPlans = try persistence.container.viewContext.fetch(fetchRequest)
            
            for plan in mealPlans {
                if let date = plan.value(forKey: "date") as? Date,
                   let recipe = plan.value(forKey: "recipe") as? RecipeEntity {
                    let dayIndex = calendar.dateComponents([.day], from: weekStart, to: date).day ?? 0
                    weeklyPlan[dayIndex] = recipe
                }
            }
        } catch {
            print("Error loading current week plan: \(error)")
        }
        return weeklyPlan
    }
}
