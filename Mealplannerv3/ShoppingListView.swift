import SwiftUI
import CoreData

struct ShoppingListView: View {
    let list: ShoppingList
    @EnvironmentObject var basketManager: ShoppingBasketManager
    @State private var editingItem: ShoppingItem?
    
    var sortedItems: [String: [ShoppingItem]] {
        Dictionary(grouping: list.itemsArray) { item in
            item.category ?? "other"
        }
    }
    
    var body: some View {
        List {
            ForEach(Array(sortedItems.keys.sorted()), id: \.self) { category in
                Section(header: Text(category.capitalized)) {
                    ForEach(sortedItems[category] ?? []) { item in
                        HStack {
                            Button(action: {
                                item.isChecked.toggle()
                                try? PersistenceController.shared.container.viewContext.save()
                            }) {
                                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isChecked ? .green : .gray)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(item.name ?? "")
                                    .strikethrough(item.isChecked)
                                Text("Quantity: \(item.quantity)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                editingItem = item
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            if let item = sortedItems[category]?[index] {
                                basketManager.removeItem(item)
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $editingItem) { item in
            EditItemView(item: item)
                .environmentObject(basketManager)
        }
    }
}

struct EditItemView: View {
    let item: ShoppingItem
    @EnvironmentObject var basketManager: ShoppingBasketManager
    @Environment(\.dismiss) private var dismiss
    @State private var quantity: Int
    
    init(item: ShoppingItem) {
        self.item = item
        _quantity = State(initialValue: Int(item.quantity))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 0...99)
                }
            }
            .navigationTitle("Edit \(item.name ?? "")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        basketManager.updateItemQuantity(item, quantity: quantity)
                        dismiss()
                    }
                }
            }
        }
    }
}