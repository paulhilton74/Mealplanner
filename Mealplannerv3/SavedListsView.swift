import SwiftUI
import CoreData

struct SavedListsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var basketManager: ShoppingBasketManager
    @FetchRequest(
        entity: ShoppingList.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ShoppingList.createdAt, ascending: false)]
    ) private var savedLists: FetchedResults<ShoppingList>
    
    var body: some View {
        NavigationView {
            List {
                ForEach(savedLists) { list in
                    Button(action: {
                        basketManager.currentList = list
                        dismiss()
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(list.name ?? "Shopping List")
                                .font(.headline)
                            
                            if let date = list.createdAt {
                                Text(formatDate(date))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete { indexSet in
                    deleteList(at: indexSet)
                }
            }
            .navigationTitle("Saved Lists")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func deleteList(at indexSet: IndexSet) {
        let context = PersistenceController.shared.container.viewContext
        
        for index in indexSet {
            let list = savedLists[index]
            context.delete(list)
        }
        
        try? context.save()
    }
}