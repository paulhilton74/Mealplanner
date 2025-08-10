import Foundation

struct Config {
    static let openAIAPIKey: String = {
        // Try to get from environment variable first
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            return envKey
        }
        
        // Fallback to reading from a local config file (not committed to git)
        if let path = Bundle.main.path(forResource: "APIKeys", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let key = plist["OpenAIAPIKey"] as? String {
            return key
        }
        
        // Development fallback - replace with your actual key for local development
        return "YOUR_OPENAI_API_KEY_HERE"
    }()
    
    // Add other API keys here as needed
    static let claudeAPIKey: String = {
        if let envKey = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"] {
            return envKey
        }
        return "YOUR_CLAUDE_API_KEY_HERE"
    }()
}
