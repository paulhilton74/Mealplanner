import SwiftUI

struct TestView: View {
    var body: some View {
        VStack {
            Text("Hello, Mealplannerv3!")
                .font(.largeTitle)
                .padding()
            
            Text("If you can see this, the app is working correctly.")
                .padding()
            
            Button("Test Button") {
                print("Button tapped!")
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
}

struct TestView_Previews: PreviewProvider {
    static var previews: some View {
        TestView()
    }
}