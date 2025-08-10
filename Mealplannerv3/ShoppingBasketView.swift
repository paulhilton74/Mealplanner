import SwiftUI
import CoreData

class ShoppingBasketManager: ObservableObject {
    @Published var currentList: ShoppingList?
    
    func createNewList(name: String) -> ShoppingList {
        let context = PersistenceController.shared.container.viewContext
        let newList = ShoppingList(context: context)
        newList.id = UUID()
        newList.name = name
        newList.createdAt = Date()
        
        try? context.save()
        currentList = newList
        return newList
    }
    
    func addItem(name: String, quantity: Int, category: String) {
        guard let list = currentList else { return }
        
        let context = PersistenceController.shared.container.viewContext
        let newItem = ShoppingItem(context: context)
        newItem.id = UUID()
        newItem.name = name
        newItem.quantity = Int32(quantity)  // Changed from Int16 to Int32
        newItem.category = category.lowercased()
        newItem.isChecked = false
        newItem.list = list
        
        try? context.save()
    }
    
    func removeItem(_ item: ShoppingItem) {
        let context = PersistenceController.shared.container.viewContext
        context.delete(item)
        try? context.save()
    }
    
    func updateItemQuantity(_ item: ShoppingItem, quantity: Int) {
        item.quantity = Int32(quantity)  // Changed from Int16 to Int32
        try? PersistenceController.shared.container.viewContext.save()
    }
    
    func saveCurrentList() {
        try? PersistenceController.shared.container.viewContext.save()
    }
}

struct ShoppingBasketView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var basketManager: ShoppingBasketManager
    @State private var showingSavedLists = false
    @State private var newItemName = ""
    @State private var newItemQuantity = 1
    @State private var newItemCategory = "produce"
    
    let categories = ["produce", "dairy", "meat", "bakery", "pantry", "frozen", "other"]
    
    var body: some View {
        NavigationView {
            VStack {
                if let currentList = basketManager.currentList {
                    ShoppingListView(list: currentList)
                } else {
                    VStack(spacing: 20) {
                        Text("No Shopping List Selected")
                            .font(.headline)
                        
                        Button(action: {
                            _ = basketManager.createNewList(name: "Shopping List")
                        }) {
                            Text("Create New List")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            showingSavedLists = true
                        }) {
                            Text("Open Saved List")
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
                
                if basketManager.currentList != nil {
                    VStack {
                        HStack {
                            TextField("Item name", text: $newItemName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Stepper("\(newItemQuantity)", value: $newItemQuantity, in: 1...99)
                                .frame(width: 100)
                        }
                        
                        Picker("Category", selection: $newItemCategory) {
                            ForEach(categories, id: \.self) { category in
                                Text(category.capitalized).tag(category)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        Button(action: addItem) {
                            Text("Add Item")
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .disabled(newItemName.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("Shopping List")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if basketManager.currentList != nil {
                        Menu {
                            Button(action: {
                                basketManager.saveCurrentList()
                            }) {
                                Label("Save List", systemImage: "square.and.arrow.down")
                            }
                            
                            Button(action: {
                                showingSavedLists = true
                            }) {
                                Label("Open Saved List", systemImage: "folder")
                            }
                            
                            Button(action: {
                                basketManager.currentList = nil
                            }) {
                                Label("Close List", systemImage: "xmark")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSavedLists) {
                SavedListsView()
            }
        }
    }
    
    private func addItem() {
        basketManager.addItem(name: newItemName, quantity: newItemQuantity, category: newItemCategory)
        newItemName = ""
        newItemQuantity = 1
    }
}

struct ShoppingBasketView_Previews: PreviewProvider {
    static var previews: some View {
        ShoppingBasketView()
            .environmentObject(ShoppingBasketManager())
    }
}