import SwiftUI

struct NutritionDial: View {
    let value: Double
    let maxValue: Double
    let unit: String
    let label: String
    let colorThresholds: (good: Double, ok: Double) // Thresholds for color coding
    
    // Determine color based on value and thresholds
    private var color: Color {
        if value <= colorThresholds.good {
            return .green
        } else if value <= colorThresholds.ok {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        VStack {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: 70, height: 70)
                
                // Value circle with color
                Circle()
                    .trim(from: 0, to: min(CGFloat(value / maxValue), 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))
                
                // Value text
                VStack(spacing: 0) {
                    Text("\(Int(value))")
                        .font(.system(size: 18, weight: .bold))
                    Text(unit)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct NutritionDialRow: View {
    let calories: Double
    let fat: Double
    let carbs: Double
    let protein: Double
    
    // Add initializer that accepts NutritionInfo
    init(nutritionInfo: NutritionInfo) {
        self.calories = nutritionInfo.calories
        self.fat = nutritionInfo.fat
        self.carbs = nutritionInfo.carbs
        self.protein = nutritionInfo.protein
    }
    
    // Original initializer
    init(calories: Double, fat: Double, carbs: Double, protein: Double) {
        self.calories = calories
        self.fat = fat
        self.carbs = carbs
        self.protein = protein
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Nutrition Facts (per serving)")
                .font(.headline)
                .padding(.bottom, 4)
            
            HStack(spacing: 16) {
                NutritionDial(
                    value: calories,
                    maxValue: 2500, // Daily recommended value
                    unit: "kcal",
                    label: "Calories",
                    colorThresholds: (good: 500, ok: 800)
                )
                
                NutritionDial(
                    value: fat,
                    maxValue: 70, // Daily recommended value
                    unit: "g",
                    label: "Fat",
                    colorThresholds: (good: 15, ok: 30)
                )
                
                NutritionDial(
                    value: carbs,
                    maxValue: 300, // Daily recommended value
                    unit: "g",
                    label: "Carbs",
                    colorThresholds: (good: 60, ok: 100)
                )
                
                NutritionDial(
                    value: protein,
                    maxValue: 50, // Daily recommended value
                    unit: "g",
                    label: "Protein",
                    colorThresholds: (good: 30, ok: 20) // For protein, higher is better
                )
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// Preview
struct NutritionDial_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            NutritionDialRow(
                calories: 450,
                fat: 12,
                carbs: 65,
                protein: 25
            )
            
            NutritionDialRow(
                calories: 850,
                fat: 35,
                carbs: 120,
                protein: 15
            )
        }
        .padding()
    }
} 