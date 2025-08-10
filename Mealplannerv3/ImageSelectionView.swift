import SwiftUI

struct ImageSelectionView: View {
    let images: [(url: URL, title: String?)]
    @Binding var selectedImageData: Data?
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading images...")
                } else if let error = errorMessage {
                    VStack {
                        Text("Error loading images")
                            .font(.headline)
                        Text(error)
                            .foregroundColor(.red)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                            ForEach(images, id: \.url) { image in
                                ImageSelectionCell(imageURL: image.url, title: image.title) { imageData in
                                    selectedImageData = imageData
                                    dismiss()
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Select Recipe Image")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ImageSelectionCell: View {
    let imageURL: URL
    let title: String?
    let onSelect: (Data) -> Void
    
    @State private var imageData: Data?
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        VStack {
            if let imageData = imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 150)
                    .clipped()
                    .cornerRadius(8)
                    .onTapGesture {
                        onSelect(imageData)
                    }
                if let title = title {
                    Text(title)
                        .font(.caption)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            } else if isLoading {
                ProgressView()
                    .frame(height: 150)
            } else if error != nil {
                Image(systemName: "exclamationmark.triangle")
                    .frame(height: 150)
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        isLoading = true
        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            imageData = data
        } catch {
            self.error = error
        }
        isLoading = false
    }
}
