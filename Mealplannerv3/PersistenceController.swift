import CoreData

class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init() {
        container = NSPersistentContainer(name: "RecipeModel")
        
        // Register the StringArrayTransformer
        ValueTransformer.setValueTransformer(
            StringArrayTransformer(),
            forName: NSValueTransformerName("StringArrayTransformer")
        )
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Error loading Core Data stores: \(error)")
            }
            
            // Enable automatic merging of changes from parent contexts
            self.container.viewContext.automaticallyMergesChangesFromParent = true
            
            // Add dateAdded to existing recipes if needed
            self.addDateAddedToExistingRecipes()
        }
    }
    
    private func addDateAddedToExistingRecipes() {
        let context = container.viewContext
        let fetchRequest = NSFetchRequest<RecipeEntity>(entityName: "RecipeEntity")
        fetchRequest.predicate = NSPredicate(format: "dateAdded == nil")
        
        do {
            let recipes = try context.fetch(fetchRequest)
            for recipe in recipes {
                recipe.dateAdded = Date()
            }
            
            if !recipes.isEmpty {
                try context.save()
                print("Added dateAdded to \(recipes.count) existing recipes")
            }
        } catch {
            print("Error adding dateAdded to existing recipes: \(error)")
        }
    }
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }
}
