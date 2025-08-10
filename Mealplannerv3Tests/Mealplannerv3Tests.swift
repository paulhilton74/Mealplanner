//
//  Mealplannerv3Tests.swift
//  Mealplannerv3Tests
//
//  Created by Paul Hilton on 17/2/25.
//

import XCTest
@testable import Mealplannerv3

class Mealplannerv3Tests: XCTestCase {
    var addRecipeView: AddRecipeView!
    
    override func setUp() {
        super.setUp()
        addRecipeView = AddRecipeView()
    }
    
    override func tearDown() {
        addRecipeView = nil
        super.tearDown()
    }
    
    func testRecipeURLExtraction() {
        // Test valid recipe URL
        let expectation = XCTestExpectation(description: "Recipe extraction")
        addRecipeView.sourceURL = "https://example.com/recipe"
        
        // Mock URLSession data task
        let mockHTML = """
        <script type="application/ld+json">
        {
            "@type": "Recipe",
            "name": "Test Recipe",
            "recipeIngredient": ["1 cup flour", "2 eggs"],
            "recipeInstructions": ["Mix ingredients", "Bake at 350F"],
            "image": "https://example.com/image.jpg"
        }
        </script>
        """
        
        // Verify extracted data
        if let recipeData = addRecipeView.extractRecipeData(from: mockHTML) {
            XCTAssertEqual(recipeData.title, "Test Recipe")
            XCTAssertEqual(recipeData.ingredients, ["1 cup flour", "2 eggs"])
            XCTAssertEqual(recipeData.instructions, ["Mix ingredients", "Bake at 350F"])
            XCTAssertEqual(recipeData.images, ["https://example.com/image.jpg"])
            expectation.fulfill()
        } else {
            XCTFail("Failed to extract recipe data")
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testInvalidRecipeURL() {
        // Test invalid URL format
        addRecipeView.sourceURL = "invalid-url"
        XCTAssertFalse(URL(string: addRecipeView.sourceURL) != nil)
        
        // Test URL with no recipe data
        let expectation = XCTestExpectation(description: "Invalid recipe data")
        addRecipeView.sourceURL = "https://example.com/no-recipe"
        
        let mockHTML = "<html><body>No recipe data here</body></html>"
        let recipeData = addRecipeView.extractRecipeData(from: mockHTML)
        XCTAssertNil(recipeData)
        expectation.fulfill()
        
        wait(for: [expectation], timeout: 5.0)
    }
}
