//
//  DocumentAIService.swift
//  MeetingIntelligence
//
//  AI Service for Document Processing using Backend API
//  Handles OCR extraction and text cleaning/structuring
//  Optimized for accurate handwritten text recognition
//

import Foundation
import UIKit

// MARK: - Document AI Service
class DocumentAIService {
    static let shared = DocumentAIService()
    
    // Backend API URL - OpenAI key is configured on Render.com
    private let baseURL = "https://dashmet-rca-api.onrender.com/api/document-ocr"
    
    private init() {}
    
    // MARK: - Process Multiple Pages (Main Method)
    
    /// Process multiple scanned pages via backend and combine into single document
    func processMultiplePages(_ images: [UIImage], documentType: String, sourceLanguage: String = "English", progressHandler: ((Double, String) -> Void)? = nil) async throws -> DocumentProcessingResult {
        progressHandler?(0.1, "Preparing images for processing...")
        
        // Convert images to base64
        var base64Images: [String] = []
        for (index, image) in images.enumerated() {
            progressHandler?(0.1 + (Double(index) / Double(images.count) * 0.2), "Encoding image \(index + 1)...")
            
            guard let imageData = image.jpegData(compressionQuality: 0.85) else {
                throw DocumentAIError.invalidImage
            }
            base64Images.append(imageData.base64EncodedString())
        }
        
        progressHandler?(0.35, "Processing document (\(sourceLanguage))...")
        
        // Call backend API
        let requestBody: [String: Any] = [
            "images": base64Images,
            "documentType": documentType,
            "sourceLanguage": sourceLanguage
        ]
        
        let result = try await makeBackendRequest(endpoint: "/process", body: requestBody)
        
        progressHandler?(0.9, "Parsing results...")
        
        // Parse the response
        guard let data = result["data"] as? [String: Any] else {
            throw DocumentAIError.parsingError
        }
        
        progressHandler?(1.0, "Complete!")
        
        return DocumentProcessingResult(
            originalText: data["originalText"] as? String ?? "",
            translatedText: data["translatedText"] as? String,
            cleanedText: data["cleanedText"] as? String ?? "",
            detectedLanguage: data["detectedLanguage"] as? String ?? sourceLanguage,
            isHandwritten: data["isHandwritten"] as? Bool ?? false,
            keyPoints: data["keyPoints"] as? [String] ?? [],
            mentionedNames: data["mentionedNames"] as? [String] ?? [],
            mentionedDates: data["mentionedDates"] as? [String] ?? [],
            summary: data["summary"] as? String ?? "",
            corrections: data["corrections"] as? [String] ?? [],
            pageCount: data["pageCount"] as? Int ?? images.count,
            confidence: data["confidence"] as? Double ?? 0.8
        )
    }
    
    // MARK: - Individual Operations (for specific use cases)
    
    /// Extract text from a single image via backend
    func extractTextFromImage(_ image: UIImage, sourceLanguage: String = "English") async throws -> ExtractedTextResult {
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw DocumentAIError.invalidImage
        }
        
        let base64Image = imageData.base64EncodedString()
        
        let requestBody: [String: Any] = [
            "image": base64Image,
            "sourceLanguage": sourceLanguage
        ]
        
        let result = try await makeBackendRequest(endpoint: "/extract", body: requestBody)
        
        guard let data = result["data"] as? [String: Any] else {
            throw DocumentAIError.parsingError
        }
        
        return ExtractedTextResult(
            extractedText: data["extractedText"] as? String ?? "",
            isHandwritten: data["isHandwritten"] as? Bool ?? false,
            detectedLanguage: data["detectedLanguage"] as? String ?? sourceLanguage,
            confidence: data["confidence"] as? Double ?? 0.8,
            unclearSections: data["unclearSections"] as? [String] ?? []
        )
    }
    
    /// Clean and structure text via backend
    func cleanAndStructureText(_ rawText: String, documentType: String, sourceLanguage: String = "English") async throws -> CleanedTextResult {
        let requestBody: [String: Any] = [
            "text": rawText,
            "documentType": documentType,
            "sourceLanguage": sourceLanguage
        ]
        
        let result = try await makeBackendRequest(endpoint: "/clean", body: requestBody)
        
        guard let data = result["data"] as? [String: Any] else {
            throw DocumentAIError.parsingError
        }
        
        return CleanedTextResult(
            cleanedText: data["cleanedText"] as? String ?? rawText,
            corrections: data["corrections"] as? [String] ?? [],
            keyPoints: data["keyPoints"] as? [String] ?? [],
            mentionedNames: data["mentionedNames"] as? [String] ?? [],
            mentionedDates: data["mentionedDates"] as? [String] ?? [],
            summary: data["summary"] as? String ?? ""
        )
    }
    
    /// Translate text to English via backend
    func translateToEnglish(_ text: String, sourceLanguage: String) async throws -> String {
        if sourceLanguage.lowercased() == "english" {
            return text
        }
        
        let requestBody: [String: Any] = [
            "text": text,
            "sourceLanguage": sourceLanguage
        ]
        
        let result = try await makeBackendRequest(endpoint: "/translate", body: requestBody)
        
        guard let data = result["data"] as? [String: Any],
              let translatedText = data["translatedText"] as? String else {
            throw DocumentAIError.parsingError
        }
        
        return translatedText
    }
    
    // MARK: - Private Helpers
    
    private func makeBackendRequest(endpoint: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: baseURL + endpoint) else {
            throw DocumentAIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 180 // 3 minutes for large documents
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DocumentAIError.invalidResponse
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DocumentAIError.invalidResponse
        }
        
        // Check for error response
        if httpResponse.statusCode != 200 {
            // Check for language mismatch error
            if let errorCode = json["error"] as? String, errorCode == "LANGUAGE_MISMATCH" {
                let detected = json["detectedLanguage"] as? String ?? "unknown"
                let selected = json["selectedLanguage"] as? String ?? "unknown"
                throw DocumentAIError.languageMismatch(detected: detected, selected: selected)
            }
            if let errorMessage = json["message"] as? String {
                throw DocumentAIError.apiError(errorMessage)
            }
            if let errorMessage = json["error"] as? String {
                throw DocumentAIError.apiError(errorMessage)
            }
            throw DocumentAIError.apiError("Server error: HTTP \(httpResponse.statusCode)")
        }
        
        // Check success field
        if let success = json["success"] as? Bool, !success {
            // Check for language mismatch error
            if let errorCode = json["error"] as? String, errorCode == "LANGUAGE_MISMATCH" {
                let detected = json["detectedLanguage"] as? String ?? "unknown"
                let selected = json["selectedLanguage"] as? String ?? "unknown"
                throw DocumentAIError.languageMismatch(detected: detected, selected: selected)
            }
            if let errorMessage = json["message"] as? String {
                throw DocumentAIError.apiError(errorMessage)
            }
            if let errorMessage = json["error"] as? String {
                throw DocumentAIError.apiError(errorMessage)
            }
        }
        
        return json
    }
}

// MARK: - Result Models

struct ExtractedTextResult {
    let extractedText: String
    let isHandwritten: Bool
    let detectedLanguage: String
    let confidence: Double
    let unclearSections: [String]
}

struct CleanedTextResult {
    let cleanedText: String
    let corrections: [String]
    let keyPoints: [String]
    let mentionedNames: [String]
    let mentionedDates: [String]
    let summary: String
}

struct DocumentProcessingResult {
    let originalText: String
    let translatedText: String?
    let cleanedText: String
    let detectedLanguage: String
    let isHandwritten: Bool
    let keyPoints: [String]
    let mentionedNames: [String]
    let mentionedDates: [String]
    let summary: String
    let corrections: [String]
    let pageCount: Int
    let confidence: Double
}

struct TTSResult {
    let audioData: Data
    let languageCode: String
    let greeting: String
    let purpose: String
    let transition: String
    let closing: String
    let documentText: String
    let introWordCount: Int  // Number of words in intro speech (for delaying text highlight)
}

// MARK: - Errors

enum DocumentAIError: LocalizedError {
    case invalidImage
    case invalidResponse
    case parsingError
    case apiError(String)
    case languageMismatch(detected: String, selected: String)
    case textExtractionFailed(hint: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image. Please try scanning again with better lighting."
        case .invalidResponse:
            return "Invalid response from System. Please try again."
        case .parsingError:
            return "Could not process the document content. Please try again."
        case .apiError(let message):
            return message
        case .languageMismatch(let detected, let selected):
            return "The document appears to be in \(detected), but '\(selected)' was selected. Please go back and select the correct language for accurate text extraction."
        case .textExtractionFailed(let hint):
            return "Unable to extract text from the document. \(hint)"
        }
    }
    
    /// Provides a helpful hint for the user
    var recoveryHint: String? {
        switch self {
        case .languageMismatch:
            return "Tap 'Go Back' and select the correct language before scanning."
        case .textExtractionFailed:
            return "Make sure the correct language is selected and the document is clearly visible."
        case .invalidImage:
            return "Ensure the document is well-lit and in focus when scanning."
        default:
            return nil
        }
    }
}

// MARK: - Text-to-Speech Service

class TextToSpeechService {
    static let shared = TextToSpeechService()
    
    private let baseURL = "https://dashmet-rca-api.onrender.com/api/document-ocr"
    
    private init() {}
    
    /// Generate speech from text with personalized greeting in the specified language
    /// - Parameters:
    ///   - text: The document text to read aloud
    ///   - employeeName: Name of the employee for personalized greeting
    ///   - documentType: Type of document (e.g., "complaint")
    ///   - languageCode: Language code (e.g., "en-US", "fr-FR")
    ///   - skipIntro: If true, skip the greeting/intro/closing and just read the content.
    ///                Use this for documents that have already been reviewed and accepted.
    func generateSpeech(text: String, employeeName: String, documentType: String = "complaint", languageCode: String = "en-US", skipIntro: Bool = false) async throws -> TTSResult {
        guard let url = URL(string: baseURL + "/text-to-speech") else {
            throw DocumentAIError.invalidResponse
        }
        
        let requestBody: [String: Any] = [
            "text": text,
            "employeeName": employeeName,
            "documentType": documentType,
            "languageCode": languageCode,
            "skipIntro": skipIntro
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 120 // 2 minutes for TTS generation
        
        print("TTS Service: Calling \(url), skipIntro: \(skipIntro)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("TTS Service: Invalid response type")
            throw DocumentAIError.invalidResponse
        }
        
        print("TTS Service: HTTP status \(httpResponse.statusCode), response size: \(data.count)")
        
        guard httpResponse.statusCode == 200 else {
            print("TTS Service: HTTP error \(httpResponse.statusCode)")
            throw DocumentAIError.apiError("Server error: HTTP \(httpResponse.statusCode)")
        }
        
        // Backend returns raw audio bytes (audio/mpeg) and headers with metadata
        let responseLanguage = httpResponse.value(forHTTPHeaderField: "X-Language-Code") ?? languageCode
        let introWordCountStr = httpResponse.value(forHTTPHeaderField: "X-Intro-Word-Count") ?? "0"
        let introWordCount = Int(introWordCountStr) ?? 0
        
        print("TTS Service: Received raw audio data: \(data.count) bytes, intro words: \(introWordCount)")
        
        return TTSResult(
            audioData: data,
            languageCode: responseLanguage,
            greeting: "",
            purpose: "",
            transition: "",
            closing: "",
            documentText: text,
            introWordCount: introWordCount
        )
    }
}
