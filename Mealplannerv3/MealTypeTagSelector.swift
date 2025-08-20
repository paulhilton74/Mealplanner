import SwiftUI

struct MealTypeTagSelector: View {
    @Binding var selectedMealTypes: Set<MealType>
    let title: String
    let showTitle: Bool
    
    init(selectedMealTypes: Binding<Set<MealType>>, title: String = "Meal Types", showTitle: Bool = true) {
        self._selectedMealTypes = selectedMealTypes
        self.title = title
        self.showTitle = showTitle
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showTitle {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(MealType.allCases, id: \.self) { mealType in
                    MealTypeToggleButton(
                        mealType: mealType,
                        isSelected: selectedMealTypes.contains(mealType)
                    ) {
                        toggleMealType(mealType)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func toggleMealType(_ mealType: MealType) {
        if selectedMealTypes.contains(mealType) {
            selectedMealTypes.remove(mealType)
        } else {
            selectedMealTypes.insert(mealType)
        }
    }
}

struct MealTypeToggleButton: View {
    let mealType: MealType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: mealType.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : mealType.color)
                
                Text(mealType.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? mealType.color : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(mealType.color, lineWidth: isSelected ? 0 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    struct PreviewWrapper: View {
        @State private var selectedMealTypes: Set<MealType> = [.breakfast, .lunch]
        
        var body: some View {
            VStack {
                MealTypeTagSelector(selectedMealTypes: $selectedMealTypes)
                
                Text("Selected: \(selectedMealTypes.map { $0.displayName }.joined(separator: ", "))")
                    .padding()
            }
            .padding()
        }
    }
    
    return PreviewWrapper()
}
