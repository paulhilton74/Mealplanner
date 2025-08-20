import SwiftUI

// MARK: - Meal Type Enum
enum MealType: String, CaseIterable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snacks = "Snacks"
    
    var displayName: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .breakfast:
            return "sunrise.fill"
        case .lunch:
            return "sun.max.fill"
        case .dinner:
            return "moon.fill"
        case .snacks:
            return "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .breakfast:
            return .orange
        case .lunch:
            return .yellow
        case .dinner:
            return .purple
        case .snacks:
            return .blue
        }
    }
    
    var lightColor: Color {
        switch self {
        case .breakfast:
            return .orange.opacity(0.2)
        case .lunch:
            return .yellow.opacity(0.2)
        case .dinner:
            return .purple.opacity(0.2)
        case .snacks:
            return .blue.opacity(0.2)
        }
    }
}

// MARK: - Meal Type Badge
struct MealTypeBadge: View {
    let mealType: MealType
    let size: BadgeSize
    
    enum BadgeSize {
        case small, medium, large
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 12
            case .large: return 14
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 10
            case .large: return 12
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
            case .medium: return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            case .large: return EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: mealType.icon)
                .font(.system(size: size.iconSize))
                .foregroundColor(mealType.color)
            
            Text(mealType.rawValue)
                .font(.system(size: size.fontSize, weight: .medium))
                .foregroundColor(mealType.color)
        }
        .padding(size.padding)
        .background(
            Capsule()
                .fill(mealType.lightColor)
                .overlay(
                    Capsule()
                        .stroke(mealType.color.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

// MARK: - Meal Type Selector
struct MealTypeSelector: View {
    @Binding var selectedMealType: MealType
    let style: SelectorStyle
    
    enum SelectorStyle {
        case segmented, grid, list
    }
    
    var body: some View {
        switch style {
        case .segmented:
            segmentedSelector
        case .grid:
            gridSelector
        case .list:
            listSelector
        }
    }
    
    private var segmentedSelector: some View {
        Picker("Meal Type", selection: $selectedMealType) {
            ForEach(MealType.allCases, id: \.self) { mealType in
                Text(mealType.rawValue).tag(mealType)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
    }
    
    private var gridSelector: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            ForEach(MealType.allCases, id: \.self) { mealType in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMealType = mealType
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: mealType.icon)
                            .font(.system(size: 24))
                            .foregroundColor(selectedMealType == mealType ? .white : mealType.color)
                        
                        Text(mealType.rawValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedMealType == mealType ? .white : mealType.color)
                    }
                    .frame(height: 70)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedMealType == mealType ? mealType.color : mealType.lightColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(mealType.color.opacity(0.5), lineWidth: selectedMealType == mealType ? 2 : 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var listSelector: some View {
        VStack(spacing: 8) {
            ForEach(MealType.allCases, id: \.self) { mealType in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMealType = mealType
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: mealType.icon)
                            .font(.system(size: 18))
                            .foregroundColor(mealType.color)
                            .frame(width: 24)
                        
                        Text(mealType.rawValue)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if selectedMealType == mealType {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(mealType.color)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedMealType == mealType ? mealType.lightColor : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(mealType.color.opacity(selectedMealType == mealType ? 0.5 : 0.2), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Meal Type Sheet
struct MealTypeSelectionSheet: View {
    @Binding var selectedMealType: MealType
    @Environment(\.dismiss) private var dismiss
    let onSelection: (MealType) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Select Meal Type")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                Text("Choose what type of meal this recipe is for")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                MealTypeSelector(selectedMealType: $selectedMealType, style: .grid)
                    .padding(.horizontal)
                
                Spacer()
                
                Button(action: {
                    onSelection(selectedMealType)
                    dismiss()
                }) {
                    Text("Add to \(selectedMealType.rawValue)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [selectedMealType.color, selectedMealType.color.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: selectedMealType.color.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Meal Type Filter
struct MealTypeFilter: View {
    @Binding var selectedFilter: MealType?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All meals button
                Button(action: {
                    withAnimation(.easeInOut) {
                        selectedFilter = nil
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 10))
                        Text("All")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(selectedFilter == nil ? Color.gray : Color.clear)
                            .overlay(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                            )
                    )
                    .foregroundColor(selectedFilter == nil ? .white : .gray)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Meal type buttons
                ForEach(MealType.allCases, id: \.self) { mealType in
                    Button(action: {
                        withAnimation(.easeInOut) {
                            selectedFilter = selectedFilter == mealType ? nil : mealType
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: mealType.icon)
                                .font(.system(size: 10))
                            Text(mealType.rawValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selectedFilter == mealType ? mealType.color : Color.clear)
                                .overlay(
                                    Capsule()
                                        .stroke(mealType.color.opacity(0.5), lineWidth: 1)
                                )
                        )
                        .foregroundColor(selectedFilter == mealType ? .white : mealType.color)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Extensions
extension MealType {
    init?(from string: String?) {
        guard let string = string else { return nil }
        self.init(rawValue: string)
    }
}

// MARK: - Preview
struct MealTypeComponents_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            // Badge examples
            HStack(spacing: 12) {
                MealTypeBadge(mealType: .breakfast, size: .small)
                MealTypeBadge(mealType: .lunch, size: .medium)
                MealTypeBadge(mealType: .dinner, size: .large)
            }
            
            // Selector examples
            MealTypeSelector(selectedMealType: .constant(.dinner), style: .segmented)
            
            MealTypeSelector(selectedMealType: .constant(.breakfast), style: .grid)
                .frame(height: 200)
            
            MealTypeFilter(selectedFilter: .constant(.lunch))
        }
        .padding()
    }
}
