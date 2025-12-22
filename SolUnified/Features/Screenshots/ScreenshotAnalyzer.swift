//
//  ScreenshotAnalyzer.swift
//  SolUnified
//
//  Native Apple Vision integration for screenshot analysis
//

import Foundation
import Vision
import AppKit

class ScreenshotAnalyzer: ObservableObject {
    static let shared = ScreenshotAnalyzer()
    
    @Published var isAnalyzing = false
    
    private init() {}
    
    func analyzeScreenshot(_ screenshot: Screenshot) async throws -> (description: String, tags: String, textContent: String) {
        
        // 1. Load Image
        guard let image = NSImage(contentsOfFile: screenshot.filepath),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "Failed to load image", code: -1)
        }

        await MainActor.run {
            isAnalyzing = true
        }
        
        defer {
            Task { @MainActor in
                isAnalyzing = false
            }
        }

        // 2. Create Vision Request (Local OCR)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        // 3. Process
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        // 4. Extract Text
        guard let observations = request.results else { return ("", "", "") }
        let recognizedText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")

        // 5. Basic Local Tagging (Heuristics based on text)
        var tags: [String] = []
        let lowerText = recognizedText.lowercased()
        
        // Context detection heuristics
        if lowerText.contains("order confirmed") || lowerText.contains("receipt") || lowerText.contains("total:") { tags.append("Purchase") }
        if lowerText.contains("sent") && (lowerText.contains("message") || lowerText.contains("email")) { tags.append("Communication") }
        if lowerText.contains("build succeeded") || lowerText.contains("commit") || lowerText.contains("pr merged") { tags.append("Dev") }
        if lowerText.contains("error") || lowerText.contains("failed") || lowerText.contains("exception") { tags.append("Error") }
        if lowerText.contains("slack") || lowerText.contains("discord") || lowerText.contains("whatsapp") { tags.append("Social") }
        
        let description = "Local OCR Analysis (\(recognizedText.count) chars)"

        return (description, tags.joined(separator: ", "), recognizedText)
    }
}

