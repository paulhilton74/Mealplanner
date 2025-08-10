import Foundation
import CoreData

class RecipeModelMigration {
    static func migrateIfNeeded(context: NSManagedObjectContext) {
        // Check if we need to add the dateAdded attribute
        let fetchRequest = NSFetchRequest<RecipeEntity>(entityName: "RecipeEntity")
        fetchRequest.fetchLimit = 1
        
        do {
            let recipes = try context.fetch(fetchRequest)
            if let recipe = recipes.first, recipe.dateAdded == nil {
                addDateAddedToAllRecipes(context: context)
            }
        } catch {
            print("Error checking for migration: \(error)")
        }
    }
    
    private static func addDateAddedToAllRecipes(context: NSManagedObjectContext) {
        let fetchRequest = NSFetchRequest<RecipeEntity>(entityName: "RecipeEntity")
        
        do {
            let recipes = try context.fetch(fetchRequest)
            for recipe in recipes {
                if recipe.dateAdded == nil {
                    recipe.dateAdded = Date()
                }
            }
            
            try context.save()
            print("Migration complete: Added dateAdded to \(recipes.count) recipes")
        } catch {
            print("Error during migration: \(error)")
        }
    }
} 