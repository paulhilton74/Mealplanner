import SwiftUI

struct MainMenuView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var basketManager = ShoppingBasketManager()
    @StateObject private var recipeManager = RecipeManager.shared
    @State private var todaysRecipes: [RecipeEntity] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    List {
                        NavigationLink(destination: ContentView().environment(\.managedObjectContext, viewContext)) {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                
                                VStack(alignment: .leading) {
                                    Text("Recipe Extractor")
                                        .font(.headline)
                                    Text("Extract recipes from websites")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        
                        NavigationLink(destination: SavedRecipesView().environment(\.managedObjectContext, viewContext)) {
                            HStack {
                                Image(systemName: "book.closed")
                                    .foregroundColor(.purple)
                                    .font(.title2)
                                
                                VStack(alignment: .leading) {
                                    Text("My Recipes")
                                        .font(.headline)
                                    Text("View and manage your saved recipes")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        
                        NavigationLink(destination: WeeklyPlanView()
                            .environment(\.managedObjectContext, viewContext)
                            .environmentObject(basketManager)) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.green)
                                    .font(.title2)
                                
                                VStack(alignment: .leading) {
                                    Text("Weekly Meal Planner")
                                        .font(.headline)
                                    Text("Plan your meals for the week")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        
                        NavigationLink(destination: ShoppingBasketView()
                            .environment(\.managedObjectContext, viewContext)
                            .environmentObject(basketManager)) {
                            HStack {
                                Image(systemName: "cart")
                                    .foregroundColor(.orange)
                                    .font(.title2)
                                
                                VStack(alignment: .leading) {
                                    Text("Shopping List")
                                        .font(.headline)
                                    Text("Generate shopping lists from your meal plan")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .frame(height: 400)
                    
                    // Today's Meals Section
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Today's Meals")
                                .font(.title2)
                                .bold()
                            
                            Spacer()
                            
                            Text(currentDayOfWeek())
                                .font(.headline)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        
                        if todaysRecipes.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "fork.knife")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                
                                Text("No meals planned for today")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                NavigationLink(destination: WeeklyPlanView()
                                    .environment(\.managedObjectContext, viewContext)
                                    .environmentObject(basketManager)) {
                                    Text("Add meals to today's plan")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    ForEach(todaysRecipes, id: \.id) { recipe in
                                        NavigationLink(destination: RecipeDetailView(recipe: recipe)
                                            .environment(\.managedObjectContext, viewContext)) {
                                            VStack(alignment: .leading) {
                                                if let imageData = recipe.imageData, let uiImage = UIImage(data: imageData) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 160, height: 120)
                                                        .cornerRadius(10)
                                                } else {
                                                    Image(systemName: "photo")
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .padding()
                                                        .frame(width: 160, height: 120)
                                                        .background(Color.gray.opacity(0.2))
                                                        .cornerRadius(10)
                                                }
                                                
                                                Text(recipe.title ?? "Untitled Recipe")
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                    .lineLimit(2)
                                                    .frame(width: 160, alignment: .leading)
                                                
                                                if let ingredients = recipe.getIngredients(), !ingredients.isEmpty {
                                                    Text("\(ingredients.count) ingredients")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            .frame(width: 160)
                                            .padding(.bottom, 5)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.top, 10)
                }
            }
            .navigationTitle("Meal Planner")
            .onAppear {
                loadTodaysRecipes()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func currentDayOfWeek() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE" // Full day name
        return formatter.string(from: Date())
    }
    
    private func loadTodaysRecipes() {
        recipeManager.loadWeeklyPlan()
        let today = currentDayOfWeek()
        todaysRecipes = recipeManager.getRecipesForDay(today)
    }
}

struct MainMenuView_Previews: PreviewProvider {
    static var previews: some View {
        MainMenuView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}