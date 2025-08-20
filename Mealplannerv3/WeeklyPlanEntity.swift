import Foundation
import CoreData

@objc(WeeklyPlanEntity)
public class WeeklyPlanEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var dayOfWeek: String?
    @NSManaged public var recipe: RecipeEntity?
    @NSManaged public var mealType: String?
}

extension WeeklyPlanEntity {
    static func fetchRequest() -> NSFetchRequest<WeeklyPlanEntity> {
        return NSFetchRequest<WeeklyPlanEntity>(entityName: "WeeklyPlanEntity")
    }
}
