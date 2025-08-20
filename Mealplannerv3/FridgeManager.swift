import SwiftUI
import Foundation
import CoreData
import Vision
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

class FridgeManager: ObservableObject {
    static let shared = FridgeManager()
    
    @Published var fridgeItems: [FridgeItem] = []
    @Published var expiringItems: [FridgeItem] = []
    
    private var persistence: PersistenceController {
        return PersistenceController.shared
    }
    
    private init() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadFridgeItems()
            self.setupNotifications()
        }
    }
    
    func loadFridgeItems() {
        let request = NSFetchRequest<FridgeItem>(entityName: "FridgeItem")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FridgeItem.expiryDate, ascending: true),
            NSSortDescriptor(keyPath: \FridgeItem.name, ascending: true)
        ]
        
        do {
            fridgeItems = try persistence.container.viewContext.fetch(request)
            updateExpiringItems()
        } catch {
            print("Error loading fridge items: \(error)")
        }
    }
    
    func saveFridgeItem(name: String, expiryDate: Date, category: String, imageData: Data? = nil, notes: String? = nil) {
        let context = persistence.container.viewContext
        let fridgeItem = FridgeItem(context: context)
        
        fridgeItem.id = UUID()
        fridgeItem.name = name
        fridgeItem.expiryDate = expiryDate
        fridgeItem.dateAdded = Date()
        fridgeItem.category = category
        fridgeItem.imageData = imageData
        fridgeItem.notes = notes
        
        do {
            try context.save()
            loadFridgeItems()
            scheduleNotificationForItem(fridgeItem)
        } catch {
            print("Error saving fridge item: \(error)")
        }
    }
    
    func updateFridgeItem(_ item: FridgeItem, name: String, expiryDate: Date, category: String, imageData: Data? = nil, notes: String? = nil) {
        let context = persistence.container.viewContext
        
        item.name = name
        item.expiryDate = expiryDate
        item.category = category
        if let imageData = imageData {
            item.imageData = imageData
        }
        item.notes = notes
        
        do {
            try context.save()
            loadFridgeItems()
            // Cancel old notification and schedule new one
            if let itemId = item.id {
                cancelNotification(for: itemId)
                scheduleNotificationForItem(item)
            }
        } catch {
            print("Error updating fridge item: \(error)")
        }
    }
    
    func deleteFridgeItem(_ item: FridgeItem) {
        let context = persistence.container.viewContext
        
        // Cancel notification for this item
        if let itemId = item.id {
            cancelNotification(for: itemId)
        }
        
        context.delete(item)
        
        do {
            try context.save()
            loadFridgeItems()
        } catch {
            print("Error deleting fridge item: \(error)")
            context.rollback()
        }
    }
    
    private func updateExpiringItems() {
        expiringItems = fridgeItems.filter { $0.isExpiringSoon || $0.isExpired }
    }
    
    func getItemsByCategory() -> [String: [FridgeItem]] {
        return Dictionary(grouping: fridgeItems) { item in
            item.category ?? "Other"
        }
    }
    
    func getExpiringItemsCount() -> Int {
        return expiringItems.count
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
        }
    }
    
    private func scheduleNotificationForItem(_ item: FridgeItem) {
        guard let itemId = item.id,
              let expiryDate = item.expiryDate,
              let itemName = item.name else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Food Expiring Soon!"
        content.body = "\(itemName) expires tomorrow. Check your fridge!"
        content.sound = .default
        content.badge = 1
        
        // Schedule notification 1 day before expiry at 9 AM
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Calendar.current.date(byAdding: .day, value: -1, to: expiryDate) ?? expiryDate)
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: itemId.uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Notification scheduled for \(itemName)")
            }
        }
    }
    
    private func cancelNotification(for itemId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [itemId.uuidString])
    }
    
    // MARK: - Image Processing
    
    func extractItemNameFromImage(_ imageData: Data) async throws -> String? {
        guard let cgImage = UIImage(data: imageData)?.cgImage else {
            throw NSError(domain: "FridgeManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        try requestHandler.perform([request])
        
        guard let observations = request.results else {
            return nil
        }
        
        let recognizedText = observations.compactMap { $0.topCandidates(1).first?.string }
        return extractItemNameFromText(recognizedText)
    }
    
    private func extractItemNameFromText(_ textLines: [String]) -> String? {
        // Common food items and product types to look for
        let foodKeywords = [
            "milk", "bread", "cheese", "butter", "eggs", "yogurt", "chicken", "beef", "pork",
            "fish", "salmon", "tuna", "apple", "banana", "orange", "carrot", "potato", "onion",
            "tomato", "lettuce", "spinach", "broccoli", "rice", "pasta", "cereal", "juice",
            "water", "soda", "beer", "wine", "coffee", "tea", "sugar", "flour", "oil",
            "salt", "pepper", "garlic", "lemon", "lime", "strawberry", "blueberry", "grape",
            "cucumber", "bell pepper", "mushroom", "avocado", "corn", "beans", "nuts",
            "cream", "soup", "sauce", "jam", "honey", "chocolate", "biscuit", "cookie",
            "crackers", "chips", "pizza", "sandwich", "wrap", "salad", "smoothie"
        ]
        
        // Product descriptors that indicate food items
        let productDescriptors = [
            "organic", "fresh", "natural", "whole", "skimmed", "semi-skimmed", "low fat",
            "fat free", "greek", "plain", "vanilla", "strawberry", "chocolate", "original",
            "extra virgin", "virgin", "unsalted", "salted", "smoked", "free range",
            "lean", "minced", "diced", "sliced", "chopped", "frozen", "chilled"
        ]
        
        var bestMatch: String? = nil
        var bestScore = 0
        
        // Look for complete product names with descriptors
        for line in textLines {
            let cleanedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercaseLine = cleanedLine.lowercased()
            
            // Skip very short lines, very long lines, or lines that look like dates/codes
            if cleanedLine.count < 3 || cleanedLine.count > 50 {
                continue
            }
            
            // Skip lines that look like barcodes, dates, or nutritional info
            if lowercaseLine.contains("best before") || 
               lowercaseLine.contains("use by") || 
               lowercaseLine.contains("exp") ||
               lowercaseLine.contains("bb") ||
               lowercaseLine.contains("kcal") ||
               lowercaseLine.contains("calories") ||
               lowercaseLine.contains("protein") ||
               lowercaseLine.contains("fat") ||
               lowercaseLine.contains("carb") ||
               lowercaseLine.range(of: #"^\d+$"#, options: .regularExpression) != nil ||
               lowercaseLine.range(of: #"^\d{8,}"#, options: .regularExpression) != nil {
                continue
            }
            
            var score = 0
            
            // Check for food keywords
            for keyword in foodKeywords {
                if lowercaseLine.contains(keyword) {
                    score += 10
                    break
                }
            }
            
            // Check for product descriptors
            for descriptor in productDescriptors {
                if lowercaseLine.contains(descriptor) {
                    score += 5
                }
            }
            
            // Prefer lines with multiple words (more likely to be complete product names)
            let wordCount = cleanedLine.components(separatedBy: .whitespaces).count
            if wordCount >= 2 && wordCount <= 6 {
                score += wordCount * 2
            }
            
            // Prefer lines that start with capital letters (product names)
            if cleanedLine.first?.isUppercase == true {
                score += 3
            }
            
            // Prefer lines with reasonable length for product names
            if cleanedLine.count >= 8 && cleanedLine.count <= 30 {
                score += 5
            }
            
            if score > bestScore {
                bestScore = score
                bestMatch = cleanedLine
            }
        }
        
        // If we found a good match, return it
        if let match = bestMatch, bestScore >= 10 {
            return match
        }
        
        // Fallback: look for any line with food keywords
        for line in textLines {
            let cleanedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercaseLine = cleanedLine.lowercased()
            
            if cleanedLine.count >= 3 && cleanedLine.count <= 40 {
                for keyword in foodKeywords {
                    if lowercaseLine.contains(keyword) {
                        return cleanedLine
                    }
                }
            }
        }
        
        // Final fallback: return the first reasonable line
        for line in textLines {
            let cleanedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanedLine.count >= 4 && cleanedLine.count <= 25 {
                let lowercaseLine = cleanedLine.lowercased()
                // Skip obvious non-product text
                if !lowercaseLine.contains("ingredients") &&
                   !lowercaseLine.contains("nutrition") &&
                   !lowercaseLine.contains("allergen") &&
                   !lowercaseLine.contains("storage") {
                    return cleanedLine
                }
            }
        }
        
        return nil
    }
    
    func extractDatesFromImage(_ imageData: Data) async throws -> [Date] {
        guard let cgImage = UIImage(data: imageData)?.cgImage else {
            throw NSError(domain: "FridgeManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        try requestHandler.perform([request])
        
        guard let observations = request.results else {
            return []
        }
        
        let recognizedText = observations.compactMap { $0.topCandidates(1).first?.string }
        return extractDatesFromText(recognizedText)
    }
    
    private func extractDatesFromText(_ textLines: [String]) -> [Date] {
        let dateFormatter = DateFormatter()
        var foundDates: [Date] = []
        var expiryDates: [Date] = [] // Prioritize expiry-related dates
        
        // Common date formats to try
        let dateFormats = [
            "dd/MM/yyyy", "MM/dd/yyyy", "yyyy-MM-dd",
            "dd-MM-yyyy", "MM-dd-yyyy", "dd.MM.yyyy",
            "MMM dd yyyy", "dd MMM yyyy", "MMMM dd, yyyy",
            "dd/MM/yy", "MM/dd/yy", "dd-MM-yy",
            "MMM dd", "dd MMM", "MMM yyyy", "dd MMM yy",
            "MMM dd yy", "dd/MM", "MM/dd"
        ]
        
        // Expiry-related keywords to prioritize
        let expiryKeywords = [
            "use by", "best before", "best by", "expires", "exp", "bb", 
            "use before", "consume by", "sell by", "freeze by"
        ]
        
        for line in textLines {
            let cleanedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercaseLine = cleanedLine.lowercased()
            
            // Check if this line contains expiry-related keywords
            let isExpiryLine = expiryKeywords.contains { keyword in
                lowercaseLine.contains(keyword)
            }
            
            // Look for date patterns in the text
            for format in dateFormats {
                dateFormatter.dateFormat = format
                
                // For formats without year, assume current or next year
                if !format.contains("y") {
                    dateFormatter.defaultDate = Date()
                }
                
                // Try to parse the entire line
                if let date = dateFormatter.date(from: cleanedLine) {
                    let adjustedDate = adjustDateForCurrentYear(date, format: format)
                    if isValidExpiryDate(adjustedDate) {
                        if isExpiryLine {
                            expiryDates.append(adjustedDate)
                        } else {
                            foundDates.append(adjustedDate)
                        }
                        break
                    }
                }
                
                // Try to find date patterns within the line using regex
                let dateRegexPatterns = [
                    "\\d{1,2}/\\d{1,2}/\\d{2,4}",     // DD/MM/YYYY or MM/DD/YYYY
                    "\\d{1,2}-\\d{1,2}-\\d{2,4}",     // DD-MM-YYYY or MM-DD-YYYY
                    "\\d{1,2}\\.\\d{1,2}\\.\\d{2,4}", // DD.MM.YYYY
                    "\\d{1,2}/\\d{1,2}/\\d{2}",       // DD/MM/YY or MM/DD/YY
                    "\\d{1,2}-\\d{1,2}-\\d{2}",       // DD-MM-YY or MM-DD-YY
                    "\\d{1,2}/\\d{1,2}",              // DD/MM or MM/DD
                    "\\b\\w{3}\\s+\\d{1,2}\\s+\\d{4}\\b", // MMM DD YYYY
                    "\\b\\d{1,2}\\s+\\w{3}\\s+\\d{4}\\b", // DD MMM YYYY
                    "\\b\\w{3}\\s+\\d{1,2}\\s+\\d{2}\\b", // MMM DD YY
                    "\\b\\d{1,2}\\s+\\w{3}\\s+\\d{2}\\b", // DD MMM YY
                    "\\b\\w{3}\\s+\\d{1,2}\\b",          // MMM DD
                    "\\b\\d{1,2}\\s+\\w{3}\\b"           // DD MMM
                ]
                
                for pattern in dateRegexPatterns {
                    do {
                        let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                        let matches = regex.matches(in: cleanedLine, options: [], range: NSRange(cleanedLine.startIndex..., in: cleanedLine))
                        
                        for match in matches {
                            if let range = Range(match.range, in: cleanedLine) {
                                let dateString = String(cleanedLine[range])
                                if let date = dateFormatter.date(from: dateString) {
                                    let adjustedDate = adjustDateForCurrentYear(date, format: format)
                                    if isValidExpiryDate(adjustedDate) {
                                        if isExpiryLine {
                                            expiryDates.append(adjustedDate)
                                        } else {
                                            foundDates.append(adjustedDate)
                                        }
                                    }
                                }
                            }
                        }
                    } catch {
                        continue
                    }
                }
            }
        }
        
        // Prioritize expiry dates, then other dates
        let allDates = expiryDates + foundDates
        
        // Remove duplicates and sort
        let uniqueDates = Array(Set(allDates)).sorted()
        return uniqueDates
    }
    
    private func adjustDateForCurrentYear(_ date: Date, format: String) -> Date {
        // If format doesn't include year, or is a 2-digit year that seems old
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let dateYear = calendar.component(.year, from: date)
        
        // If the date year is before current year - 1, it's likely a 2-digit year interpretation issue
        if dateYear < currentYear - 1 {
            // Adjust to current or next year
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            
            // If the month/day has passed this year, assume next year
            let thisYearDate = calendar.date(from: DateComponents(year: currentYear, month: components.month, day: components.day)) ?? date
            if thisYearDate < Date() {
                components.year = currentYear + 1
            } else {
                components.year = currentYear
            }
            
            return calendar.date(from: components) ?? date
        }
        
        return date
    }
    
    private func isValidExpiryDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // Date should be between yesterday and 5 years from now
        let minDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let maxDate = calendar.date(byAdding: .year, value: 5, to: now) ?? now
        
        return date >= minDate && date <= maxDate
    }
    
    // MARK: - Meal Planner Integration
    
    func createRecipeFromFridgeItem(_ item: FridgeItem) {
        guard let itemName = item.name else { return }
        
        // Create a simple recipe using the fridge item
        let recipeTitle = "Recipe with \(itemName)"
        let ingredients = [itemName]
        let instructions = ["Use \(itemName) in your favorite recipe"]
        let tags = [item.category ?? "Fridge Item"]
        
        // Use RecipeManager to save the recipe
        RecipeManager.shared.saveRecipe(
            title: recipeTitle,
            ingredients: ingredients,
            instructions: instructions,
            tags: tags,
            imageData: item.imageData
        )
    }
    
    func addFridgeItemToMealPlan(_ item: FridgeItem, date: Date) {
        guard let itemName = item.name else { return }
        
        // First create a recipe from the fridge item
        let recipeTitle = "Use \(itemName)"
        let ingredients = [itemName]
        let instructions = ["Cook with \(itemName) before it expires on \(formatDate(item.expiryDate))"]
        let tags = [item.category ?? "Fridge Item", "Quick Use"]
        
        // Save the recipe
        RecipeManager.shared.saveRecipe(
            title: recipeTitle,
            ingredients: ingredients,
            instructions: instructions,
            tags: tags,
            imageData: item.imageData
        )
        
        // Get the newly created recipe
        let recipes = RecipeManager.shared.recipes
        if let newRecipe = recipes.first(where: { $0.title == recipeTitle }) {
            // Add it to the meal plan for the specified date
            RecipeManager.shared.saveMealPlan(recipe: newRecipe, date: date)
        }
    }
    
    func addFridgeItemToWeeklyPlan(_ item: FridgeItem, day: String) {
        guard let itemName = item.name else { return }
        
        // Create a recipe from the fridge item
        let recipeTitle = "Use \(itemName)"
        let ingredients = [itemName]
        let instructions = ["Cook with \(itemName) before it expires on \(formatDate(item.expiryDate))"]
        let tags = [item.category ?? "Fridge Item", "Quick Use"]
        
        // Save the recipe
        RecipeManager.shared.saveRecipe(
            title: recipeTitle,
            ingredients: ingredients,
            instructions: instructions,
            tags: tags,
            imageData: item.imageData
        )
        
        // Get the newly created recipe
        let recipes = RecipeManager.shared.recipes
        if let newRecipe = recipes.first(where: { $0.title == recipeTitle }) {
            // Add it to the weekly plan for the specified day
            RecipeManager.shared.addRecipeToDay(newRecipe, day: day)
        }
    }
    
    func suggestRecipesForExpiringItems() -> [(item: FridgeItem, suggestedDay: String)] {
        let expiringItems = fridgeItems.filter { $0.isExpiringSoon && !$0.isExpired }
        var suggestions: [(item: FridgeItem, suggestedDay: String)] = []
        
        let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        
        for (index, item) in expiringItems.enumerated() {
            // Suggest using items in the next few days
            let suggestedDayIndex = min(index % dayNames.count, dayNames.count - 1)
            suggestions.append((item: item, suggestedDay: dayNames[suggestedDayIndex]))
        }
        
        return suggestions
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "unknown date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    // Common categories for fridge items
    static let categories = [
        "Dairy", "Meat", "Vegetables", "Fruits", "Leftovers", 
        "Condiments", "Beverages", "Frozen", "Other"
    ]
}