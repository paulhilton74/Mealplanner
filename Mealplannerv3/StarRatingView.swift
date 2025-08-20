import SwiftUI

// MARK: - Interactive Star Rating View
struct StarRatingView: View {
    @Binding var rating: Float
    let maxRating: Int = 5
    let starSize: CGFloat
    let interactive: Bool
    
    init(rating: Binding<Float>, starSize: CGFloat = 24, interactive: Bool = true) {
        self._rating = rating
        self.starSize = starSize
        self.interactive = interactive
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { index in
                Button(action: {
                    if interactive {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            rating = Float(index)
                        }
                    }
                }) {
                    Image(systemName: starImageName(for: index))
                        .font(.system(size: starSize))
                        .foregroundColor(starColor(for: index))
                        .scaleEffect(interactive && isPressed(index) ? 1.2 : 1.0)
                }
                .disabled(!interactive)
                .buttonStyle(PlainButtonStyle())
            }
            
            if interactive && rating > 0 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        rating = 0
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: starSize * 0.8))
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func starImageName(for index: Int) -> String {
        let starValue = Float(index)
        
        if rating >= starValue {
            return "star.fill"
        } else if rating >= starValue - 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
    
    private func starColor(for index: Int) -> Color {
        let starValue = Float(index)
        
        if rating >= starValue {
            return .yellow
        } else if rating >= starValue - 0.5 {
            return .yellow
        } else {
            return .gray.opacity(0.3)
        }
    }
    
    private func isPressed(_ index: Int) -> Bool {
        // This would be used for press animation in a more complex implementation
        return false
    }
}

// MARK: - Display-Only Star Rating View
struct StarDisplayView: View {
    let rating: Float
    let starSize: CGFloat
    let showRatingText: Bool
    
    init(rating: Float, starSize: CGFloat = 16, showRatingText: Bool = false) {
        self.rating = rating
        self.starSize = starSize
        self.showRatingText = showRatingText
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: starImageName(for: index))
                    .font(.system(size: starSize))
                    .foregroundColor(starColor(for: index))
            }
            
            if showRatingText && rating > 0 {
                Text(String(format: "%.1f", rating))
                    .font(.system(size: starSize * 0.8, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.leading, 4)
            }
        }
    }
    
    private func starImageName(for index: Int) -> String {
        let starValue = Float(index)
        
        if rating >= starValue {
            return "star.fill"
        } else if rating >= starValue - 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
    
    private func starColor(for index: Int) -> Color {
        let starValue = Float(index)
        
        if rating >= starValue || rating >= starValue - 0.5 {
            return .yellow
        } else {
            return .gray.opacity(0.3)
        }
    }
}

// MARK: - Compact Star Rating (for lists)
struct CompactStarRating: View {
    let rating: Float
    let starSize: CGFloat = 12
    
    var body: some View {
        HStack(spacing: 1) {
            if rating > 0 {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: starImageName(for: index))
                        .font(.system(size: starSize))
                        .foregroundColor(.yellow)
                }
                Text(String(format: "%.1f", rating))
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.leading, 2)
            } else {
                Text("No rating")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func starImageName(for index: Int) -> String {
        let starValue = Float(index)
        
        if rating >= starValue {
            return "star.fill"
        } else if rating >= starValue - 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}

// MARK: - Rating Input Section (for recipe detail)
struct RatingInputSection: View {
    @Binding var rating: Float
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.circle")
                    .foregroundColor(.yellow)
                    .font(.title2)
                Text("Rating")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if rating > 0 {
                    StarDisplayView(rating: rating, starSize: 18, showRatingText: true)
                }
                
                Button(action: {
                    withAnimation(.easeInOut) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rate this recipe")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    StarRatingView(rating: $rating, starSize: 32, interactive: true)
                    
                    if rating > 0 {
                        Text(ratingDescription)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .italic()
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
    
    private var ratingDescription: String {
        switch rating {
        case 0..<1:
            return "Poor"
        case 1..<2:
            return "Below Average"
        case 2..<3:
            return "Average"
        case 3..<4:
            return "Good"
        case 4..<5:
            return "Excellent"
        case 5:
            return "Perfect!"
        default:
            return ""
        }
    }
}

// MARK: - Preview
struct StarRatingView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            // Interactive rating
            StarRatingView(rating: .constant(3.5), starSize: 30, interactive: true)
            
            // Display only
            StarDisplayView(rating: 4.2, starSize: 20, showRatingText: true)
            
            // Compact version
            CompactStarRating(rating: 3.8)
            
            // Rating input section
            RatingInputSection(rating: .constant(4.0))
        }
        .padding()
    }
}
