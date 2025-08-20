# Claude Code Configuration

## Project Context
This is a Swift iOS meal planning application with Core Data persistence, Google Cloud Vision integration, and fridge tracking functionality.

## Instructions for Claude Code
- Minimize explanatory text and focus on code output
- Provide direct, concise responses without preamble or postamble
- When making code changes, show the code without additional commentary
- Only explain code when explicitly asked
- Prioritize Swift/iOS conventions and existing codebase patterns
- Use existing Core Data models and follow established architecture

## Development Commands
- Build: `xcodebuild -project ../Mealplannerv3.xcodeproj -scheme Mealplannerv3 build`
- Test: `xcodebuild -project ../Mealplannerv3.xcodeproj -scheme Mealplannerv3 test`

## Key Files
- Core Data Model: `RecipeModel.xcdatamodeld/`
- Main Views: `ContentView.swift`, `MainMenuView.swift`
- Data Management: `PersistenceController.swift`
- Services: `GoogleCloudVisionService.swift`