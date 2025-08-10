import Foundation
import CoreData

// MARK: - ShoppingList Extensions
extension ShoppingList {
    var itemsArray: [ShoppingItem] {
        let set = items as? Set<ShoppingItem> ?? []
        return Array(set)
    }
}

// MARK: - Convenience Initializers
extension ShoppingList {
    static func createNew(name: String, in context: NSManagedObjectContext) -> ShoppingList {
        let list = ShoppingList(context: context)
        list.id = UUID()
        list.name = name
        list.createdAt = Date()
        return list
    }
}

extension ShoppingItem {
    static func createNew(name: String, quantity: Int, category: String, in list: ShoppingList, context: NSManagedObjectContext) -> ShoppingItem {
        let item = ShoppingItem(context: context)
        item.id = UUID()
        item.name = name
        item.quantity = Int32(quantity)  // Changed from Int16 to Int32
        item.category = category.lowercased()
        item.isChecked = false
        item.list = list
        return item
    }
}