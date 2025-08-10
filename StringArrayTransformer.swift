import Foundation

@objc(StringArrayTransformer)
class StringArrayTransformer: ValueTransformer {

    // Indicate that the transformed value is an instance of Data.
    override class func transformedValueClass() -> AnyClass {
        return NSData.self
    }
    
    // Allow reverse transformation.
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    // Convert [String] to Data.
    override func transformedValue(_ value: Any?) -> Any? {
        guard let stringArray = value as? [String] else { return nil }
        do {
            let data = try JSONEncoder().encode(stringArray)
            return data
        } catch {
            print("Error encoding string array: \(error)")
            return nil
        }
    }
    
    // Convert Data back to [String].
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        do {
            let stringArray = try JSONDecoder().decode([String].self, from: data)
            return stringArray
        } catch {
            print("Error decoding string array: \(error)")
            return nil
        }
    }
}