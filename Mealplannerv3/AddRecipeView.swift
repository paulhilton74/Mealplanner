import SwiftUI
import PhotosUI
import CoreData
import Vision

// Import the Recipe type directly
struct Recipe {
    var title: String
    var ingredients: [String]
    var instructions: [String]
    var images: [String]
    var url: String
}

struct AddRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var recipeManager = RecipeManager.shared

    enum InputMode {
        case url, image, manual
    }

    @State private var selectedMode: InputMode? = nil
    @State private var title = ""
    @State private var ingredients = [""]
    @State private var instructions = [""]
    @State private var tags = [""]
    @State private var sourceURL = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isExtracting = false
    @State private var nutritionInfo = NutritionInfo.defaultValues
    @State private var showingNutritionSheet = false
    @State private var selectedMealTypes: Set<MealType> = []

    var body: some View {
        NavigationView {
            Group {
                if let mode = selectedMode {
                    recipeFormView(for: mode)
                } else {
                    inputSelectionView
                }
            }
            .navigationTitle("Add Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                if selectedMode != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveRecipe()
                        }
                        .disabled(title.isEmpty ||
                                  ingredients.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                    }
                }
            }
            .sheet(isPresented: $showingNutritionSheet) {
                NutritionEditorView(nutritionInfo: $nutritionInfo)
            }
        }
    }

    private var inputSelectionView: some View {
        VStack(spacing: 20) {
            Text("Choose Input Method")
                .font(.title2)
                .bold()
                .padding(.top, 30)

            VStack(spacing: 16) {
                inputOptionButton(title: "Add from Recipe URL", icon: "link", mode: .url)
                inputOptionButton(title: "Add Recipe from Image", icon: "photo", mode: .image)
                inputOptionButton(title: "Enter Recipe Manually", icon: "square.and.pencil", mode: .manual)
            }
            .padding()

            Spacer()
        }
    }

    private func inputOptionButton(title: String, icon: String, mode: InputMode) -> some View {
        Button(action: { selectedMode = mode }) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 30)
                Text(title)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
        }
    }

    @ViewBuilder
    private func recipeFormView(for mode: InputMode) -> some View {
        Form {
            if mode == .url {
                Section(header: Text("Recipe URL")) {
                    TextField("Enter recipe URL", text: $sourceURL)
                    Button(action: extractRecipe) {
                        HStack {
                            Text("Extract Recipe")
                            if isExtracting {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(sourceURL.isEmpty || isExtracting)
                }
            }

            Section(header: Text("Recipe Details")) {
                TextField("Recipe Title", text: $title)

                if mode == .image {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recipe Image")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            if let selectedImageData,
                               let uiImage = UIImage(data: selectedImageData) {
                                ZStack(alignment: .bottomTrailing) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 200)
                                        .cornerRadius(8)
                                    
                                    Text("Tap to change")
                                        .font(.caption)
                                        .padding(6)
                                        .background(Color.black.opacity(0.6))
                                        .foregroundColor(.white)
                                        .cornerRadius(6)
                                        .padding(8)
                                }
                            } else {
                                HStack {
                                    Image(systemName: "photo")
                                        .font(.title)
                                    Text("Select Recipe Image")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 100)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                            }
                        }
                        .onChange(of: selectedItem) { _, newValue in
                            Task {
                                print("=== IMAGE SELECTION DEBUG ===")
                                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                    print("Raw image data loaded: \(data.count) bytes")
                                    
                                    // Process and compress the image data
                                    let processedData = processImageData(data)
                                    
                                    await MainActor.run {
                                        selectedImageData = processedData
                                        print("✅ Processed image data stored. Size: \(processedData?.count ?? 0) bytes")
                                        print("✅ selectedImageData is now set: \(selectedImageData != nil)")
                                    }
                                } else {
                                    print("❌ Failed to load image data from PhotosPicker")
                                    await MainActor.run {
                                        selectedImageData = nil
                                    }
                                }
                            }
                        }
                        
                        if let _ = selectedImageData {
                            Button(action: extractRecipeFromImage) {
                                HStack {
                                    Image(systemName: "text.viewfinder")
                                    Text("Extract Recipe from Image")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .disabled(isExtracting)
                        }
                        
                        if isExtracting {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Extracting recipe from image...")
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }

            Section(header: Text("Ingredients")) {
                ForEach(ingredients.indices, id: \.self) { index in
                    HStack {
                        TextField("Ingredient \(index + 1)", text: $ingredients[index])
                        if ingredients.count > 1 {
                            Button(action: { ingredients.remove(at: index) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                Button("Add Ingredient") {
                    ingredients.append("")
                }
            }

            Section(header: Text("Instructions")) {
                ForEach(instructions.indices, id: \.self) { index in
                    HStack {
                        TextField("Step \(index + 1)", text: $instructions[index])
                        if instructions.count > 1 {
                            Button(action: { instructions.remove(at: index) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                Button("Add Step") {
                    instructions.append("")
                }
            }

            Section(header: Text("Tags")) {
                ForEach(tags.indices, id: \.self) { index in
                    HStack {
                        TextField("Tag \(index + 1)", text: $tags[index])
                        if tags.count > 1 {
                            Button(action: { tags.remove(at: index) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                Button("Add Tag") {
                    tags.append("")
                }
            }

            Section(header: Text("Nutrition Information")) {
                Button(action: {
                    // Generate nutrition info based on ingredients before showing the editor
                    if !ingredients.allSatisfy({ $0.isEmpty }) {
                        nutritionInfo = generateNutritionInfo(from: ingredients)
                    }
                    showingNutritionSheet = true
                }) {
                    HStack {
                        Text("Edit Nutrition Facts")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
                
                NutritionDialRow(nutritionInfo: nutritionInfo)
                    .frame(height: 100)
                    .padding(.vertical, 8)
            }
            
            Section {
                MealTypeTagSelector(
                    selectedMealTypes: $selectedMealTypes,
                    title: "Quick Tag for Meal Types",
                    showTitle: true
                )
            } header: {
                Text("Meal Type Tags")
            } footer: {
                Text("Select which meal types this recipe is suitable for. This helps with organizing your weekly meal plans.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func extractRecipe() {
        isExtracting = true

        guard let url = URL(string: sourceURL) else {
            isExtracting = false
            print("Invalid URL format")
            return
        }

        // Create a RecipeExtractorService instance
        let extractorService = RecipeExtractorService()
        
        // Use Task for async operation
        Task {
            do {
                // Try to extract the recipe using the service
                let recipeData = try await extractorService.extractRecipe(from: sourceURL)
                
                // Convert the tuple to a Recipe struct
                let recipe = Recipe(
                    title: recipeData.title,
                    ingredients: recipeData.ingredients,
                    instructions: recipeData.instructions,
                    images: recipeData.images,
                    url: sourceURL
                )
                
                // Update UI on main thread
                await MainActor.run {
                    self.title = recipe.title
                    
                    if !recipe.ingredients.isEmpty {
                        self.ingredients = recipe.ingredients
                    } else {
                        print("No ingredients extracted.")
                    }
                    
                    if !recipe.instructions.isEmpty {
                        self.instructions = recipe.instructions
                    } else {
                        print("No instructions extracted.")
                    }
                    
                    if let imageURLString = recipe.images.first,
                       let imageURL = URL(string: imageURLString) {
                        self.downloadImage(from: imageURL)
                    }
                    
                    self.isExtracting = false
                }
            } catch {
                // Fall back to the old method if the service fails
                print("RecipeExtractorService failed: \(error). Falling back to URLSession.")
                
                let task = URLSession.shared.dataTask(with: url) { data, response, error in
                    DispatchQueue.main.async {
                        defer { self.isExtracting = false }
                        
                        if let error = error {
                            print("Error fetching recipe: \(error)")
                            return
                        }
                        
                        guard let data = data,
                              let html = String(data: data, encoding: .utf8) else {
                            print("Error decoding data")
                            return
                        }
                        
                        if let recipeData = self.extractRecipeData(from: html) {
                            self.title = recipeData.title
                            
                            if !recipeData.ingredients.isEmpty {
                                self.ingredients = recipeData.ingredients
                            } else {
                                print("No ingredients extracted.")
                            }
                            
                            if !recipeData.instructions.isEmpty {
                                self.instructions = recipeData.instructions
                            } else {
                                print("No instructions extracted.")
                            }
                            
                            if let imageURLString = recipeData.images.first,
                               let imageURL = URL(string: imageURLString) {
                                self.downloadImage(from: imageURL)
                            }
                        } else {
                            print("Failed to extract recipe data")
                        }
                    }
                }
                task.resume()
            }
        }
    }

    private func extractRecipeData(from html: String) -> (title: String, ingredients: [String], instructions: [String], images: [String])? {
        // 1) Try JSON-LD first
        if let jsonLDData = extractJSONLD(from: html) {
            print("Extracted recipe data using JSON-LD")
            return jsonLDData
        }
        
        // 2) Try Microdata
        if let microdataResult = extractMicrodata(from: html) {
            print("Extracted recipe data using Microdata")
            return microdataResult
        }
        
        print("Failed to extract recipe data using built-in extractors")
        return nil
    }

    private func extractJSONLD(from html: String) -> (title: String, ingredients: [String], instructions: [String], images: [String])? {
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
        guard let title = recipeData["name"] as? String else { return nil }

        // Extract ingredients with fallback for single-string ingredients.
        var ingredients: [String] = []
        if let ingredientList = recipeData["recipeIngredient"] as? [String] {
            ingredients = ingredientList
        } else if let ingredientList = recipeData["ingredients"] as? [String] {
            ingredients = ingredientList
        } else if let ingredientString = recipeData["recipeIngredient"] as? String {
            ingredients = ingredientString.components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        } else if let ingredientString = recipeData["ingredients"] as? String {
            ingredients = ingredientString.components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }

        // Extract instructions with additional handling if it's a single string
        var instructions: [String] = []
        if let steps = recipeData["recipeInstructions"] as? [String] {
            instructions = steps
        } else if let steps = recipeData["recipeInstructions"] as? [[String: Any]] {
            instructions = steps.compactMap { $0["text"] as? String }
        } else if let instructionsString = recipeData["recipeInstructions"] as? String {
            instructions = instructionsString.components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }

        // Extract images
        var images: [String] = []
        if let image = recipeData["image"] as? String {
            images = [image]
        } else if let imageList = recipeData["image"] as? [String] {
            images = imageList
        }

        return (title, ingredients, instructions, images)
    }

    private func extractMicrodata(from html: String) -> (title: String, ingredients: [String], instructions: [String], images: [String])? {
        var title = ""
        var ingredients: [String] = []
        var instructions: [String] = []
        var images: [String] = []

        // Extract title (using common recipe title patterns)
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

        // Extract ingredients using several patterns.
        let ingredientPatterns = [
            "<li[^>]*class=\"[^\"]*ingredient[^\"]*\"[^>]*>(.*?)</li>",
            "<li[^>]*itemprop=\"recipeIngredient\"[^>]*>(.*?)</li>",
            "<div[^>]*class=\"[^\"]*ingredient[^\"]*\"[^>]*>(.*?)</div>",
            "<span[^>]*class=\"[^\"]*ingredient[^\"]*\"[^>]*>(.*?)</span>",
            "<p[^>]*class=\"[^\"]*ingredient[^\"]*\"[^>]*>(.*?)</p>",
            "<div[^>]*data-ingredient[^>]*>(.*?)</div>",
            // Extra pattern: any <li> that contains the word "ingredient" (case-insensitive)
            "(?i)<li[^>]*>([^<]*ingredient[^<]*)</li>"
        ]
        for pattern in ingredientPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                let foundIngredients = matches.compactMap { match -> String? in
                    guard let range = Range(match.range(at: 1), in: html) else { return nil }
                    return String(html[range])
                        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if !foundIngredients.isEmpty {
                    ingredients = foundIngredients
                    break
                }
            }
        }

        // Extract instructions using several patterns.
        let instructionPatterns = [
            "<li[^>]*class=\"[^\"]*instruction[^\"]*\"[^>]*>(.*?)</li>",
            "<li[^>]*itemprop=\"recipeInstructions\"[^>]*>(.*?)</li>",
            "<div[^>]*class=\"[^\"]*instruction[^\"]*\"[^>]*>(.*?)</div>",
            "<p[^>]*class=\"[^\"]*instruction[^\"]*\"[^>]*>(.*?)</p>",
            "<div[^>]*class=\"[^\"]*step[^\"]*\"[^>]*>(.*?)</div>",
            "<ol[^>]*class=\"[^\"]*instructions[^\"]*\"[^>]*>(.*?)</ol>",
            "<div[^>]*class=\"[^\"]*recipe-method[^\"]*\"[^>]*>(.*?)</div>",
            "<div[^>]*class=\"[^\"]*preparation[^\"]*\"[^>]*>(.*?)</div>",
            "<div[^>]*class=\"[^\"]*directions[^\"]*\"[^>]*>(.*?)</div>",
            "<div[^>]*class=\"[^\"]*method-steps[^\"]*\"[^>]*>(.*?)</div>",
            "<div[^>]*class=\"[^\"]*recipe-directions[^\"]*\"[^>]*>(.*?)</div>",
            "<div[^>]*class=\"[^\"]*cooking-instructions[^\"]*\"[^>]*>(.*?)</div>",
            "<div[^>]*data-recipe-instructions[^>]*>(.*?)</div>",
            "<div[^>]*itemtype=\"http://schema.org/Recipe\"[^>]*>.*?<div[^>]*class=\"[^\"]*instructions[^\"]*\"[^>]*>(.*?)</div>"
        ]
        for pattern in instructionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                let foundInstructions = matches.compactMap { match -> String? in
                    guard let range = Range(match.range(at: 1), in: html) else { return nil }
                    let instruction = String(html[range])
                        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        .replacingOccurrences(of: "&nbsp;", with: " ")
                        .replacingOccurrences(of: "&amp;", with: "&")
                        .replacingOccurrences(of: "&quot;", with: "\"")
                        .replacingOccurrences(of: "&#39;", with: "'")
                        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return instruction.isEmpty ? nil : instruction
                }
                if !foundInstructions.isEmpty {
                    instructions = foundInstructions
                    break
                }
            }
        }

        // If we have a single block of instructions, try splitting by newline.
        if instructions.count == 1 {
            let potentialSteps = instructions[0].components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if potentialSteps.count > 1 {
                instructions = potentialSteps
            }
        }

        // Extract images.
        let imagePatterns = [
            "<meta\\s+property=\"og:image\"\\s+content=\"([^\"]+)\"",
            "<img[^>]+class=\"[^\"]*recipe-image[^\"]*\"[^>]+src=\"([^\"]+)\"",
            "<img[^>]+src=\"([^\"]+)\"[^>]*>"
        ]
        for pattern in imagePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                let foundImages = matches.compactMap { match -> String? in
                    guard let range = Range(match.range(at: 1), in: html) else { return nil }
                    return String(html[range])
                }
                if !foundImages.isEmpty {
                    images = foundImages
                    break
                }
            }
        }

        return (!title.isEmpty && (!ingredients.isEmpty || !instructions.isEmpty)) ?
            (title, ingredients, instructions, images) : nil
    }

    private func downloadImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let data = data {
                    self.selectedImageData = self.processImageData(data)
                    print("Downloaded and processed image from URL. Size: \(self.selectedImageData?.count ?? 0) bytes")
                }
            }
        }.resume()
    }
    
    private func processImageData(_ data: Data) -> Data? {
        print("=== PROCESS IMAGE DATA DEBUG ===")
        print("Input data size: \(data.count) bytes")
        
        guard let image = UIImage(data: data) else { 
            print("❌ Failed to create UIImage from data")
            return data 
        }
        
        print("✅ UIImage created successfully. Size: \(image.size)")
        
        // Resize image if it's too large to save storage space
        let maxSize: CGFloat = 1024
        let size = image.size
        
        if size.width > maxSize || size.height > maxSize {
            print("📏 Image is large (\(size)), resizing...")
            let ratio = min(maxSize / size.width, maxSize / size.height)
            let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            if let resizedImage = resizedImage,
               let compressedData = resizedImage.jpegData(compressionQuality: 0.8) {
                print("✅ Image resized from \(size) to \(newSize). Compressed size: \(compressedData.count) bytes")
                return compressedData
            } else {
                print("❌ Failed to resize image, returning original")
                return data
            }
        }
        
        // If no resizing needed, just compress
        if let compressedData = image.jpegData(compressionQuality: 0.8) {
            print("✅ Image compressed without resizing. Size: \(compressedData.count) bytes")
            return compressedData
        }
        
        print("❌ Compression failed, returning original data")
        return data
    }

    private func extractRecipeFromImage() {
        print("=== EXTRACT RECIPE FROM IMAGE DEBUG ===")
        print("selectedImageData at start: \(selectedImageData?.count ?? 0) bytes")
        
        guard let imageData = selectedImageData, let uiImage = UIImage(data: imageData) else { 
            print("❌ Error: No image data or unable to create UIImage")
            print("selectedImageData is nil: \(selectedImageData == nil)")
            return 
        }
        
        isExtracting = true
        print("✅ Starting recipe extraction from image... Image size: \(uiImage.size.width)x\(uiImage.size.height)")
        print("Image data being used for OCR: \(imageData.count) bytes")
        
        // Use local Vision framework instead of Google Cloud Vision
        print("Using local iOS Vision framework for OCR")
        
        // Create a background task for OCR processing using local Vision framework
        Task {
            // First attempt: Original image
            print("Starting local OCR processing on original image...")
            let extractedText = await performOCR(on: uiImage)
            print("Local OCR completed. Extracted text length: \(extractedText.count) characters")
            
            if extractedText.isEmpty || extractedText.count < 50 {
                print("No text or insufficient text extracted from image. Trying with enhanced image...")
                
                // Second attempt: Enhanced image
                let enhancedImage = enhanceImageForOCR(uiImage)
                let secondAttemptText = await performOCR(on: enhancedImage)
                print("Enhanced OCR completed. Extracted text length: \(secondAttemptText.count) characters")
                
                if secondAttemptText.isEmpty || secondAttemptText.count < 50 {
                    print("Still insufficient text. Trying with rotated image...")
                    
                    // Third attempt: Try with rotated image (sometimes OCR works better on different orientations)
                    if let cgImage = uiImage.cgImage {
                        let rotatedImage = UIImage(cgImage: cgImage, scale: uiImage.scale, orientation: .right)
                        let thirdAttemptText = await performOCR(on: enhanceImageForOCR(rotatedImage))
                        print("Rotated OCR completed. Extracted text length: \(thirdAttemptText.count) characters")
                        
                        if thirdAttemptText.isEmpty || thirdAttemptText.count < 50 {
                            await MainActor.run {
                                isExtracting = false
                                print("Error: No text was extracted from the image after multiple attempts")
                                
                                // Set default values since extraction failed
                                if self.title.isEmpty {
                                    self.title = "Recipe from Image"
                                }
                                
                                if self.ingredients.count == 1 && self.ingredients[0].isEmpty {
                                    self.ingredients = ["No ingredients detected. Please add manually."]
                                }
                                
                                if self.instructions.count == 1 && self.instructions[0].isEmpty {
                                    self.instructions = ["No instructions detected. Please add manually."]
                                }
                                
                                print("Image data preserved after failed extraction: \(self.selectedImageData?.count ?? 0) bytes")
                            }
                            return
                        } else {
                            print("Third attempt extracted \(thirdAttemptText.count) characters")
                            await processExtractedTextAndUpdateUI(thirdAttemptText)
                        }
                    } else {
                        await processExtractedTextAndUpdateUI(secondAttemptText.isEmpty ? "Recipe from Image" : secondAttemptText)
                    }
                } else {
                    print("Second attempt extracted \(secondAttemptText.count) characters")
                    await processExtractedTextAndUpdateUI(secondAttemptText)
                }
            } else {
                // Continue with the text from the first attempt
                print("First attempt successful, processing \(extractedText.count) characters")
                await processExtractedTextAndUpdateUI(extractedText)
            }
        }
    }
    
    // Helper function to process text and update UI
    private func processExtractedTextAndUpdateUI(_ extractedText: String) async {
        // Print the first 500 characters of extracted text for debugging
        let previewText = extractedText.prefix(500)
        print("Preview of extracted text: \n\(previewText)...")
        
        // Step 2: Process the extracted text to identify recipe components
        let (extractedTitle, extractedIngredients, extractedInstructions) = processExtractedText(extractedText)
        
        print("Processing completed:")
        print("- Title: \(extractedTitle)")
        print("- Ingredients found: \(extractedIngredients.count)")
        print("- Instructions found: \(extractedInstructions.count)")
        
        // Step 3: Update the UI on the main thread
        await MainActor.run {
            isExtracting = false
            
            // Update title if empty or if we found a good title
            if self.title.isEmpty || (extractedTitle.count > 0 && extractedTitle.count < 50) {
                self.title = extractedTitle.isEmpty ? "Recipe from Image" : extractedTitle
            }
            
            // Update ingredients if we found any
            if !extractedIngredients.isEmpty {
                self.ingredients = extractedIngredients
            } else if self.ingredients.count == 1 && self.ingredients[0].isEmpty {
                // Fallback if no ingredients were found
                self.ingredients = ["No ingredients detected. Please add manually."]
            }
            
            // Update instructions if we found any
            if !extractedInstructions.isEmpty {
                self.instructions = extractedInstructions
            } else if self.instructions.count == 1 && self.instructions[0].isEmpty {
                // Fallback if no instructions were found
                self.instructions = ["No instructions detected. Please add manually."]
            }
            
            print("Recipe extraction complete: \(self.title)")
            print("Found \(extractedIngredients.count) ingredients and \(extractedInstructions.count) instructions")
            print("Image data after extraction: \(self.selectedImageData?.count ?? 0) bytes")
        }
    }
    
    // Enhanced image preprocessing for OCR
    private func enhanceImageForOCR(_ image: UIImage) -> UIImage {
        print("Enhancing image for OCR...")
        
        guard let cgImage = image.cgImage else {
            print("Error: Unable to get CGImage from UIImage")
            return image
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext(options: nil)
        
        // Apply a series of filters to improve text recognition
        
        // 1. Convert to grayscale with higher contrast
        let grayscaleFilter = CIFilter(name: "CIColorControls")
        grayscaleFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        grayscaleFilter?.setValue(0.0, forKey: kCIInputSaturationKey) // Remove color
        grayscaleFilter?.setValue(1.5, forKey: kCIInputContrastKey) // Increase contrast more
        grayscaleFilter?.setValue(0.1, forKey: kCIInputBrightnessKey) // Slightly increase brightness
        
        var processedImage = grayscaleFilter?.outputImage ?? ciImage
        
        // 2. Apply unsharp mask to sharpen text
        let sharpenFilter = CIFilter(name: "CIUnsharpMask")
        sharpenFilter?.setValue(processedImage, forKey: kCIInputImageKey)
        sharpenFilter?.setValue(2.5, forKey: kCIInputRadiusKey) // Increased radius
        sharpenFilter?.setValue(2.0, forKey: kCIInputIntensityKey) // Increased intensity
        
        if let outputImage = sharpenFilter?.outputImage {
            processedImage = outputImage
        }
        
        // 3. Apply noise reduction filter
        if let noiseReductionFilter = CIFilter(name: "CINoiseReduction") {
            noiseReductionFilter.setValue(processedImage, forKey: kCIInputImageKey)
            noiseReductionFilter.setValue(0.02, forKey: "inputNoiseLevel")
            noiseReductionFilter.setValue(0.40, forKey: "inputSharpness")
            
            if let outputImage = noiseReductionFilter.outputImage {
                processedImage = outputImage
            }
        }
        
        // Convert back to UIImage
        if let outputCGImage = context.createCGImage(processedImage, from: processedImage.extent) {
            print("Image enhancement successful with multiple filters")
            return UIImage(cgImage: outputCGImage)
        }
        
        print("Image enhancement failed, returning original image")
        return image
    }
    
    // Perform OCR on the image using Vision framework
    private func performOCR(on image: UIImage) async -> String {
        // Create a Vision request to recognize text
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        // Set recognition languages to prioritize English
        request.recognitionLanguages = ["en-US", "en-GB"]
        
        // Set custom revision if available
        if #available(iOS 16.0, *) {
            request.revision = VNRecognizeTextRequestRevision3
        } else {
            request.revision = VNRecognizeTextRequestRevision2
        }
        
        // Try multiple recognition approaches
        return await withCheckedContinuation { continuation in
            guard let cgImage = image.cgImage else {
                print("Error: Unable to get CGImage from UIImage")
                continuation.resume(returning: "")
                return
            }
            
            print("Image dimensions for OCR: \(cgImage.width) x \(cgImage.height)")
            
            // Create a request handler with the image
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                print("Starting OCR text recognition with accurate level...")
                try handler.perform([request])
                
                // Process the recognized text
                guard let observations = request.results else {
                    print("Error: No text observations found in the image")
                    continuation.resume(returning: "")
                    return
                }
                
                print("OCR found \(observations.count) text observations")
                
                if observations.isEmpty {
                    print("Warning: Observations array is empty")
                    continuation.resume(returning: "")
                    return
                }
                
                // Combine all recognized text
                let recognizedText = observations.compactMap { observation in
                    // Get the top candidate with confidence
                    if let candidate = observation.topCandidates(1).first {
                        let confidence = candidate.confidence
                        let text = candidate.string
                        print("OCR text: '\(text)' (confidence: \(confidence))")
                        // Lower threshold to capture more text
                        return confidence > 0.03 ? text : nil 
                    }
                    return nil
                }.joined(separator: "\n")
                
                print("Total recognized text length: \(recognizedText.count)")
                
                if recognizedText.isEmpty {
                    // If no text was recognized, try with fast recognition level
                    print("No text recognized with accurate level, trying with fast level...")
                    let fastRequest = VNRecognizeTextRequest()
                    fastRequest.recognitionLevel = .fast
                    fastRequest.usesLanguageCorrection = true
                    fastRequest.recognitionLanguages = ["en-US", "en-GB"]
                    
                    try handler.perform([fastRequest])
                    
                    if let fastObservations = fastRequest.results, !fastObservations.isEmpty {
                        let fastRecognizedText = fastObservations.compactMap { observation in
                            if let candidate = observation.topCandidates(1).first {
                                let confidence = candidate.confidence
                                let text = candidate.string
                                print("Fast OCR text: '\(text)' (confidence: \(confidence))")
                                return confidence > 0.01 ? text : nil // Even lower threshold for fast mode
                            }
                            return nil
                        }.joined(separator: "\n")
                        
                        print("Fast OCR recognized text length: \(fastRecognizedText.count)")
                        continuation.resume(returning: fastRecognizedText)
                    } else {
                        continuation.resume(returning: "")
                    }
                } else {
                    continuation.resume(returning: recognizedText)
                }
            } catch {
                print("Error performing OCR: \(error)")
                continuation.resume(returning: "")
            }
        }
    }
    
    // Process the extracted text to identify recipe components
    private func processExtractedText(_ text: String) -> (title: String, ingredients: [String], instructions: [String]) {
        guard !text.isEmpty else { 
            print("Error: Empty text to process")
            return ("", [], []) 
        }
        
        // Split the text into lines
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        print("Processing \(lines.count) lines of text")
        
        // Print all lines for debugging
        for (i, line) in lines.enumerated() {
            print("Line \(i): \(line)")
        }
        
        // Extract title (usually one of the first few lines, shorter than ingredients/instructions)
        var title = ""
        for i in 0..<min(5, lines.count) {
            let line = lines[i]
            if line.count > 3 && line.count < 60 && !line.contains(":") && 
               !line.hasPrefix("•") && !line.hasPrefix("-") && !line.hasPrefix("*") && 
               !line.hasPrefix("–") && !line.hasPrefix("1") && !line.hasPrefix("2") {
                title = line
                print("Found potential title: \(title)")
                break
            }
        }
        
        // If no title found in first 5 lines, try to find the most title-like line
        if title.isEmpty && lines.count > 0 {
            for line in lines {
                if line.count > 5 && line.count < 60 && 
                   !line.contains("ingredient") && !line.contains("instruction") && 
                   !line.contains("direction") && !line.contains("step") &&
                   !line.contains("cup") && !line.contains("tbsp") && !line.contains("tsp") {
                    title = line
                    print("Found alternative title: \(title)")
                    break
                }
            }
        }
        
        var ingredients: [String] = []
        var instructions: [String] = []
        var currentSection: RecipeSection = .unknown
        let _ = false // ingredientSectionFound - removed unused variable
        let _ = false // instructionSectionFound - removed unused variable
        
        // First pass: Look for explicit section headers
        print("First pass: Looking for section headers")
        
        for (index, line) in lines.enumerated() {
            let lowercaseLine = line.lowercased()
            
            // Check for ingredient section headers
            if (lowercaseLine.contains("ingredient") && !lowercaseLine.contains("instruction")) ||
               lowercaseLine == "ingredients" || 
               lowercaseLine.hasSuffix("ingredients:") || 
               lowercaseLine.hasSuffix("ingredients list:") ||
               lowercaseLine == "what you need" ||
               lowercaseLine.hasSuffix("what you need:") {
                currentSection = .ingredients
                print("Found ingredients section at line \(index): \(line)")
                continue
            } 
            
            // Check for instruction section headers
            if lowercaseLine.contains("instruction") || 
               lowercaseLine.contains("direction") || 
               lowercaseLine.contains("method") || 
               lowercaseLine.contains("preparation") || 
               lowercaseLine.contains("steps") ||
               lowercaseLine == "instructions" ||
               lowercaseLine.hasSuffix("instructions:") ||
               lowercaseLine.hasSuffix("directions:") ||
               lowercaseLine.hasSuffix("method:") ||
               lowercaseLine == "what to do" ||
               lowercaseLine.hasSuffix("what to do:") {
                currentSection = .instructions
                print("Found instructions section at line \(index): \(line)")
                continue
            }
            
            // Process lines based on current section
            if currentSection == .ingredients {
                // Skip section header lines
                if lowercaseLine.contains("ingredient") && lowercaseLine.count < 15 {
                    continue
                }
                
                let cleaned = cleanIngredientLine(line)
                if !cleaned.isEmpty {
                    ingredients.append(cleaned)
                    print("Added ingredient from section: \(cleaned)")
                }
            } else if currentSection == .instructions {
                // Skip section header lines
                if (lowercaseLine.contains("instruction") || lowercaseLine.contains("direction")) && lowercaseLine.count < 15 {
                    continue
                }
                
                let cleaned = cleanInstructionLine(line)
                if !cleaned.isEmpty {
                    instructions.append(cleaned)
                    print("Added instruction from section: \(cleaned)")
                }
            }
        }
        
        // Second pass: If we didn't find explicit sections, analyze line by line
        if ingredients.isEmpty && instructions.isEmpty {
            print("Second pass: Analyzing line by line")
            
            // Reset current section
            currentSection = .unknown
            
            for (index, line) in lines.enumerated() {
                // Skip very short lines or lines that are likely headers
                if line.count < 3 || (line.uppercased() == line && line.count < 20) {
                    continue
                }
                
                // Skip the title line
                if line == title {
                    continue
                }
                
                // Process the line based on its characteristics
                if isLikelyIngredient(line) {
                    let cleaned = cleanIngredientLine(line)
                    ingredients.append(cleaned)
                    print("Line \(index) identified as ingredient: \(cleaned)")
                    if currentSection == .unknown {
                        currentSection = .ingredients
                    }
                } else if isLikelyInstruction(line) {
                    let cleaned = cleanInstructionLine(line)
                    instructions.append(cleaned)
                    print("Line \(index) identified as instruction: \(cleaned)")
                    if currentSection == .unknown {
                        currentSection = .instructions
                    }
                } else if currentSection == .ingredients {
                    // If we're in the ingredients section, assume it's an ingredient
                    let cleaned = cleanIngredientLine(line)
                    ingredients.append(cleaned)
                    print("Line \(index) added as ingredient (by section): \(cleaned)")
                } else if currentSection == .instructions {
                    // If we're in the instructions section, assume it's an instruction
                    let cleaned = cleanInstructionLine(line)
                    instructions.append(cleaned)
                    print("Line \(index) added as instruction (by section): \(cleaned)")
                }
            }
        }
        
        // Third pass: If we still couldn't identify sections, try to make an educated guess
        if ingredients.isEmpty && instructions.isEmpty {
            print("Third pass: Making educated guesses")
            
            // Try to identify ingredients and instructions based on line characteristics
            for (index, line) in lines.enumerated() {
                if line.count > 3 && line != title {
                    // Check for common ingredient indicators
                    if line.contains("cup") || line.contains("tbsp") || line.contains("tsp") || 
                       line.contains("oz") || line.contains("pound") || line.contains("g") ||
                       line.contains("ml") || line.contains("liter") || line.contains("pinch") ||
                       line.contains("tablespoon") || line.contains("teaspoon") ||
                       line.contains("salt") || line.contains("pepper") || line.contains("sugar") ||
                       line.contains("flour") || line.contains("butter") || line.contains("oil") {
                        let cleaned = cleanIngredientLine(line)
                        ingredients.append(cleaned)
                        print("Line \(index) guessed as ingredient: \(cleaned)")
                    } 
                    // Check for common instruction indicators
                    else if line.count > 20 && (line.contains(" in ") || line.contains(" until ") || 
                              line.contains(" for ") || line.contains(" then ") ||
                              line.contains(" mix ") || line.contains(" stir ") ||
                              line.contains(" add ") || line.contains(" cook ") ||
                              line.contains(" bake ") || line.contains(" heat ") ||
                              line.contains(" combine ") || line.contains(" place ") ||
                              line.contains(" remove ") || line.contains(" set ")) {
                        let cleaned = cleanInstructionLine(line)
                        instructions.append(cleaned)
                        print("Line \(index) guessed as instruction: \(cleaned)")
                    }
                }
            }
        }
        
        // Last resort: If we still have nothing, use a simple heuristic
        if ingredients.isEmpty && instructions.isEmpty && lines.count > 2 {
            print("Last resort: Using simple heuristic to split content")
            
            // Analyze line lengths to determine a potential split point
            let lineLengths = lines.map { $0.count }
            var potentialSplitPoints: [Int] = []
            
            // Look for significant changes in line length that might indicate a section change
            for i in 1..<lineLengths.count {
                let lengthRatio = Double(lineLengths[i]) / Double(max(1, lineLengths[i-1]))
                if lengthRatio > 2.0 || lengthRatio < 0.5 {
                    potentialSplitPoints.append(i)
                }
            }
            
            if let splitPoint = potentialSplitPoints.first, splitPoint > 1 && splitPoint < lines.count - 1 {
                print("Found potential split point at line \(splitPoint)")
                
                // Assume lines before split point are ingredients
                for i in 0..<splitPoint {
                    if lines[i] != title && lines[i].count > 3 {
                        ingredients.append(cleanIngredientLine(lines[i]))
                    }
                }
                
                // Assume lines after split point are instructions
                for i in splitPoint..<lines.count {
                    if lines[i] != title && lines[i].count > 3 {
                        instructions.append(cleanInstructionLine(lines[i]))
                    }
                }
            } else {
                // If no clear split point, use the first third as ingredients and the rest as instructions
                let splitPoint = min(lines.count / 3, 5)
                
                for i in 0..<splitPoint {
                    if lines[i] != title && lines[i].count > 3 {
                        ingredients.append(cleanIngredientLine(lines[i]))
                    }
                }
                
                for i in splitPoint..<lines.count {
                    if lines[i] != title && lines[i].count > 3 {
                        instructions.append(cleanInstructionLine(lines[i]))
                    }
                }
            }
        }
        
        // Remove duplicates
        ingredients = Array(Set(ingredients))
        instructions = Array(Set(instructions))
        
        // Sort ingredients and instructions to maintain a logical order
        ingredients.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        
        // Sort instructions by any leading numbers if present
        instructions.sort { (a, b) -> Bool in
            let aPrefix = a.prefix(while: { $0.isNumber || $0 == "." || $0 == ")" || $0.isWhitespace })
            let bPrefix = b.prefix(while: { $0.isNumber || $0 == "." || $0 == ")" || $0.isWhitespace })
            
            if let aNum = Int(aPrefix.filter { $0.isNumber }), let bNum = Int(bPrefix.filter { $0.isNumber }) {
                return aNum < bNum
            }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
        
        print("Final extraction results:")
        print("- Title: \(title)")
        print("- Ingredients: \(ingredients.count)")
        print("- Instructions: \(instructions.count)")
        
        return (title, ingredients, instructions)
    }
    
    // Helper enum to track which section we're processing
    private enum RecipeSection {
        case unknown, ingredients, instructions
    }
    
    // Check if a line is likely an ingredient
    private func isLikelyIngredient(_ line: String) -> Bool {
        let lowercaseLine = line.lowercased()
        
        // Check for common ingredient patterns
        if line.hasPrefix("•") || line.hasPrefix("-") || line.hasPrefix("*") || line.hasPrefix("–") {
            return true
        }
        
        // Check for numbered list items that are likely ingredients
        if let regex = try? NSRegularExpression(pattern: #"^\d+[\.\)]\s"#),
           regex.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) != nil {
            // If it's a numbered item, check if it's short enough to be an ingredient
            // Ingredients are typically shorter than instructions
            return line.count < 100
        }
        
        // Check for measurement patterns
        let measurementTerms = [
            "cup", "cups", "tbsp", "tbs", "tablespoon", "tablespoons",
            "tsp", "teaspoon", "teaspoons", "ounce", "ounces", 
            "oz", "pound", "pounds", "lb", "lbs", "gram", "grams",
            "g ", "kg", "ml", "milliliter", "milliliters", "liter", "liters",
            "pinch", "dash", "handful", "slice", "slices", "piece", "pieces",
            "clove", "cloves", "bunch", "bunches", "sprig", "sprigs"
        ]
        
        for term in measurementTerms {
            if lowercaseLine.contains(term) {
                return true
            }
        }
        
        // Check for fraction patterns that are common in ingredients
        let fractionPatterns = ["1/2", "1/4", "3/4", "1/3", "2/3", "1/8", "3/8", "5/8", "7/8"]
        for fraction in fractionPatterns {
            if lowercaseLine.contains(fraction) {
                return true
            }
        }
        
        // Check for common ingredient names
        let commonIngredients = [
            "salt", "pepper", "sugar", "flour", "oil", "butter", "egg", "eggs",
            "milk", "cream", "cheese", "water", "garlic", "onion", "tomato",
            "chicken", "beef", "pork", "fish", "rice", "pasta", "potato",
            "carrot", "celery", "olive", "vinegar", "sauce", "broth", "stock",
            "yogurt", "honey", "syrup", "vanilla", "cinnamon", "oregano", "basil",
            "thyme", "rosemary", "parsley", "cilantro", "lemon", "lime", "orange"
        ]
        
        for ingredient in commonIngredients {
            // Check for whole word match to avoid false positives
            let pattern = "\\b\(ingredient)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern),
               regex.firstMatch(in: lowercaseLine, range: NSRange(location: 0, length: lowercaseLine.utf16.count)) != nil {
                return true
            }
        }
        
        // If the line is short and doesn't contain cooking verbs, it's more likely to be an ingredient
        if line.count < 50 && !containsCookingVerbs(lowercaseLine) {
            return true
        }
        
        return false
    }
    
    // Check if a line is likely an instruction
    private func isLikelyInstruction(_ line: String) -> Bool {
        // Instructions are typically longer
        if line.count < 15 {
            return false
        }
        
        let lowercaseLine = line.lowercased()
        
        // Check for numbered steps
        if let regex = try? NSRegularExpression(pattern: #"^\d+[\.\)]\s"#),
           regex.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) != nil ||
           (try? NSRegularExpression(pattern: #"^step\s*\d+"#))?.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) != nil {
            // If it's a numbered item and it's long, it's likely an instruction
            return line.count >= 30
        }
        
        // Check if the line contains cooking verbs
        if containsCookingVerbs(lowercaseLine) {
            return true
        }
        
        // Check for cooking-related phrases
        let cookingPhrases = [
            " until ", " for ", " then ", " minutes", " minute ",
            " hour ", " hours ", " heat ", " oven ", " stove ",
            " pan ", " pot ", " bowl ", " mix ", " combine ",
            " temperature ", " degrees ", " fahrenheit ", " celsius ",
            " preheat ", " simmer ", " boil ", " fry ", " sauté ",
            " bake ", " roast ", " grill ", " broil ", " toast ",
            " microwave ", " refrigerate ", " chill ", " cool ", " rest "
        ]
        
        for phrase in cookingPhrases {
            if lowercaseLine.contains(phrase) {
                return true
            }
        }
        
        // If the line is long and doesn't look like an ingredient, it's more likely to be an instruction
        return line.count > 60
    }
    
    // Helper function to check if a line contains cooking verbs
    private func containsCookingVerbs(_ line: String) -> Bool {
        let cookingVerbs = [
            "preheat", "heat", "mix", "stir", "combine", "add", "pour", "place", 
            "cook", "bake", "roast", "grill", "simmer", "boil", "fry", "sauté", 
            "chop", "dice", "slice", "mince", "whisk", "blend", "fold", "sprinkle",
            "drain", "strain", "rinse", "wash", "dry", "pat", "season", "marinate",
            "garnish", "serve", "prepare", "transfer", "remove", "set", "let", "allow",
            "cool", "chill", "refrigerate", "freeze", "thaw", "defrost", "melt", "dissolve"
        ]
        
        for verb in cookingVerbs {
            // Check for whole word match to avoid false positives
            let pattern = "\\b\(verb)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern),
               regex.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) != nil {
                return true
            }
        }
        
        return false
    }
    
    // Clean up an ingredient line
    private func cleanIngredientLine(_ line: String) -> String {
        var cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove bullet points and other common prefixes
        if cleaned.hasPrefix("•") || cleaned.hasPrefix("-") || cleaned.hasPrefix("*") || cleaned.hasPrefix("–") {
            cleaned = String(cleaned.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Remove any numbered prefixes like "1. " or "1) "
        let pattern = #"^\d+[\.\)]\s"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: cleaned, range: NSRange(location: 0, length: cleaned.utf16.count)) {
            let nsRange = match.range
            if let range = Range(nsRange, in: cleaned) {
                cleaned = String(cleaned[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Remove any OCR artifacts or special characters that shouldn't be in ingredients
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ") // Double spaces
        cleaned = cleaned.replacingOccurrences(of: " :", with: ":") // Space before colon
        
        // Capitalize first letter if it's not already
        if !cleaned.isEmpty {
            let firstChar = cleaned.prefix(1).uppercased()
            let restOfString = cleaned.dropFirst()
            cleaned = firstChar + restOfString
        }
        
        return cleaned
    }
    
    // Clean up an instruction line
    private func cleanInstructionLine(_ line: String) -> String {
        var cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove numbered prefixes like "1. " or "1) "
        let pattern = #"^\d+[\.\)]\s"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: cleaned, range: NSRange(location: 0, length: cleaned.utf16.count)) {
            let nsRange = match.range
            if let range = Range(nsRange, in: cleaned) {
                cleaned = String(cleaned[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Remove "Step X: " prefixes
        let stepPattern = #"^step\s*\d+:?\s"#
        if let regex = try? NSRegularExpression(pattern: stepPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: cleaned, range: NSRange(location: 0, length: cleaned.utf16.count)) {
            let nsRange = match.range
            if let range = Range(nsRange, in: cleaned) {
                cleaned = String(cleaned[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Remove any OCR artifacts or fix common OCR errors
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ") // Double spaces
        cleaned = cleaned.replacingOccurrences(of: " .", with: ".") // Space before period
        cleaned = cleaned.replacingOccurrences(of: " ,", with: ",") // Space before comma
        
        // Capitalize first letter if it's not already
        if !cleaned.isEmpty {
            let firstChar = cleaned.prefix(1).uppercased()
            let restOfString = cleaned.dropFirst()
            cleaned = firstChar + restOfString
        }
        
        // Make sure instruction ends with a period
        if !cleaned.isEmpty && !cleaned.hasSuffix(".") && !cleaned.hasSuffix("!") && !cleaned.hasSuffix("?") {
            cleaned += "."
        }
        
        return cleaned
    }

    private func saveRecipe() {
        print("=== COMPREHENSIVE SAVE RECIPE DEBUG ===")
        print("Title: '\(title)'")
        print("Ingredients count: \(ingredients.count)")
        print("Instructions count: \(instructions.count)")
        print("Selected image data: \(selectedImageData?.count ?? 0) bytes")
        print("Source URL: '\(sourceURL)'")
        print("selectedImageData memory address: \(Unmanaged.passUnretained(selectedImageData as AnyObject? ?? NSNull()).toOpaque())")
        
        // Create recipe entity
        let recipe = RecipeEntity(context: viewContext)
        recipe.id = UUID()
        recipe.title = title
        recipe.sourceURL = sourceURL
        recipe.dateAdded = Date()
        
        // Critical: Set image data BEFORE any other operations
        if let imageData = selectedImageData {
            print("🔍 About to set imageData on recipe entity...")
            print("🔍 Image data size: \(imageData.count) bytes")
            print("🔍 Image data first 10 bytes: \(Array(imageData.prefix(10)))")
            
            recipe.imageData = imageData
            
            // Immediately verify it was set
            if let savedImageData = recipe.imageData {
                print("✅ CONFIRMED: Recipe.imageData was set successfully. Size: \(savedImageData.count) bytes")
                print("✅ Verification: First 10 bytes match: \(Array(savedImageData.prefix(10)) == Array(imageData.prefix(10)))")
            } else {
                print("❌ CRITICAL ERROR: Recipe.imageData is nil immediately after setting!")
            }
        } else {
            print("❌ selectedImageData is nil - no image to save")
        }

        // Convert arrays to JSON strings
        if let ingredientsData = try? JSONEncoder().encode(ingredients.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            recipe.ingredientsString = String(data: ingredientsData, encoding: .utf8)
        }

        // Ensure instructions are always included, even if empty
        let filteredInstructions = instructions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let finalInstructions = filteredInstructions.isEmpty ? ["Instructions will be added later."] : filteredInstructions
        
        if let instructionsData = try? JSONEncoder().encode(finalInstructions) {
            recipe.instructionsString = String(data: instructionsData, encoding: .utf8)
        }

        if let tagsData = try? JSONEncoder().encode(tags.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            recipe.tagsString = String(data: tagsData, encoding: .utf8)
        }

        // Create searchable terms
        let searchableText = [title] + ingredients + tags
        recipe.searchTerms = searchableText.joined(separator: " ")
        
        // Save nutrition information
        recipe.setNutritionInfo(nutritionInfo)
        
        // Save meal type tags
        recipe.setMealTypes(selectedMealTypes)

        do {
            print("🔄 About to save to Core Data...")
            
            // Final verification before save
            if let imageData = recipe.imageData {
                print("🔍 Pre-save verification: Recipe has imageData of \(imageData.count) bytes")
            } else {
                print("❌ Pre-save verification: Recipe has NO imageData")
            }
            
            try viewContext.save()
            print("✅ Core Data save completed successfully!")
            
            // Post-save verification
            if let savedImageData = recipe.imageData {
                print("✅ POST-SAVE CONFIRMED: Recipe has image data: \(savedImageData.count) bytes")
                
                // Test if we can create UIImage from saved data
                if UIImage(data: savedImageData) != nil {
                    print("✅ Image data is valid - can create UIImage")
                } else {
                    print("❌ Image data is corrupted - cannot create UIImage")
                }
            } else {
                print("❌ POST-SAVE CRITICAL: Recipe has NO image data after save!")
            }
            
            // Force refresh the recipe manager to reload recipes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                RecipeManager.shared.loadRecipes()
                print("🔄 Forced recipe manager reload")
            }
            
            dismiss()
        } catch {
            print("❌ Core Data save failed: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
        }
    }
    
    // Helper function to generate nutrition info based on ingredients
    private func generateNutritionInfo(from ingredients: [String]) -> NutritionInfo {
        // Base values
        var calories: Double = 0
        var fat: Double = 0
        var carbs: Double = 0
        var protein: Double = 0
        
        // Filter out empty ingredients
        let filteredIngredients = ingredients.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        // If no ingredients, return default values
        guard !filteredIngredients.isEmpty else {
            return NutritionInfo.defaultValues
        }
        
        // Simple estimation based on ingredient count and keywords
        let ingredientCount = Double(filteredIngredients.count)
        
        // Base values per ingredient
        calories = 100 * ingredientCount
        fat = 3 * ingredientCount
        carbs = 12 * ingredientCount
        protein = 5 * ingredientCount
        
        // Adjust based on keywords in ingredients
        for ingredient in filteredIngredients {
            let lowercased = ingredient.lowercased()
            
            // High fat ingredients
            if lowercased.contains("oil") || lowercased.contains("butter") || 
               lowercased.contains("cream") || lowercased.contains("cheese") {
                fat += 5
                calories += 45
            }
            
            // High carb ingredients
            if lowercased.contains("sugar") || lowercased.contains("flour") || 
               lowercased.contains("rice") || lowercased.contains("pasta") || 
               lowercased.contains("bread") || lowercased.contains("potato") {
                carbs += 15
                calories += 60
            }
            
            // High protein ingredients
            if lowercased.contains("chicken") || lowercased.contains("beef") || 
               lowercased.contains("pork") || lowercased.contains("fish") || 
               lowercased.contains("egg") || lowercased.contains("tofu") || 
               lowercased.contains("bean") {
                protein += 10
                calories += 40
            }
        }
        
        // Normalize values to reasonable ranges
        calories = min(max(calories, 150), 1200)
        fat = min(max(fat, 3), 50)
        carbs = min(max(carbs, 10), 150)
        protein = min(max(protein, 5), 60)
        
        return NutritionInfo(
            calories: calories,
            fat: fat,
            carbs: carbs,
            protein: protein
        )
    }
}

struct AddRecipeView_Previews: PreviewProvider {
    static var previews: some View {
        AddRecipeView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
