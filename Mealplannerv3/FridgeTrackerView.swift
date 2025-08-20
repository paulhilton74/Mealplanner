import SwiftUI

struct FridgeTrackerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var fridgeManager = FridgeManager.shared
    @State private var showingAddItemSheet = false
    @State private var selectedCategory = "All"
    @State private var showingExpiringAlert = false
    @State private var selectedItem: FridgeItem?
    @State private var showingEditSheet = false
    
    private let categories = ["All"] + FridgeManager.categories
    
    var body: some View {
        NavigationView {
            VStack {
                // Expiring Items Alert
                if fridgeManager.getExpiringItemsCount() > 0 {
                    ExpiringItemsAlert(count: fridgeManager.getExpiringItemsCount()) {
                        showingExpiringAlert = true
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            Button(action: {
                                selectedCategory = category
                            }) {
                                Text(category)
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == category ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedCategory == category ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                // Items List
                if filteredItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "refrigerator")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No items in your fridge")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Add items to track their expiration dates")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            showingAddItemSheet = true
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add First Item")
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredItems, id: \.id) { item in
                            FridgeItemRow(item: item) {
                                selectedItem = item
                                showingEditSheet = true
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Fridge Tracker")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddItemSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddItemSheet) {
                AddFridgeItemView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingEditSheet) {
                if let item = selectedItem {
                    EditFridgeItemView(item: item)
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            .alert("Expiring Items", isPresented: $showingExpiringAlert) {
                Button("OK") { }
            } message: {
                Text(expiringItemsMessage)
            }
            .onAppear {
                fridgeManager.loadFridgeItems()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private var filteredItems: [FridgeItem] {
        if selectedCategory == "All" {
            return fridgeManager.fridgeItems
        } else {
            return fridgeManager.fridgeItems.filter { $0.category == selectedCategory }
        }
    }
    
    private var expiringItemsMessage: String {
        let expiredCount = fridgeManager.expiringItems.filter { $0.isExpired }.count
        let expiringSoonCount = fridgeManager.expiringItems.filter { !$0.isExpired }.count
        
        var message = ""
        if expiredCount > 0 {
            message += "\(expiredCount) item(s) have expired.\n"
        }
        if expiringSoonCount > 0 {
            message += "\(expiringSoonCount) item(s) expire soon."
        }
        
        return message.isEmpty ? "Check your fridge items." : message
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredItems[$0] }.forEach(fridgeManager.deleteFridgeItem)
        }
    }
}

struct FridgeItemRow: View {
    let item: FridgeItem
    let onTap: () -> Void
    @State private var showingMealPlanOptions = false
    @State private var showingDayPicker = false
    @State private var showingDatePicker = false
    @State private var selectedDate = Date()
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack {
                    // Image
                    if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                    } else {
                        Image(systemName: "photo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding()
                            .frame(width: 60, height: 60)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(item.category ?? "Other")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let expiryDate = item.expiryDate {
                            Text("Expires: \(expiryDate, formatter: dateFormatter)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        // Status indicator
                        Circle()
                            .fill(statusColor(for: item))
                            .frame(width: 12, height: 12)
                        
                        Text(item.statusText)
                            .font(.caption2)
                            .foregroundColor(statusColor(for: item))
                            .multilineTextAlignment(.trailing)
                        
                        // Meal planner button
                        Button(action: {
                            showingMealPlanOptions = true
                        }) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Meal plan options
            if showingMealPlanOptions {
                VStack(spacing: 8) {
                    Divider()
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            showingDayPicker = true
                        }) {
                            Label("Add to Weekly Plan", systemImage: "calendar")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            showingDatePicker = true
                        }) {
                            Label("Add to Date", systemImage: "calendar.badge.plus")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            FridgeManager.shared.createRecipeFromFridgeItem(item)
                            showingMealPlanOptions = false
                        }) {
                            Label("Create Recipe", systemImage: "book")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.1))
                                .foregroundColor(.orange)
                                .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showingMealPlanOptions = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(Color.gray.opacity(0.05))
            }
        }
        .sheet(isPresented: $showingDayPicker) {
            DayPickerView(item: item) {
                showingMealPlanOptions = false
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerView(item: item, selectedDate: $selectedDate) {
                showingMealPlanOptions = false
            }
        }
    }
    
    private func statusColor(for item: FridgeItem) -> Color {
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
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}

struct ExpiringItemsAlert: View {
    let count: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading) {
                    Text("Items Expiring Soon!")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(count) item(s) need your attention")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DayPickerView: View {
    let item: FridgeItem
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    
    var body: some View {
        NavigationView {
            List(days, id: \.self) { day in
                Button(action: {
                    FridgeManager.shared.addFridgeItemToWeeklyPlan(item, day: day)
                    onComplete()
                    dismiss()
                }) {
                    Text(day)
                        .foregroundColor(.primary)
                }
            }
            .navigationTitle("Select Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DatePickerView: View {
    let item: FridgeItem
    @Binding var selectedDate: Date
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select a date to add \(item.displayName) to your meal plan")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()
                
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()
                
                Button(action: {
                    FridgeManager.shared.addFridgeItemToMealPlan(item, date: selectedDate)
                    onComplete()
                    dismiss()
                }) {
                    Text("Add to Meal Plan")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Add to Meal Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    FridgeTrackerView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}