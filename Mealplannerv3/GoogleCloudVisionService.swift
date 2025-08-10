import Foundation
import UIKit

// MARK: - Response Models
struct GoogleCloudVisionResponse: Decodable {
    let responses: [AnnotateImageResponse]?
    let error: ErrorInfo?
}

struct AnnotateImageResponse: Decodable {
    let textAnnotations: [TextAnnotation]?
    let error: ErrorInfo?
}

struct TextAnnotation: Decodable {
    let description: String
}

struct ErrorInfo: Decodable {
    let code: Int?
    let message: String?
    let status: String?
    let details: [ErrorDetail]?
}

struct ErrorDetail: Decodable {
    let type: String?
    let reason: String?
    let domain: String?
    let metadata: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case reason
        case domain
        case metadata
    }
}

// MARK: - Request Models
struct GoogleCloudVisionRequest: Encodable {
    let requests: [AnnotateImageRequest]
}

struct AnnotateImageRequest: Encodable {
    let image: ImageContent
    let features: [Feature]
}

struct ImageContent: Encodable {
    let content: String
}

struct Feature: Encodable {
    let type: String
    let maxResults: Int
}

enum VisionAPIError: Error {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case decodingError
    case networkError(Error)
    case noTextFound
}

// MARK: - Google Cloud Vision Service
class GoogleCloudVisionService {
    private let apiKey: String
    private let apiURL: URL
    private var lastExtractedRawText: String = ""
    
    init() {
        print("Initializing GoogleCloudVisionService with endpoint: \(Config.googleCloudVisionEndpoint)")
        self.apiKey = Config.googleCloudVisionAPIKey
        self.apiURL = URL(string: "\(Config.googleCloudVisionEndpoint)?key=\(apiKey)")!
        print("API URL: \(self.apiURL.absoluteString)")
    }
    
    // Get the last raw text extracted from an image
    func getLastExtractedRawText() -> String {
        return lastExtractedRawText
    }
    
    // Test function to check if the API is properly configured
    func testAPIConnection() async -> (success: Bool, message: String) {
        // Create a minimal 1x1 transparent PNG image in base64
        let minimalImageBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
        
        // Create a minimal request
        let requestBody = GoogleCloudVisionRequest(
            requests: [
                AnnotateImageRequest(
                    image: ImageContent(content: minimalImageBase64),
                    features: [Feature(type: "TEXT_DETECTION", maxResults: 1)]
                )
            ]
        )
        
        do {
            // Encode request to JSON
            let jsonData = try JSONEncoder().encode(requestBody)
            
            // Create URL request
            var request = URLRequest(url: apiURL)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            print("Sending test request to Google Cloud Vision API...")
            
            // Send request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check response status
            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, "Invalid response type")
            }
            
            print("Received test response with status code: \(httpResponse.statusCode)")
            
            // Check for successful status code
            if (200...299).contains(httpResponse.statusCode) {
                return (true, "API connection successful! The Google Cloud Vision API is properly configured.")
            } else {
                // Try to decode the error response
                do {
                    let errorResponse = try JSONDecoder().decode(GoogleCloudVisionResponse.self, from: data)
                    if let errorInfo = errorResponse.error {
                        let errorMessage = errorInfo.message ?? "Unknown error"
                        
                        if let details = errorInfo.details, let reason = details.first?.reason {
                            if reason == "SERVICE_DISABLED" {
                                return (false, "The Google Cloud Vision API is not enabled for this project. Please enable it in the Google Cloud Console and ensure billing is enabled for your project.")
                            } else if reason.contains("BILLING") {
                                return (false, "Billing is not enabled for the Google Cloud project. Please enable billing in the Google Cloud Console.")
                            }
                        }
                        
                        return (false, "API Error: \(errorMessage)")
                    }
                } catch {
                    let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                    return (false, "Failed to decode error response: \(responseString)")
                }
                
                return (false, "HTTP Error: \(httpResponse.statusCode)")
            }
        } catch {
            return (false, "Network error: \(error.localizedDescription)")
        }
    }
    
    func extractRecipeFromImage(_ imageData: Data) async throws -> (title: String, ingredients: [String], instructions: [String]) {
        // Convert image data to base64 string
        let base64String = imageData.base64EncodedString()
        print("Image data converted to base64 string with length: \(base64String.count)")
        
        // Create request body
        let requestBody = GoogleCloudVisionRequest(
            requests: [
                AnnotateImageRequest(
                    image: ImageContent(content: base64String),
                    features: [Feature(type: "TEXT_DETECTION", maxResults: 10)]
                )
            ]
        )
        
        // Encode request to JSON
        let jsonData = try JSONEncoder().encode(requestBody)
        print("Request JSON size: \(jsonData.count) bytes")
        
        // Create URL request
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        print("Sending request to Google Cloud Vision API...")
        
        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response status
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Invalid response type")
            throw VisionAPIError.invalidResponse
        }
        
        print("Received response with status code: \(httpResponse.statusCode)")
        
        // Check for successful status code
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to decode the error response
            do {
                let errorResponse = try JSONDecoder().decode(GoogleCloudVisionResponse.self, from: data)
                if let errorInfo = errorResponse.error {
                    let errorMessage = "API Error: \(errorInfo.message ?? "Unknown error")"
                    print(errorMessage)
                    throw VisionAPIError.apiError(errorMessage)
                }
            } catch {
                print("Failed to decode error response: \(error)")
                print("Raw error response: \(String(data: data, encoding: .utf8) ?? "Unable to convert data to string")")
            }
            
            throw VisionAPIError.apiError("HTTP Error: \(httpResponse.statusCode)")
        }
        
        // Decode response
        do {
            let visionResponse = try JSONDecoder().decode(GoogleCloudVisionResponse.self, from: data)
            
            // Check for API errors
            if let error = visionResponse.error {
                let errorMessage = "API Error: \(error.message ?? "Unknown error")"
                print(errorMessage)
                throw VisionAPIError.apiError(errorMessage)
            }
            
            // Extract text from response
            guard let responses = visionResponse.responses,
                  let firstResponse = responses.first,
                  let textAnnotations = firstResponse.textAnnotations,
                  let firstAnnotation = textAnnotations.first,
                  !firstAnnotation.description.isEmpty else {
                print("No text found in the image")
                throw VisionAPIError.noTextFound
            }
            
            let extractedText = firstAnnotation.description
            print("Successfully extracted text with length: \(extractedText.count) characters")
            
            // Save the raw text for debugging
            self.lastExtractedRawText = extractedText
            
            // Process the extracted text to identify recipe components
            return processExtractedText(extractedText)
        } catch {
            print("Error decoding response: \(error)")
            throw VisionAPIError.decodingError
        }
    }
    
    private func processExtractedText(_ text: String) -> (title: String, ingredients: [String], instructions: [String]) {
        var title = ""
        var ingredients: [String] = []
        var instructions: [String] = []
        
        // Print the raw text for debugging
        print("Raw extracted text:\n\(text)")
        
        // Split text into lines
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Look for recipe title patterns
        // Magazine recipes often have distinctive title patterns
        for (index, line) in lines.enumerated() {
            let lowercaseLine = line.lowercased()
            
            // Look for common recipe title indicators
            if lowercaseLine.contains("recipe") || 
               lowercaseLine.contains("cake") || 
               lowercaseLine.contains("pie") || 
               lowercaseLine.contains("soup") || 
               lowercaseLine.contains("salad") || 
               lowercaseLine.contains("curry") || 
               lowercaseLine.contains("stew") || 
               lowercaseLine.contains("roast") {
                
                // If it's a short line (likely a title) or contains "recipe for"
                if line.count < 50 || lowercaseLine.contains("recipe for") {
                    title = line
                    break
                }
            }
        }
        
        // If we didn't find a title with food keywords, use the first non-header line
        if title.isEmpty {
            for line in lines {
                let lowercaseLine = line.lowercased()
                if !lowercaseLine.contains("ingredient") && 
                   !lowercaseLine.contains("instruction") && 
                   !lowercaseLine.contains("direction") && 
                   !lowercaseLine.contains("method") && 
                   !lowercaseLine.contains("preparation") && 
                   line.count < 50 {  // Titles are usually short
                    title = line
                    break
                }
            }
        }
        
        // Find section headers - expanded to catch more variations
        var ingredientSectionIndex: Int? = nil
        var instructionSectionIndex: Int? = nil
        var servesIndex: Int? = nil
        
        for (index, line) in lines.enumerated() {
            let lowercaseLine = line.lowercased()
            
            // Look for ingredient section headers - expanded patterns
            if lowercaseLine.contains("ingredient") || 
               lowercaseLine.contains("you'll need") || 
               lowercaseLine.contains("you need") || 
               lowercaseLine.contains("shopping list") || 
               lowercaseLine.contains("what you need") || 
               lowercaseLine.contains("for the") || 
               (lowercaseLine.contains("serves") && lowercaseLine.count < 20) {
                
                if lowercaseLine.contains("serves") && servesIndex == nil {
                    servesIndex = index
                } else {
                    ingredientSectionIndex = index
                }
            }
            
            // Look for instruction section headers - expanded patterns
            if lowercaseLine.contains("instruction") || 
               lowercaseLine.contains("direction") || 
               lowercaseLine.contains("method") || 
               lowercaseLine.contains("preparation") || 
               lowercaseLine.contains("steps") || 
               lowercaseLine.contains("how to") || 
               lowercaseLine.contains("to make") || 
               lowercaseLine.contains("procedure") {
                instructionSectionIndex = index
            }
        }
        
        // Process based on identified sections
        if let ingredientIndex = ingredientSectionIndex, let instructionIndex = instructionSectionIndex {
            // We found both sections
            let startIngredients = ingredientIndex + 1
            let endIngredients = instructionIndex
            let startInstructions = instructionIndex + 1
            
            if startIngredients < endIngredients {
                ingredients = Array(lines[startIngredients..<endIngredients])
            }
            
            if startInstructions < lines.count {
                instructions = Array(lines[startInstructions..<lines.count])
            }
        } else if let ingredientIndex = ingredientSectionIndex {
            // Only found ingredients section
            let startIngredients = ingredientIndex + 1
            
            // Try to find where instructions might start
            var possibleInstructionStart = lines.count
            
            // Look for patterns that might indicate the start of instructions
            for i in startIngredients..<lines.count {
                let line = lines[i]
                
                // Check for numbered steps
                if line.range(of: #"^\s*\d+[\.\)]"#, options: .regularExpression) != nil {
                    possibleInstructionStart = i
                    break
                }
                
                // Check for step keywords
                let lowercaseLine = line.lowercased()
                if lowercaseLine.contains("step") || 
                   lowercaseLine.contains("first") || 
                   lowercaseLine.contains("begin by") || 
                   lowercaseLine.contains("start by") || 
                   lowercaseLine.contains("preheat") || 
                   lowercaseLine.contains("heat") || 
                   lowercaseLine.contains("mix") {
                    possibleInstructionStart = i
                    break
                }
            }
            
            if startIngredients < possibleInstructionStart {
                ingredients = Array(lines[startIngredients..<possibleInstructionStart])
            }
            
            if possibleInstructionStart < lines.count {
                instructions = Array(lines[possibleInstructionStart..<lines.count])
            }
        } else if let instructionIndex = instructionSectionIndex {
            // Only found instructions section
            let startInstructions = instructionIndex + 1
            
            // Assume everything before instructions (except title) is ingredients
            if title.isEmpty {
                ingredients = Array(lines[0..<instructionIndex])
            } else {
                // Find where ingredients might start
                var ingredientStartIndex = 0
                for (index, line) in lines.enumerated() {
                    if line == title {
                        ingredientStartIndex = index + 1
                        break
                    }
                }
                
                if ingredientStartIndex < instructionIndex {
                    ingredients = Array(lines[ingredientStartIndex..<instructionIndex])
                }
            }
            
            if startInstructions < lines.count {
                instructions = Array(lines[startInstructions..<lines.count])
            }
        } else {
            // No clear sections found, use enhanced heuristics
            
            // Skip title if we have one
            var startIndex = 0
            if !title.isEmpty {
                for (index, line) in lines.enumerated() {
                    if line == title {
                        startIndex = index + 1
                        break
                    }
                }
            }
            
            // Look for patterns in the text
            var instructionStartIndex = startIndex
            
            // Try to identify ingredients by common patterns
            var identifiedIngredients: [String] = []
            var identifiedInstructions: [String] = []
            
            // Magazine recipes often have numbered steps for instructions
            var foundNumberedStep = false
            
            for i in startIndex..<lines.count {
                let line = lines[i]
                let lowercaseLine = line.lowercased()
                
                // Check if line looks like an ingredient
                let hasQuantity = line.range(of: #"\d+\s*([a-zA-Z]+|\s*\/\s*\d+)"#, options: .regularExpression) != nil
                let hasMeasurement = lowercaseLine.contains("cup") || 
                                    lowercaseLine.contains("tbsp") || 
                                    lowercaseLine.contains("tsp") || 
                                    lowercaseLine.contains("tablespoon") || 
                                    lowercaseLine.contains("teaspoon") || 
                                    lowercaseLine.contains("ounce") || 
                                    lowercaseLine.contains("oz") || 
                                    lowercaseLine.contains("pound") || 
                                    lowercaseLine.contains("lb") || 
                                    lowercaseLine.contains("gram") || 
                                    lowercaseLine.contains("g ") || 
                                    lowercaseLine.contains("ml") || 
                                    lowercaseLine.contains("liter") || 
                                    lowercaseLine.contains("kg") || 
                                    lowercaseLine.contains("pinch") || 
                                    lowercaseLine.contains("dash") || 
                                    lowercaseLine.contains("handful")
                
                // Common ingredient indicators
                let hasCommonIngredient = lowercaseLine.contains("salt") || 
                                         lowercaseLine.contains("pepper") || 
                                         lowercaseLine.contains("oil") || 
                                         lowercaseLine.contains("butter") || 
                                         lowercaseLine.contains("sugar") || 
                                         lowercaseLine.contains("flour") || 
                                         lowercaseLine.contains("egg") || 
                                         lowercaseLine.contains("milk") || 
                                         lowercaseLine.contains("water") || 
                                         lowercaseLine.contains("cheese") || 
                                         lowercaseLine.contains("garlic") || 
                                         lowercaseLine.contains("onion")
                
                // Check if line looks like an instruction
                let isNumberedStep = line.range(of: #"^\s*\d+[\.\)]"#, options: .regularExpression) != nil
                let hasInstructionVerb = lowercaseLine.contains("mix") || 
                                        lowercaseLine.contains("stir") || 
                                        lowercaseLine.contains("cook") || 
                                        lowercaseLine.contains("bake") || 
                                        lowercaseLine.contains("preheat") || 
                                        lowercaseLine.contains("heat") || 
                                        lowercaseLine.contains("add") || 
                                        lowercaseLine.contains("combine") || 
                                        lowercaseLine.contains("place") || 
                                        lowercaseLine.contains("pour") || 
                                        lowercaseLine.contains("simmer") || 
                                        lowercaseLine.contains("boil") || 
                                        lowercaseLine.contains("fry") || 
                                        lowercaseLine.contains("grill") || 
                                        lowercaseLine.contains("roast") || 
                                        lowercaseLine.contains("serve")
                
                if isNumberedStep {
                    foundNumberedStep = true
                }
                
                if (hasQuantity || hasMeasurement || hasCommonIngredient) && !foundNumberedStep {
                    identifiedIngredients.append(line)
                } else if isNumberedStep || hasInstructionVerb {
                    identifiedInstructions.append(line)
                    // Once we start finding instructions, remaining lines are likely instructions
                    if instructionStartIndex == startIndex {
                        instructionStartIndex = i
                    }
                } else if foundNumberedStep {
                    // If we've already found a numbered step, assume subsequent lines are instructions
                    identifiedInstructions.append(line)
                } else {
                    // If we can't clearly identify, assume it's an ingredient until we find instructions
                    identifiedIngredients.append(line)
                }
            }
            
            // If we found a clear instruction start point
            if instructionStartIndex > startIndex {
                ingredients = Array(lines[startIndex..<instructionStartIndex])
                instructions = Array(lines[instructionStartIndex..<lines.count])
            } else if !identifiedIngredients.isEmpty || !identifiedInstructions.isEmpty {
                // Use our identified lists
                ingredients = identifiedIngredients
                instructions = identifiedInstructions
            } else {
                // Last resort: split the content
                let midPoint = (lines.count - startIndex) / 2 + startIndex
                ingredients = Array(lines[startIndex..<midPoint])
                instructions = Array(lines[midPoint..<lines.count])
            }
        }
        
        // Clean up ingredients
        ingredients = ingredients.map { line -> String in
            // Remove bullet points and other common markers
            var cleaned = line
            cleaned = cleaned.replacingOccurrences(of: #"^\s*[\•\-\*\–\—\⁃\◦\‣\⦿\⁌\⁍]\s*"#, with: "", options: .regularExpression)
            return cleaned
        }
        
        // Clean up instructions
        instructions = instructions.map { line -> String in
            // Remove step numbers
            var cleaned = line
            cleaned = cleaned.replacingOccurrences(of: #"^\s*\d+[\.\)]\s*"#, with: "", options: .regularExpression)
            return cleaned
        }
        
        // Filter out any lines that might be section headers
        ingredients = ingredients.filter { line in
            let lowercaseLine = line.lowercased()
            return !lowercaseLine.contains("ingredient") && 
                   !lowercaseLine.contains("instruction") && 
                   !lowercaseLine.contains("direction") && 
                   !lowercaseLine.contains("method") && 
                   !lowercaseLine.contains("preparation") && 
                   !lowercaseLine.contains("serves")
        }
        
        instructions = instructions.filter { line in
            let lowercaseLine = line.lowercased()
            return !lowercaseLine.contains("ingredient") && 
                   !lowercaseLine.contains("instruction") && 
                   !lowercaseLine.contains("direction") && 
                   !lowercaseLine.contains("method") && 
                   !lowercaseLine.contains("preparation")
        }
        
        // If we have a very short title or no title, try to find a better one
        if title.count < 3 || title.isEmpty {
            // Look for the recipe name in the first few lines
            for i in 0..<min(5, lines.count) {
                let line = lines[i]
                if line.count > 3 && line.count < 50 && !line.lowercased().contains("ingredient") {
                    title = line
                    break
                }
            }
            
            // If still no title, use a default
            if title.isEmpty {
                title = "Recipe from Image"
            }
        }
        
        // Print what we found for debugging
        print("Extracted title: \(title)")
        print("Extracted \(ingredients.count) ingredients")
        print("Extracted \(instructions.count) instructions")
        
        return (title: title, ingredients: ingredients, instructions: instructions)
    }
} 