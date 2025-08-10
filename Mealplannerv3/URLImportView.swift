import SwiftUI

struct URLImportView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recipeManager = RecipeManager.shared
    
    @State private var isLoading = true
    @State private var extractedRecipe: (title: String, ingredients: [String], instructions: [String], images: [(url: URL, title: String?)])? = nil
    @State private var errorMessage: String? = nil
    @State private var selectedTags: Set<String> = []
    @State private var customTag: String = ""
    @State private var showingCustomTagField = false
    @State private var isSaving = false
    @State private var downloadedImageData: Data? = nil
    
    private let availableTags = [
        "Breakfast", "Lunch", "Dinner", "Snack", "Dessert",
        "Vegetarian", "Vegan", "Gluten-Free", "Dairy-Free",
        "Quick", "Easy", "Healthy", "Comfort Food"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Extracting recipe from URL...")
                                .font(.headline)
                            Text(url.absoluteString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                    } else if let error = errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                            Text("Failed to Extract Recipe")
                                .font(.headline)
                            Text(error)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                    } else if let recipe = extractedRecipe {
                        // Recipe content
                        VStack(alignment: .leading, spacing: 20) {
                            // Image
                            if let imageData = downloadedImageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 200)
                                    .cornerRadius(12)
                            }
                            
                            // Title
                            Text(recipe.title)
                                .font(.title)
                                .bold()
                            
                            // Tags section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Tags")
                                    .font(.headline)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                    ForEach(availableTags, id: \.self) { tag in
                                        Button(action: {
                                            if selectedTags.contains(tag) {
                                                selectedTags.remove(tag)
                                            } else {
                                                selectedTags.insert(tag)
                                            }
                                        }) {
                                            Text(tag)
                                                .font(.caption)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(selectedTags.contains(tag) ? Color.blue : Color.gray.opacity(0.2))
                                                .foregroundColor(selectedTags.contains(tag) ? .white : .primary)
                                                .cornerRadius(16)
                                        }
                                    }
                                }
                                
                                // Custom tag input
                                HStack {
                                    if showingCustomTagField {
                                        TextField("Custom tag", text: $customTag)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .onSubmit {
                                                if !customTag.isEmpty {
                                                    selectedTags.insert(customTag)
                                                    customTag = ""
                                                    showingCustomTagField = false
                                                }
                                            }
                                    }
                                    
                                    Button(action: {
                                        if showingCustomTagField && !customTag.isEmpty {
                                            selectedTags.insert(customTag)
                                            customTag = ""
                                            showingCustomTagField = false
                                        } else {
                                            showingCustomTagField.toggle()
                                        }
                                    }) {
                                        Text(showingCustomTagField ? "Add" : "Add Custom Tag")
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.green)
                                            .foregroundColor(.white)
                                            .cornerRadius(16)
                                    }
                                }
                            }
                            
                            // Ingredients
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Ingredients")
                                    .font(.headline)
                                
                                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                                    Text("• \(ingredient)")
                                        .font(.body)
                                }
                            }
                            
                            // Instructions
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Instructions")
                                    .font(.headline)
                                
                                ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                                    Text("\(index + 1). \(instruction)")
                                        .font(.body)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Import Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if extractedRecipe != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: saveRecipe) {
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("Save")
                                    .bold()
                            }
                        }
                        .disabled(isSaving)
                    }
                }
            }
        }
        .onAppear {
            extractRecipe()
        }
    }
    
    private func extractRecipe() {
        Task {
            do {
                isLoading = true
                errorMessage = nil
                
                let result = try await recipeManager.extractRecipeFromURL(url.absoluteString)
                
                await MainActor.run {
                    self.extractedRecipe = result
                    
                    // Download image if available
                    if let firstImage = result.images.first {
                        downloadImage(from: firstImage.url)
                    }
                    
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func downloadImage(from url: URL) {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                await MainActor.run {
                    self.downloadedImageData = data
                }
            } catch {
                print("Failed to download image: \(error)")
            }
        }
    }
    
    private func saveRecipe() {
        guard let recipe = extractedRecipe else { return }
        
        isSaving = true
        
        let tagsArray = Array(selectedTags)
        
        recipeManager.saveRecipe(
            title: recipe.title,
            ingredients: recipe.ingredients,
            instructions: recipe.instructions,
            tags: tagsArray,
            imageData: downloadedImageData
        )
        
        isSaving = false
        dismiss()
    }
}

#Preview {
    URLImportView(url: URL(string: "https://example.com/recipe")!)
}
