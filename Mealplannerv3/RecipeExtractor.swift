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
    
    // Helper function to clean instruction text
    private func cleanInstructionText(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) // Remove HTML tags
            .replacingOccurrences(of: "&nbsp;", with: " ") // Replace HTML entities
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "\\n", with: " ") // Replace literal \n with space
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression) // Multiple spaces to single
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
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

            // Extract instructions with enhanced handling
            var instructions: [String] = []
            
            // Handle array of strings
            if let steps = recipeData["recipeInstructions"] as? [String] {
                instructions = steps.map { cleanInstructionText($0) }.filter { !$0.isEmpty }
            } 
            // Handle array of objects with text property
            else if let steps = recipeData["recipeInstructions"] as? [[String: Any]] {
                instructions = steps.compactMap { step -> String? in
                    // Check for HowToStep type with text property
                    if let text = step["text"] as? String {
                        let cleanText = cleanInstructionText(text)
                        // Skip if it's just a section header (short text without periods)
                        if cleanText.count > 15 || cleanText.contains(".") || cleanText.contains(",") {
                            return cleanText
                        }
                    }
                    // Check for name property (common in HowToStep)
                    else if let name = step["name"] as? String {
                        let cleanName = cleanInstructionText(name)
                        // Skip if it's just a section header
                        if cleanName.count > 15 || cleanName.contains(".") || cleanName.contains(",") {
                            return cleanName
                        }
                    }
                    // Check for itemListElement that might contain steps
                    else if let itemListElement = step["itemListElement"] as? [[String: Any]] {
                        let stepTexts = itemListElement.compactMap { $0["text"] as? String }
                        return stepTexts.isEmpty ? nil : cleanInstructionText(stepTexts.joined(separator: " "))
                    }
                    // Check for step property
                    else if let stepText = step["step"] as? String {
                        return cleanInstructionText(stepText)
                    }
                    // Check for description property
                    else if let description = step["description"] as? String {
                        return cleanInstructionText(description)
                    }
                    return nil
                }.filter { !$0.isEmpty }
            } 
            // Handle single object with itemListElement
            else if let instructionObject = recipeData["recipeInstructions"] as? [String: Any],
                    let itemListElement = instructionObject["itemListElement"] as? [[String: Any]] {
                instructions = itemListElement.compactMap { 
                    if let text = $0["text"] as? String {
                        return cleanInstructionText(text)
                    }
                    return nil
                }.filter { !$0.isEmpty }
            }
            // Handle string with newlines
            else if let instructionsString = recipeData["recipeInstructions"] as? String {
                instructions = instructionsString.components(separatedBy: "\n")
                    .map { cleanInstructionText($0) }
                    .filter { !$0.isEmpty }
            }
            
            // If we still don't have good instructions, try multiple fallback strategies
            if instructions.isEmpty || instructions.allSatisfy({ $0.count < 20 && !$0.contains(".") }) {
                // Strategy 1: Look for method/recipeMethod property
                if let methodData = recipeData["method"] ?? recipeData["recipeMethod"] {
                    if let methodArray = methodData as? [[String: Any]] {
                        let methodInstructions = methodArray.compactMap { methodStep -> String? in
                            if let text = methodStep["text"] as? String {
                                return cleanInstructionText(text)
                            } else if let description = methodStep["description"] as? String {
                                return cleanInstructionText(description)
                            }
                            return nil
                        }.filter { !$0.isEmpty && $0.count > 10 }
                        
                        if !methodInstructions.isEmpty {
                            instructions = methodInstructions
                        }
                    } else if let methodString = methodData as? String {
                        let methodInstructions = methodString.components(separatedBy: "\n")
                            .map { cleanInstructionText($0) }
                            .filter { !$0.isEmpty && $0.count > 10 }
                        if !methodInstructions.isEmpty {
                            instructions = methodInstructions
                        }
                    }
                }
                
                // Strategy 2: Look for "instructions" property with different structure
                if instructions.isEmpty || instructions.allSatisfy({ $0.count < 20 }), 
                   let instructionsData = recipeData["instructions"] {
                    if let instructionsList = instructionsData as? [String] {
                        instructions = instructionsList.map { cleanInstructionText($0) }.filter { !$0.isEmpty && $0.count > 10 }
                    } else if let instructionsString = instructionsData as? String {
                        instructions = instructionsString.components(separatedBy: "\n")
                            .map { cleanInstructionText($0) }
                            .filter { !$0.isEmpty && $0.count > 10 }
                    } else if let instructionsArray = instructionsData as? [[String: Any]] {
                        instructions = instructionsArray.compactMap { instructionObj -> String? in
                            if let text = instructionObj["text"] as? String {
                                let cleanText = cleanInstructionText(text)
                                return cleanText.count > 10 ? cleanText : nil
                            } else if let name = instructionObj["name"] as? String {
                                let cleanName = cleanInstructionText(name)
                                return cleanName.count > 10 ? cleanName : nil
                            }
                            return nil
                        }.filter { !$0.isEmpty }
                    }
                }
            }

            // Extract images with better handling
            var images: [String] = []
            if let image = recipeData["image"] as? String {
                images = [image]
            } else if let imageList = recipeData["image"] as? [String] {
                images = imageList
            } else if let imageObject = recipeData["image"] as? [String: Any], let url = imageObject["url"] as? String {
                images = [url]
            } else if let imageArray = recipeData["image"] as? [[String: Any]] {
                images = imageArray.compactMap { imageObj in
                    if let url = imageObj["url"] as? String {
                        return url
                    } else if let contentUrl = imageObj["contentUrl"] as? String {
                        return contentUrl
                    }
                    return nil
                }
            }
            
            // Also try to get the main image from other properties
            if images.isEmpty {
                if let mainImage = recipeData["photo"] as? String {
                    images = [mainImage]
                } else if let mainImageObj = recipeData["photo"] as? [String: Any], let url = mainImageObj["url"] as? String {
                    images = [url]
                }
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

        // Extract instructions with enhanced patterns for RecipeTin Eats and other sites
        var instructions: [String] = []
        let instructionPatterns = [
            // RecipeTin Eats specific patterns
            "<li[^>]*class=\"[^\"]*wprm-recipe-instruction-text[^\"]*\"[^>]*>(.*?)</li>",
            "<div[^>]*class=\"[^\"]*wprm-recipe-instruction-text[^\"]*\"[^>]*>(.*?)</div>",
            "<div[^>]*class=\"[^\"]*recipe-instructions[^\"]*\"[^>]*>(.*?)</div>",
            
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
            
            // WP Recipe Maker specific patterns (used by many food blogs)
            "<li[^>]*class=\"[^\"]*wprm-recipe-instruction[^\"]*\"[^>]*>(.*?)</li>",
            "<div[^>]*class=\"[^\"]*wprm-recipe-instruction[^\"]*\"[^>]*>(.*?)</div>",
            
            // Microdata patterns
            "<li[^>]*itemprop=\"recipeInstructions\"[^>]*>(.*?)</li>",
            "<div[^>]*itemprop=\"recipeInstructions\"[^>]*>(.*?)</div>",
            "<p[^>]*itemprop=\"recipeInstructions\"[^>]*>(.*?)</p>",
            
            // Generic patterns for ordered lists that might contain instructions
            "<ol[^>]*class=\"[^\"]*instructions[^\"]*\"[^>]*>(.*?)</ol>",
            "<ol[^>]*class=\"[^\"]*recipe-instructions[^\"]*\"[^>]*>(.*?)</ol>",
            "<ol[^>]*class=\"[^\"]*method[^\"]*\"[^>]*>(.*?)</ol>",
            
            // Try to find any ordered list after a heading that contains "instructions", "directions", "method", etc.
            "(?i)<h[1-6][^>]*>.*?(instructions|directions|method|steps|preparation).*?</h[1-6]>\\s*<ol[^>]*>(.*?)</ol>",
            
            // Try to find any div with "instructions" or "directions" in the class name
            "<div[^>]*class=\"[^\"]*(?:instructions|directions|method|steps|preparation)[^\"]*\"[^>]*>(.*?)</div>"
        ]
        
        // First try to extract instructions as a list
        for pattern in instructionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                
                if pattern.contains("</ol>") {
                    // Handle ordered list patterns - extract individual list items
                    let foundInstructions = matches.compactMap { match -> [String]? in
                        guard let range = Range(match.range(at: 1), in: html) else { return nil }
                        let listContent = String(html[range])
                        
                        // Extract individual list items from the ordered list
                        let itemPattern = "<li[^>]*>(.*?)</li>"
                        if let itemRegex = try? NSRegularExpression(pattern: itemPattern, options: [.dotMatchesLineSeparators]) {
                            let itemMatches = itemRegex.matches(in: listContent, range: NSRange(listContent.startIndex..., in: listContent))
                            return itemMatches.compactMap { itemMatch -> String? in
                                guard let itemRange = Range(itemMatch.range(at: 1), in: listContent) else { return nil }
                                let instruction = String(listContent[itemRange])
                                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                                    .replacingOccurrences(of: "&nbsp;", with: " ")
                                    .replacingOccurrences(of: "&amp;", with: "&")
                                    .replacingOccurrences(of: "&lt;", with: "<")
                                    .replacingOccurrences(of: "&gt;", with: ">")
                                    .replacingOccurrences(of: "&quot;", with: "\"")
                                    .replacingOccurrences(of: "&#39;", with: "'")
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                
                                // Filter out short instructions that are likely section headers
                                return instruction.count > 15 || instruction.contains(".") ? instruction : nil
                            }
                        }
                        return nil
                    }.flatMap { $0 }
                    
                    if !foundInstructions.isEmpty {
                        instructions = foundInstructions
                        break
                    }
                } else {
                    // Handle individual instruction patterns
                    let foundInstructions = matches.compactMap { match -> String? in
                        guard let range = Range(match.range(at: 1), in: html) else { return nil }
                        let instruction = String(html[range])
                            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                            .replacingOccurrences(of: "&nbsp;", with: " ")
                            .replacingOccurrences(of: "&amp;", with: "&")
                            .replacingOccurrences(of: "&lt;", with: "<")
                            .replacingOccurrences(of: "&gt;", with: ">")
                            .replacingOccurrences(of: "&quot;", with: "\"")
                            .replacingOccurrences(of: "&#39;", with: "'")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Filter out short instructions that are likely section headers
                        return instruction.count > 15 || instruction.contains(".") ? instruction : nil
                    }
                    
                    if !foundInstructions.isEmpty {
                        instructions = foundInstructions
                        break
                    }
                }
            }
        }
        
        // If we still don't have instructions, try additional extraction strategies
        if instructions.isEmpty {
            // Strategy 1: Look for instructions in specific recipe card containers
            let recipeCardPatterns = [
                "<div[^>]*class=\"[^\"]*recipe-card[^\"]*\"[^>]*>(.*?)</div>",
                "<div[^>]*class=\"[^\"]*wprm-recipe[^\"]*\"[^>]*>(.*?)</div>",
                "<div[^>]*class=\"[^\"]*recipe-instructions[^\"]*\"[^>]*>(.*?)</div>"
            ]
            
            for cardPattern in recipeCardPatterns {
                if let cardRegex = try? NSRegularExpression(pattern: cardPattern, options: [.dotMatchesLineSeparators]) {
                    let cardMatches = cardRegex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                    
                    for cardMatch in cardMatches {
                        guard let cardRange = Range(cardMatch.range(at: 1), in: html) else { continue }
                        let cardHtml = String(html[cardRange])
                        
                        // Look for instructions within the card
                        let instructionInCardPattern = "<(?:li|div|p)[^>]*(?:class=\"[^\"]*(?:instruction|step|method)[^\"]*\"|itemprop=\"recipeInstructions\")[^>]*>(.*?)</(?:li|div|p)>"
                        if let instructionRegex = try? NSRegularExpression(pattern: instructionInCardPattern, options: [.dotMatchesLineSeparators]) {
                            let instructionMatches = instructionRegex.matches(in: cardHtml, range: NSRange(cardHtml.startIndex..., in: cardHtml))
                            let cardInstructions = instructionMatches.compactMap { instructionMatch -> String? in
                                guard let instructionRange = Range(instructionMatch.range(at: 1), in: cardHtml) else { return nil }
                                let instruction = String(cardHtml[instructionRange])
                                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                                    .replacingOccurrences(of: "&nbsp;", with: " ")
                                    .replacingOccurrences(of: "&amp;", with: "&")
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                
                                return instruction.count > 15 || instruction.contains(".") ? instruction : nil
                            }
                            
                            if !cardInstructions.isEmpty {
                                instructions = cardInstructions
                                break
                            }
                        }
                    }
                }
                if !instructions.isEmpty { break }
            }
            
            // Strategy 2: Look for instructions in sections with specific headings
            if instructions.isEmpty {
                let sectionPattern = "(?i)<h[1-6][^>]*>.*?(instructions|directions|method|steps|preparation).*?</h[1-6]>\\s*(.*?)(?:<h[1-6]|<div[^>]*class=\"[^\"]*(?:section|recipe|card))"
                if let regex = try? NSRegularExpression(pattern: sectionPattern, options: [.dotMatchesLineSeparators]),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   let sectionRange = Range(match.range(at: 2), in: html) {
                    
                    let sectionHtml = String(html[sectionRange])
                    // Extract paragraphs or list items from this section
                    let stepPattern = "<(?:p|li|div)[^>]*>(.*?)</(?:p|li|div)>"
                    if let stepRegex = try? NSRegularExpression(pattern: stepPattern, options: [.dotMatchesLineSeparators]) {
                        let stepMatches = stepRegex.matches(in: sectionHtml, range: NSRange(sectionHtml.startIndex..., in: sectionHtml))
                        let sectionInstructions = stepMatches.compactMap { match -> String? in
                            guard let range = Range(match.range(at: 1), in: sectionHtml) else { return nil }
                            let step = String(sectionHtml[range])
                                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                                .replacingOccurrences(of: "&nbsp;", with: " ")
                                .replacingOccurrences(of: "&amp;", with: "&")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            return step.count > 15 || step.contains(".") ? step : nil
                        }
                        
                        if !sectionInstructions.isEmpty {
                            instructions = sectionInstructions
                        }
                    }
                }
            }
        }

        // Extract images with enhanced patterns
        var images: [String] = []
        let imagePatterns = [
            // Open Graph and Twitter Card images
            "<meta\\s+property=\"og:image\"\\s+content=\"([^\"]+)\"",
            "<meta\\s+name=\"twitter:image\"\\s+content=\"([^\"]+)\"",
            
            // Recipe-specific image classes
            "<img[^>]+class=\"[^\"]*recipe-image[^\"]*\"[^>]+src=\"([^\"]+)\"",
            "<img[^>]+class=\"[^\"]*recipe-hero[^\"]*\"[^>]+src=\"([^\"]+)\"",
            "<img[^>]+class=\"[^\"]*recipe-photo[^\"]*\"[^>]+src=\"([^\"]+)\"",
            "<img[^>]+class=\"[^\"]*hero-image[^\"]*\"[^>]+src=\"([^\"]+)\"",
            "<img[^>]+class=\"[^\"]*featured-image[^\"]*\"[^>]+src=\"([^\"]+)\"",
            "<img[^>]+class=\"[^\"]*main-image[^\"]*\"[^>]+src=\"([^\"]+)\"",
            
            // Generic patterns for recipe images
            "<img[^>]+src=\"([^\"]+)\"[^>]*alt=\"[^\"]*recipe[^\"]*\"",
            "<img[^>]+alt=\"[^\"]*recipe[^\"]*\"[^>]*src=\"([^\"]+)\"",
            
            // Picture elements
            "<picture[^>]*>[^<]*<img[^>]+src=\"([^\"]+)\"",
            
            // Figure elements with images
            "<figure[^>]*class=\"[^\"]*recipe[^\"]*\"[^>]*>[^<]*<img[^>]+src=\"([^\"]+)\""
        ]
        
        var foundImages: [String] = []
        for pattern in imagePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                let patternImages = matches.compactMap { match -> String? in
                    guard let range = Range(match.range(at: 1), in: html) else { return nil }
                    let imageUrl = String(html[range])
                    
                    // Convert relative URLs to absolute
                    if imageUrl.starts(with: "//") {
                        return "https:" + imageUrl
                    } else if imageUrl.starts(with: "/") {
                        return "\(url.scheme ?? "https")://\(url.host ?? "")" + imageUrl
                    } else if !imageUrl.starts(with: "http") {
                        return url.appendingPathComponent(imageUrl).absoluteString
                    }
                    
                    return imageUrl
                }
                foundImages.append(contentsOf: patternImages)
                if foundImages.count >= 3 { break } // Limit to first 3 images
            }
        }
        
        // Remove duplicates and filter out small/icon images
        images = Array(Set(foundImages)).filter { imageUrl in
            let lowercased = imageUrl.lowercased()
            return !lowercased.contains("icon") && 
                   !lowercased.contains("logo") && 
                   !lowercased.contains("avatar") &&
                   !lowercased.contains("thumb") &&
                   !lowercased.hasSuffix(".svg")
        }

        return (!title.isEmpty && (!ingredients.isEmpty || !instructions.isEmpty)) ?
            (title, ingredients, instructions, images) : nil
    }
}