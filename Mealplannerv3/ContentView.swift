import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var recipeUrl: String = ""
    @State private var isLoading: Bool = false
    @State private var extractedRecipe: (title: String, ingredients: [String], instructions: [String], images: [String])? = nil
    @State private var showingSaveAlert = false
    @State private var saveSuccess = false
    @State private var errorMessage = ""
    @State private var tags: [String] = [""]
    @State private var showingTagsSection = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isImageExtractionMode = false
    @State private var showingAPITestAlert = false
    @State private var apiTestMessage = ""
    @State private var apiTestSuccess = false
    @State private var showingRawTextSheet = false
    
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var recipeManager = RecipeManager.shared
    
    // Add the recipe extractor service
    private let recipeExtractorService = RecipeExtractorService()
    private let googleCloudVisionService = GoogleCloudVisionService()
    
    private let extractors: [RecipeExtractor] = [
        JSONLDExtractor(),
        MicrodataExtractor()
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                // Toggle between URL and Image extraction modes
                Picker("Extraction Method", selection: $isImageExtractionMode) {
                    Text("URL").tag(false)
                    Text("Image").tag(true)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                if !isImageExtractionMode {
                    // URL extraction UI
                    TextField("Enter recipe URL", text: $recipeUrl)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    
                    Button(action: extractRecipe) {
                        Text("Extract Recipe")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(isLoading || recipeUrl.isEmpty)
                } else {
                    // Image extraction UI
                    VStack {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            if let selectedImageData,
                               let uiImage = UIImage(data: selectedImageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 200)
                            } else {
                                Label("Select Recipe Image", systemImage: "photo")
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                        .onChange(of: selectedItem) { _, newValue in
                            Task {
                                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                    selectedImageData = data
                                }
                            }
                        }
                        
                        if let _ = selectedImageData {
                            Button(action: extractRecipeFromImage) {
                                Text("Extract Recipe from Image")
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .disabled(isLoading)
                        }
                        
                        // Add API Test button
                        Button(action: testAPIConnection) {
                            Text("Test Google Cloud Vision API")
                                .padding()
                                .background(Color.green.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(.top, 8)
                    }
                }
                
                if isLoading {
                    ProgressView()
                        .padding()
                }
                
                if let recipe = extractedRecipe {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(recipe.title)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            if !recipe.images.isEmpty, let imageUrl = URL(string: recipe.images[0]) {
                                AsyncImage(url: imageUrl) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                    case .failure:
                                        Image(systemName: "photo")
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .frame(height: 200)
                            }
                            
                            Text("Ingredients")
                                .font(.headline)
                            
                            ForEach(recipe.ingredients, id: \.self) { ingredient in
                                Text("• \(ingredient)")
                            }
                            
                            Text("Instructions")
                                .font(.headline)
                            
                            if recipe.instructions.isEmpty {
                                Text("No instructions found")
                                    .foregroundColor(.red)
                                    .italic()
                            } else {
                                ForEach(Array(recipe.instructions.enumerated()), id: \.element) { index, instruction in
                                    Text("\(index + 1). \(instruction)")
                                        .padding(.bottom, 4)
                                }
                            }
                            
                            // Tags section
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Tags")
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        showingTagsSection.toggle()
                                    }) {
                                        Image(systemName: showingTagsSection ? "chevron.up" : "chevron.down")
                                    }
                                }
                                
                                if showingTagsSection {
                                    Text("Add tags to help organize your recipes (e.g., 'Kids', 'Vegetarian', 'Quick')")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    ForEach(0..<tags.count, id: \.self) { index in
                                        HStack {
                                            TextField("Tag \(index + 1)", text: $tags[index])
                                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                            
                                            if tags.count > 1 {
                                                Button(action: {
                                                    tags.remove(at: index)
                                                }) {
                                                    Image(systemName: "minus.circle.fill")
                                                        .foregroundColor(.red)
                                                }
                                            }
                                        }
                                    }
                                    
                                    Button(action: {
                                        tags.append("")
                                    }) {
                                        Label("Add Tag", systemImage: "plus.circle")
                                    }
                                    .padding(.top, 4)
                                } else {
                                    let validTags = tags.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                                    if !validTags.isEmpty {
                                        HStack {
                                            ForEach(validTags, id: \.self) { tag in
                                                Text(tag)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.blue.opacity(0.2))
                                                    .cornerRadius(8)
                                            }
                                        }
                                    } else {
                                        Text("No tags added")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .italic()
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                            
                            // Add save button
                            Button(action: saveRecipe) {
                                Text("Save Recipe")
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .padding(.top, 20)
                            
                            // Add button to show raw text
                            if isImageExtractionMode {
                                Button(action: {
                                    showingRawTextSheet = true
                                }) {
                                    Text("Show Raw Extracted Text")
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.orange)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding()
                    }
                    .sheet(isPresented: $showingRawTextSheet) {
                        RawTextView(rawText: googleCloudVisionService.getLastExtractedRawText())
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Recipe Extractor")
            .alert(isPresented: $showingSaveAlert) {
                Alert(
                    title: Text(saveSuccess ? "Success" : "Error"),
                    message: Text(saveSuccess ? "Recipe saved successfully" : "Failed to save recipe: \(errorMessage)"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert("API Connection Test", isPresented: $showingAPITestAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(apiTestMessage)
            }
        }
    }
    
    private func testAPIConnection() {
        isLoading = true
        
        Task {
            let result = await googleCloudVisionService.testAPIConnection()
            
            await MainActor.run {
                isLoading = false
                apiTestSuccess = result.success
                apiTestMessage = result.message
                showingAPITestAlert = true
            }
        }
    }
    
    private func extractRecipe() {
        guard let url = URL(string: recipeUrl) else { return }
        
        isLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let html = String(data: data, encoding: .utf8) else {
                    isLoading = false
                    return
                }
                
                for extractor in extractors {
                    if let recipe = await extractor.parse(html: html, from: url) {
                        await MainActor.run {
                            extractedRecipe = recipe
                            isLoading = false
                        }
                        return
                    }
                }
                
                // If no extractors worked, show an error
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Could not extract recipe from this URL. Please try a different URL or enter the recipe manually."
                    showingSaveAlert = true
                }
            } catch {
                print("Error: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func extractRecipeFromImage() {
        guard let imageData = selectedImageData else { return }
        
        isLoading = true
        
        Task {
            do {
                // Try to extract the recipe
                let recipe = try await recipeExtractorService.extractRecipeFromImage(imageData)
                
                // Update UI on main thread
                await MainActor.run {
                    // Convert Recipe object to the tuple format expected by the UI
                    extractedRecipe = (
                        title: recipe.title,
                        ingredients: recipe.ingredients,
                        instructions: recipe.instructions,
                        images: recipe.images ?? []
                    )
                    isLoading = false
                    
                    // Check if we got meaningful data
                    let hasRealIngredients = recipe.ingredients.count > 1 || 
                                           (recipe.ingredients.count == 1 && 
                                            !recipe.ingredients[0].contains("No ingredients detected"))
                    
                    let hasRealInstructions = recipe.instructions.count > 1 || 
                                            (recipe.instructions.count == 1 && 
                                             !recipe.instructions[0].contains("No instructions detected"))
                    
                    // Show a helpful message if extraction was partial
                    if !hasRealIngredients || !hasRealInstructions {
                        errorMessage = "The recipe was only partially extracted. You may need to edit it manually. Try using the 'Show Raw Extracted Text' button to see what text was detected."
                        showingSaveAlert = true
                    }
                }
            } catch let error as VisionAPIError {
                print("Vision API Error: \(error)")
                
                // Update UI on main thread with a placeholder recipe and specific error message
                await MainActor.run {
                    extractedRecipe = (
                        title: "Recipe from Image",
                        ingredients: ["No ingredients could be extracted. Please edit manually."],
                        instructions: ["No instructions could be extracted. Please edit manually."],
                        images: []
                    )
                    isLoading = false
                    
                    // Set specific error message based on the error type
                    switch error {
                    case .apiError(let message):
                        errorMessage = "API Error: \(message)"
                        if message.contains("SERVICE_DISABLED") || message.contains("not been used") || message.contains("is disabled") {
                            errorMessage = "The Google Cloud Vision API is not enabled for this project. Please enable it in the Google Cloud Console and ensure billing is enabled for your project. Note that it may take a few minutes for changes to propagate."
                        } else if message.contains("billing") {
                            errorMessage = "Billing is not enabled for the Google Cloud project. Please enable billing in the Google Cloud Console by visiting https://console.cloud.google.com/billing and linking your project to a billing account."
                        }
                    case .noTextFound:
                        errorMessage = "No text could be detected in the image. Please try a clearer photo, adjust the lighting, or enter the recipe manually."
                    case .invalidResponse, .invalidURL:
                        errorMessage = "There was a problem with the API request. Please try again later."
                    case .decodingError:
                        errorMessage = "Could not process the API response. Please try again later."
                    case .networkError:
                        errorMessage = "Network error. Please check your internet connection and try again."
                    }
                    
                    showingSaveAlert = true
                }
            } catch {
                print("Error extracting recipe from image: \(error)")
                
                // Update UI on main thread with a placeholder recipe
                await MainActor.run {
                    // Still show the recipe editor even if extraction failed
                    extractedRecipe = (
                        title: "Recipe from Image",
                        ingredients: ["No ingredients could be extracted. Please edit manually."],
                        instructions: ["No instructions could be extracted. Please edit manually."],
                        images: []
                    )
                    isLoading = false
                    errorMessage = "Could not extract recipe details from the image. You can still manually edit the recipe or try the 'Show Raw Extracted Text' button to see what text was detected."
                    showingSaveAlert = true
                }
            }
        }
    }
    
    private func saveRecipe() {
        guard let recipe = extractedRecipe else { return }
        
        // Filter out empty tags
        let validTags = tags.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        // Save the recipe
        recipeManager.saveRecipe(
            title: recipe.title,
            ingredients: recipe.ingredients,
            instructions: recipe.instructions,
            tags: validTags,
            imageData: selectedImageData,
            sourceURL: recipeUrl
        )
        
        saveSuccess = true
        errorMessage = ""
        showingSaveAlert = true
    }
}

// Add a view to display the raw text
struct RawTextView: View {
    let rawText: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Raw Text Extracted from Image")
                        .font(.headline)
                        .padding(.bottom, 8)
                    
                    Text("This is the unprocessed text as returned by the Google Cloud Vision API:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.bottom, 16)
                    
                    Text(rawText)
                        .font(.body)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    
                    Text("If the text above doesn't match what you see in the image, try taking a clearer photo or adjusting the lighting.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 16)
                }
                .padding()
            }
            .navigationTitle("Raw Extracted Text")
            .navigationBarItems(trailing: Button("Close") {
                dismiss()
            })
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}