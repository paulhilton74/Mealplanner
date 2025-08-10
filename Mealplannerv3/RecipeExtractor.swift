import Foundation

enum RecipeParsingError: Error {
    case noData
    case invalidJSON
    case invalidFormat
    case missingRequiredData
}

protocol RecipeExtractor {
    func parse(html: String, from url: URL) async -> (title: String, ingredients: [String], instructions: [String], images: [String])?
}

struct JSONLDExtractor: RecipeExtractor {
    func parse(html: String, from url: URL) async -> (title: String, ingredients: [String], instructions: [String], images: [String])? {
        let pattern = "<script[^>]*type=\"application/ld\\+json\"[^>]*>\\s*(.+?)\\s*</script>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let dataRange = Range(match.range(at: 1), in: html) else {
            return nil
        }

        let jsonString = String(html[dataRange])
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }

            // Find recipe data
            let recipeData: [String: Any]
            if let type = json["@type"] as? String, type == "Recipe" {
                recipeData = json
            } else if let graph = json["@graph"] as? [[String: Any]],
                      let recipe = graph.first(where: { ($0["@type"] as? String) == "Recipe" }) {
                recipeData = recipe
            } else {
                return nil
            }

            // Extract title
            guard let title = recipeData["name"] as? String else {
                return nil
            }

            // Extract ingredients
            var ingredients: [String] = []
            if let ingredientList = recipeData["recipeIngredient"] as? [String] {
                ingredients = ingredientList
            } else if let ingredientList = recipeData["ingredients"] as? [String] {
                ingredients = ingredientList
            } else if let ingredientString = recipeData["recipeIngredient"] as? String {
                ingredients = ingredientString.components(separatedBy: "\n")
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            }

            // Extract instructions
            var instructions: [String] = []
            
            // Handle array of strings
            if let steps = recipeData["recipeInstructions"] as? [String] {
                instructions = steps
            } 
            // Handle array of objects with text property
            else if let steps = recipeData["recipeInstructions"] as? [[String: Any]] {
                instructions = steps.compactMap { step -> String? in
                    // Check for HowToStep type with text property
                    if let text = step["text"] as? String {
                        return text
                    }
                    // Check for itemListElement that might contain steps
                    else if let itemListElement = step["itemListElement"] as? [[String: Any]] {
                        return itemListElement.compactMap { $0["text"] as? String }.joined(separator: " ")
                    }
                    // Check for step property
                    else if let stepText = step["step"] as? String {
                        return stepText
                    }
                    return nil
                }
            } 
            // Handle single object with itemListElement
            else if let instructionObject = recipeData["recipeInstructions"] as? [String: Any],
                    let itemListElement = instructionObject["itemListElement"] as? [[String: Any]] {
                instructions = itemListElement.compactMap { $0["text"] as? String }
            }
            // Handle string with newlines
            else if let instructionsString = recipeData["recipeInstructions"] as? String {
                instructions = instructionsString.components(separatedBy: "\n")
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            }
            
            // If we still don't have instructions, try looking for "instructions" property
            if instructions.isEmpty, let instructionsData = recipeData["instructions"] {
                if let instructionsList = instructionsData as? [String] {
                    instructions = instructionsList
                } else if let instructionsString = instructionsData as? String {
                    instructions = instructionsString.components(separatedBy: "\n")
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                }
            }

            // Extract images
            var images: [String] = []
            if let image = recipeData["image"] as? String {
                images = [image]
            } else if let imageList = recipeData["image"] as? [String] {
                images = imageList
            } else if let imageObject = recipeData["image"] as? [String: Any], let url = imageObject["url"] as? String {
                images = [url]
            }

            return (title, ingredients, instructions, images)
    }
}

struct MicrodataExtractor: RecipeExtractor {
    func parse(html: String, from url: URL) async -> (title: String, ingredients: [String], instructions: [String], images: [String])? {
        // Extract title
        var title = ""
        let titlePatterns = [
            "<h1[^>]*>([^<]+)</h1>",
            "<meta\\s+property=\"og:title\"\\s+content=\"([^\"]+)\"",
            "<title>([^<]+)</title>"
        ]
        for pattern in titlePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let titleRange = Range(match.range(at: 1), in: html) {
                title = String(html[titleRange])
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&#x27;", with: "'")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        // Extract ingredients
        var ingredients: [String] = []
        let ingredientPatterns = [
            "<li[^>]*class=\"[^\"]*ingredient[^\"]*\"[^>]*>(.*?)</li>",
            "<li[^>]*itemprop=\"recipeIngredient\"[^>]*>(.*?)</li>",
            "<div[^>]*class=\"[^\"]*ingredient[^\"]*\"[^>]*>(.*?)</div>"
        ]
        for pattern in ingredientPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                ingredients = matches.compactMap { match -> String? in
                    guard let range = Range(match.range(at: 1), in: html) else { return nil }
                    return String(html[range])
                        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if !ingredients.isEmpty { break }
            }
        }

        // Extract instructions
        var instructions: [String] = []
        let instructionPatterns = [
            // Original patterns
            "<li[^>]*class=\"[^\"]*instruction[^\"]*\"[^>]*>(.*?)</li>",
            "<div[^>]*class=\"[^\"]*step[^\"]*\"[^>]*>(.*?)</div>",
            "<p[^>]*class=\"[^\"]*instruction[^\"]*\"[^>]*>(.*?)</p>",
            
            // Additional patterns for common recipe sites
            "<li[^>]*class=\"[^\"]*direction[^\"]*\"[^>]*>(.*?)</li>",
            "<li[^>]*class=\"[^\"]*prep-step[^\"]*\"[^>]*>(.*?)</li>",
            "<li[^>]*class=\"[^\"]*recipe-direction[^\"]*\"[^>]*>(.*?)</li>",
            "<li[^>]*class=\"[^\"]*recipe-instruction[^\"]*\"[^>]*>(.*?)</li>",
            "<li[^>]*class=\"[^\"]*method-step[^\"]*\"[^>]*>(.*?)</li>",
            "<li[^>]*class=\"[^\"]*recipeStep[^\"]*\"[^>]*>(.*?)</li>",
            "<li[^>]*class=\"[^\"]*recipe__method-step[^\"]*\"[^>]*>(.*?)</li>",
            "<li[^>]*class=\"[^\"]*recipe-method-step[^\"]*\"[^>]*>(.*?)</li>",
            "<li[^>]*class=\"[^\"]*preparation-step[^\"]*\"[^>]*>(.*?)</li>",
            
            // Generic patterns for ordered lists that might contain instructions
            "<ol[^>]*>\\s*(<li[^>]*>.*?</li>)\\s*</ol>",
            
            // Try to find any ordered list after a heading that contains "instructions", "directions", "method", etc.
            "(?i)<h[1-6][^>]*>.*?(instructions|directions|method|steps|preparation).*?</h[1-6]>\\s*<ol[^>]*>(.*?)</ol>",
            
            // Try to find any div with "instructions" or "directions" in the class name
            "<div[^>]*class=\"[^\"]*(?:instructions|directions|method|steps|preparation)[^\"]*\"[^>]*>(.*?)</div>"
        ]
        
        // First try to extract instructions as a list
        for pattern in instructionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                let foundInstructions = matches.compactMap { match -> String? in
                    guard let range = Range(match.range(at: 1), in: html) else { return nil }
                    return String(html[range])
                        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if !foundInstructions.isEmpty {
                    instructions = foundInstructions
                    break
                }
            }
        }
        
        // If we still don't have instructions, try to find a section with "instructions" in the heading
        if instructions.isEmpty {
            let sectionPattern = "(?i)<h[1-6][^>]*>.*?(instructions|directions|method|steps|preparation).*?</h[1-6]>\\s*(.*?)(?:<h[1-6]|<div[^>]*class=\"[^\"]*section)"
            if let regex = try? NSRegularExpression(pattern: sectionPattern, options: [.dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let sectionRange = Range(match.range(at: 2), in: html) {
                
                let sectionHtml = String(html[sectionRange])
                // Extract paragraphs or list items from this section
                let stepPattern = "<(?:p|li)[^>]*>(.*?)</(?:p|li)>"
                if let stepRegex = try? NSRegularExpression(pattern: stepPattern, options: [.dotMatchesLineSeparators]) {
                    let stepMatches = stepRegex.matches(in: sectionHtml, range: NSRange(sectionHtml.startIndex..., in: sectionHtml))
                    instructions = stepMatches.compactMap { match -> String? in
                        guard let range = Range(match.range(at: 1), in: sectionHtml) else { return nil }
                        let step = String(sectionHtml[range])
                            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        return step.isEmpty ? nil : step
                    }
                }
            }
        }

        // Extract images
        var images: [String] = []
        let imagePatterns = [
            "<meta\\s+property=\"og:image\"\\s+content=\"([^\"]+)\"",
            "<img[^>]+class=\"[^\"]*recipe-image[^\"]*\"[^>]+src=\"([^\"]+)\""
        ]
        for pattern in imagePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                images = matches.compactMap { match -> String? in
                    guard let range = Range(match.range(at: 1), in: html) else { return nil }
                    return String(html[range])
                }
                if !images.isEmpty { break }
            }
        }

        return (!title.isEmpty && (!ingredients.isEmpty || !instructions.isEmpty)) ?
            (title, ingredients, instructions, images) : nil
    }
}