import SwiftUI
import PhotosUI

struct EditFridgeItemView: View {
    let item: FridgeItem
    @Environment(\.dismiss) private var dismiss
    @StateObject private var fridgeManager = FridgeManager.shared
    
    @State private var itemName = ""
    @State private var expiryDate = Date()
    @State private var selectedCategory = FridgeManager.categories[0]
    @State private var notes = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var capturedImageData: Data?
    @State private var showingCamera = false
    @State private var showingImagePicker = false
    @State private var isProcessingImage = false
    @State private var extractedDates: [Date] = []
    @State private var selectedExtractedDate: Date?
    @State private var showingDateExtraction = false
    @State private var isSaving = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Image Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Product Image")
                            .font(.headline)
                        
                        if let imageData = capturedImageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 150)
                                .cornerRadius(12)
                                .overlay(
                                    VStack {
                                        Image(systemName: "photo")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                        Text("No image")
                                            .foregroundColor(.gray)
                                    }
                                )
                        }
                        
                        VStack(spacing: 12) {
                            PhotosPicker(
                                selection: $selectedImage,
                                matching: .images,
                                preferredItemEncoding: .current
                            ) {
                                HStack {
                                    Image(systemName: "camera.fill")
                                    Text("Take Photo or Choose from Library")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            
                            PhotosPicker(selection: $selectedImage, matching: .images, photoLibrary: .shared()) {
                                HStack {
                                    Image(systemName: "photo.on.rectangle")
                                    Text("Gallery")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            
                            if capturedImageData != nil {
                                Button(action: {
                                    capturedImageData = nil
                                    extractedDates = []
                                }) {
                                    HStack {
                                        Image(systemName: "trash")
                                        Text("Remove")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                            }
                        }
                        
                        if isProcessingImage {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Extracting dates from image...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Extracted dates section
                        if !extractedDates.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Dates found in image:")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                ForEach(extractedDates, id: \.self) { date in
                                    Button(action: {
                                        selectedExtractedDate = date
                                        expiryDate = date
                                        showingDateExtraction = false
                                    }) {
                                        HStack {
                                            Text(date, formatter: dateFormatter)
                                                .font(.subheadline)
                                            
                                            Spacer()
                                            
                                            if selectedExtractedDate == date {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                            } else {
                                                Image(systemName: "circle")
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Item Details Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Item Details")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name *")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextField("Enter item name", text: $itemName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Picker("Category", selection: $selectedCategory) {
                                ForEach(FridgeManager.categories, id: \.self) { category in
                                    Text(category).tag(category)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Expiry Date *")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            DatePicker("", selection: $expiryDate, displayedComponents: .date)
                                .datePickerStyle(CompactDatePickerStyle())
                                .labelsHidden()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextEditor(text: $notes)
                                .frame(height: 80)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        // Status Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Status")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 12, height: 12)
                                
                                Text(statusText)
                                    .font(.subheadline)
                                    .foregroundColor(statusColor)
                            }
                            .padding()
                            .background(statusColor.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            showingDeleteAlert = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        
                        Button("Save") {
                            saveItem()
                        }
                        .disabled(itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                        .fontWeight(.semibold)
                    }
                }
            }
            .onChange(of: selectedImage) { _, newValue in
                if let newValue = newValue {
                    Task {
                        if let data = try? await newValue.loadTransferable(type: Data.self) {
                            await MainActor.run {
                                capturedImageData = data
                                Task.detached {
                                    await processImageForDates(data)
                                }
                            }
                        }
                    }
                }
            }
            .alert("Delete Item", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    fridgeManager.deleteFridgeItem(item)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this item? This action cannot be undone.")
            }
            .onAppear {
                loadItemData()
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    private var statusColor: Color {
        switch item.expiryStatus {
        case .expired:
            return .red
        case .expiresToday:
            return .orange
        case .expiresTomorrow:
            return .yellow
        case .expiresSoon:
            return .blue
        case .fresh:
            return .green
        }
    }
    
    private var statusText: String {
        return item.statusText
    }
    
    private func loadItemData() {
        itemName = item.displayName
        expiryDate = item.expiryDate ?? Date()
        selectedCategory = item.category ?? FridgeManager.categories[0]
        notes = item.notes ?? ""
        capturedImageData = item.imageData
    }
    
    private func processImageForDates(_ imageData: Data) async {
        await MainActor.run {
            isProcessingImage = true
        }
        
        do {
            let dates = try await fridgeManager.extractDatesFromImage(imageData)
            await MainActor.run {
                self.extractedDates = dates
                self.isProcessingImage = false
                if !dates.isEmpty {
                    self.showingDateExtraction = true
                }
            }
        } catch {
            await MainActor.run {
                self.isProcessingImage = false
                print("Error extracting dates: \(error)")
            }
        }
    }
    
    private func saveItem() {
        guard !itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSaving = true
        
        fridgeManager.updateFridgeItem(
            item,
            name: itemName.trimmingCharacters(in: .whitespacesAndNewlines),
            expiryDate: expiryDate,
            category: selectedCategory,
            imageData: capturedImageData,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        )
        
        isSaving = false
        dismiss()
    }
}

#Preview {
    EditFridgeItemView(item: FridgeItem())
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}