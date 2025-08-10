import SwiftUI

@main
struct MealPlannerApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var basketManager = ShoppingBasketManager()
    @State private var incomingURL: URL?
    @State private var showingURLImport = false
    
    init() {
        // Run migration if needed
        RecipeModelMigration.migrateIfNeeded(context: persistenceController.container.viewContext)
    }
    
    var body: some Scene {
        WindowGroup {
            MainMenuView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(basketManager)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .sheet(isPresented: $showingURLImport) {
                    if let url = incomingURL {
                        URLImportView(url: url)
                    }
                }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        if url.scheme == "mealplanner" {
            // Handle custom scheme: mealplanner://import?url=https://example.com/recipe
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems,
               let urlString = queryItems.first(where: { $0.name == "url" })?.value,
               let recipeURL = URL(string: urlString) {
                incomingURL = recipeURL
                showingURLImport = true
            }
        } else if url.scheme == "http" || url.scheme == "https" {
            // Handle direct HTTP/HTTPS URLs
            incomingURL = url
            showingURLImport = true
        }
    }
}