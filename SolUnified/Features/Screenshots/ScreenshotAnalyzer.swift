//
//  ScreenshotAnalyzer.swift
//  SolUnified
//
//  Native OpenAI API integration for screenshot analysis
//

import Foundation

struct OpenAIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let content: String
        }
    }
}

class ScreenshotAnalyzer: ObservableObject {
    static let shared = ScreenshotAnalyzer()
    
    @Published var isAnalyzing = false
    
    private let apiKey: String?
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    private init() {
        // Get API key from environment or UserDefaults
        self.apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? 
                     UserDefaults.standard.string(forKey: "OPENAI_API_KEY")
    }
    
    func analyzeScreenshot(_ screenshot: Screenshot) async throws -> (description: String, tags: String, textContent: String) {
        guard let apiKey = apiKey else {
            throw NSError(domain: "No API key configured", code: -1)
        }
        
        guard let imageData = try? Data(contentsOf: URL(fileURLWithPath: screenshot.filepath)) else {
            throw NSError(domain: "Failed to read image", code: -1)
        }
        
        let base64Image = imageData.base64EncodedString()
        let mimeType = getMimeType(for: screenshot.filepath)
        
        await MainActor.run {
            isAnalyzing = true
        }
        
        defer {
            Task { @MainActor in
                isAnalyzing = false
            }
        }
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "Analyze this screenshot. Provide: 1) A brief description (one sentence), 2) Relevant tags (comma-separated, max 5 tags), 3) Any text content visible in the image (OCR). Format your response as JSON: {\"description\": \"...\", \"tags\": \"...\", \"text_content\": \"...\"}"
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:\(mimeType);base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 500
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "API request failed", code: -1)
        }
        
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        let content = openAIResponse.choices.first?.message.content ?? ""
        
        // Parse JSON response
        if let jsonData = content.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            let description = json["description"] as? String ?? ""
            let tags = json["tags"] as? String ?? ""
            let textContent = json["text_content"] as? String ?? ""
            return (description, tags, textContent)
        }
        
        // Fallback: treat entire response as description
        return (content, "", "")
    }
    
    private func getMimeType(for filePath: String) -> String {
        let ext = (filePath as NSString).pathExtension.lowercased()
        switch ext {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        default: return "image/png"
        }
    }
}
