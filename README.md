# 🍽️ Meal Planner iOS App

A comprehensive iOS meal planning application built with SwiftUI and Core Data, featuring AI-powered recipe extraction, URL sharing, and intelligent meal planning.

## ✨ Features

### Core Functionality
- **Recipe Extraction**: Extract recipes from websites using AI and web scraping
- **OCR Scanning**: Scan recipes from images (cookbooks, magazines) using Vision framework
- **AI Analysis**: Powered recipe analysis using Claude Vision Service
- **Weekly Planning**: Drag-and-drop interface for meal planning
- **Shopping Lists**: Automatic generation from meal plans
- **Recipe Management**: Automatic tagging and categorization

### 🆕 New Features Added
- **URL Sharing**: Import recipes directly from Safari and other apps
- **Weekly Planner Integration**: "Add to Weekly Planner" button in recipe details
- **Secure API Management**: Environment variables and local config file support
- **Multi-URL Support**: Handle `mealplanner://`, `http://`, and `https://` URLs

## 🛠️ Technical Stack

- **SwiftUI** - Modern UI framework
- **Core Data** - Local data persistence
- **Swift Package Manager** - Dependency management
- **SwiftSoup** - HTML parsing for recipe extraction
- **Vision Framework** - OCR capabilities
- **Claude AI** - Recipe analysis and processing
- **Google Cloud Vision** - Advanced OCR and image analysis

## 🚀 Setup Instructions

### 1. Clone the Repository
```bash
git clone https://github.com/paulhilton74/Mealplanner.git
cd Mealplanner
```

### 2. Configure API Keys
```bash
# Copy the template
cp Mealplannerv3/APIKeys.plist.template Mealplannerv3/APIKeys.plist
4. **Enable the Cloud Vision API for your project:**
   - Go to [API Library](https://console.cloud.google.com/apis/library/vision.googleapis.com)
   - Select your project
   - Click "Enable"
   - **Important:** After enabling the API, wait 5-10 minutes for the changes to fully propagate
5. Create an API key:
   - Go to [Credentials](https://console.cloud.google.com/apis/credentials)
   - Click "Create credentials" and select "API key"
   - Copy the generated API key
6. Update the `APIConfig.swift` file with your API key:
   ```swift
   struct APIConfig {
       // Google Cloud Vision API key
       static let googleCloudVisionAPIKey = "YOUR_API_KEY_HERE"
       
       // Google Cloud Vision API endpoint
       static let googleCloudVisionEndpoint = "https://vision.googleapis.com/v1/images:annotate"
   }
   ```
7. Uncomment the line in `.gitignore` to prevent your API key from being committed to version control:
   ```
   Mealplannerv3/APIConfig.swift
   ```

### Building the Project

1. Clone the repository
2. Open the project in Xcode
3. Build and run the project on a simulator or device

## Usage

### Extracting Recipes from Websites

1. Tap "Add Recipe"
2. Select "Add from Recipe URL"
3. Enter the URL of a recipe website
4. Tap "Extract Recipe"
5. Review and edit the extracted recipe
6. Tap "Save"

### Extracting Recipes from Images

1. Tap "Add Recipe"
2. Select "Add Recipe from Image"
3. Take a photo or select an image from your photo library
4. Tap "Extract Recipe from Image"
5. Review and edit the extracted recipe
6. Tap "Save"

## Dependencies

- [SwiftSoup](https://github.com/scinfu/SwiftSoup): HTML parsing
- [Alamofire](https://github.com/Alamofire/Alamofire): HTTP networking

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Troubleshooting Google Cloud Vision API

If you encounter issues with the Google Cloud Vision API, check the following:

1. **API Not Enabled**: Make sure the Cloud Vision API is enabled for your project.
2. **Billing Not Enabled**: Ensure billing is enabled for your Google Cloud project. The Vision API requires an active billing account even if you stay within the free tier.
3. **Wait After Enabling**: After enabling the API and billing, wait 5-10 minutes for the changes to fully propagate through Google's systems.
4. **Invalid API Key**: Verify that the API key in `APIConfig.swift` is correct.
5. **API Restrictions**: Check if your API key has any restrictions that might prevent it from working.
6. **Quota Limits**: Ensure you haven't exceeded your quota limits.
7. **Test API Key**: You can test your API key with a simple curl command:
   ```
   curl -s -H "Content-Type: application/json" "https://vision.googleapis.com/v1/images:annotate?key=YOUR_API_KEY" --data-binary '{"requests":[{"image":{"content":"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="},"features":[{"type":"TEXT_DETECTION","maxResults":10}]}]}'
   ```

For more information, visit the [Google Cloud Vision API documentation](https://cloud.google.com/vision/docs).
