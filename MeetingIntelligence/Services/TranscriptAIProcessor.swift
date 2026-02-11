//
//  TranscriptAIProcessor.swift
//  MeetingIntelligence
//
//  Enterprise-grade AI Transcript Processor
//  Intelligently detects speaker changes and formats transcript for clarity
//  Handles large transcripts with smart chunking to avoid token limits
//

import Foundation

/// AI-powered transcript processor that organizes conversation by detecting speaker changes
/// Uses contextual analysis to identify when different people are speaking
/// Formats output with natural paragraph breaks - no labels like "Speaker 1"
@MainActor
class TranscriptAIProcessor {
    
    static let shared = TranscriptAIProcessor()
    
    // MARK: - Configuration
    
    /// Maximum tokens per chunk (GPT-4 has 8K context, we use ~3K for safety with response)
    private let maxChunkTokens = 2500
    
    /// Approximate characters per token (conservative estimate)
    private let charsPerToken = 3.5
    
    /// Overlap between chunks to maintain context continuity
    private let overlapSentences = 3
    
    /// Backend URL for AI processing
    private let backendURL = "https://dashmet-rca-api.onrender.com/api/transcripts/process-speakers"
    
    // MARK: - Public Methods
    
    /// Process transcript to detect speakers and format with paragraph breaks
    /// - Parameter transcript: Raw transcript text
    /// - Returns: Formatted transcript with speaker paragraphs separated by blank lines
    func processTranscript(_ transcript: String) async throws -> String {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTranscript.isEmpty else {
            return transcript
        }
        
        // Estimate token count
        let estimatedTokens = Double(trimmedTranscript.count) / charsPerToken
        
        print("============================================")
        print("🤖 AI TRANSCRIPT PROCESSOR")
        print("============================================")
        print("📝 Input length: \(trimmedTranscript.count) characters")
        print("📊 Estimated tokens: \(Int(estimatedTokens))")
        
        // If transcript is small enough, process in one go
        if estimatedTokens <= Double(maxChunkTokens) {
            print("✅ Processing as single chunk")
            return try await processSingleChunk(trimmedTranscript)
        }
        
        // Large transcript - split into chunks with overlap
        print("📦 Large transcript detected - using chunked processing")
        return try await processLargeTranscript(trimmedTranscript)
    }
    
    // MARK: - Private Methods
    
    /// Process a single chunk of transcript
    private func processSingleChunk(_ text: String) async throws -> String {
        return try await callBackendAPI(text: text, isChunk: false, chunkIndex: 0, totalChunks: 1)
    }
    
    /// Process large transcript by splitting into overlapping chunks
    private func processLargeTranscript(_ transcript: String) async throws -> String {
        // Split into sentences
        let sentences = splitIntoSentences(transcript)
        print("📄 Total sentences: \(sentences.count)")
        
        // Calculate chunk size in sentences
        let avgCharsPerSentence = Double(transcript.count) / Double(max(sentences.count, 1))
        let sentencesPerChunk = Int(Double(maxChunkTokens) * charsPerToken / avgCharsPerSentence)
        
        print("📐 Sentences per chunk: ~\(sentencesPerChunk)")
        
        // Create chunks with overlap
        var chunks: [String] = []
        var currentIndex = 0
        
        while currentIndex < sentences.count {
            let endIndex = min(currentIndex + sentencesPerChunk, sentences.count)
            let chunkSentences = Array(sentences[currentIndex..<endIndex])
            chunks.append(chunkSentences.joined(separator: " "))
            
            // Move forward, but keep overlap for context
            currentIndex = endIndex - overlapSentences
            if currentIndex <= 0 || endIndex >= sentences.count {
                currentIndex = endIndex
            }
        }
        
        print("📦 Created \(chunks.count) chunks")
        
        // Process each chunk
        var processedChunks: [String] = []
        
        for (index, chunk) in chunks.enumerated() {
            print("🔄 Processing chunk \(index + 1)/\(chunks.count)...")
            
            let processed = try await callBackendAPI(
                text: chunk,
                isChunk: true,
                chunkIndex: index,
                totalChunks: chunks.count
            )
            processedChunks.append(processed)
            
            // Small delay between chunks to avoid rate limiting
            if index < chunks.count - 1 {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
        
        // Merge chunks intelligently
        let merged = mergeProcessedChunks(processedChunks)
        print("✅ Merged all chunks: \(merged.count) characters")
        
        return merged
    }
    
    /// Split text into sentences
    private func splitIntoSentences(_ text: String) -> [String] {
        // Use linguistic tagger for better sentence detection
        var sentences: [String] = []
        
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .bySentences) { substring, _, _, _ in
            if let sentence = substring?.trimmingCharacters(in: .whitespacesAndNewlines), !sentence.isEmpty {
                sentences.append(sentence)
            }
        }
        
        // Fallback if enumeration fails
        if sentences.isEmpty {
            sentences = text.components(separatedBy: ". ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        
        return sentences
    }
    
    /// Merge processed chunks, removing duplicate content from overlaps
    private func mergeProcessedChunks(_ chunks: [String]) -> String {
        guard !chunks.isEmpty else { return "" }
        guard chunks.count > 1 else { return chunks[0] }
        
        var result = chunks[0]
        
        for i in 1..<chunks.count {
            let currentChunk = chunks[i]
            
            // Find overlap and append only new content
            // Look for the last paragraph of previous chunk in current chunk
            let previousParagraphs = result.components(separatedBy: "\n\n")
            if let lastParagraph = previousParagraphs.last,
               lastParagraph.count > 20,
               let overlapRange = currentChunk.range(of: lastParagraph.prefix(50)) {
                // Skip the overlapping part
                let startIndex = currentChunk.index(overlapRange.upperBound, offsetBy: 0, limitedBy: currentChunk.endIndex) ?? overlapRange.upperBound
                let newContent = String(currentChunk[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !newContent.isEmpty {
                    result += "\n\n" + newContent
                }
            } else {
                // No clear overlap found, just append with separator
                result += "\n\n" + currentChunk
            }
        }
        
        // Clean up any multiple consecutive newlines
        result = result.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
        
        return result
    }
    
    /// Call backend API for AI processing
    private func callBackendAPI(text: String, isChunk: Bool, chunkIndex: Int, totalChunks: Int) async throws -> String {
        guard let url = URL(string: backendURL) else {
            throw TranscriptProcessingError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 // 2 minutes for AI processing
        
        // Add Firebase auth token
        do {
            let token = try await FirebaseAuthService.shared.getIDToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } catch {
            throw TranscriptProcessingError.authenticationFailed
        }
        
        // Build request body
        let body: [String: Any] = [
            "transcript": text,
            "isChunk": isChunk,
            "chunkIndex": chunkIndex,
            "totalChunks": totalChunks
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptProcessingError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool, success,
               let processedText = json["processedTranscript"] as? String {
                return processedText
            } else {
                throw TranscriptProcessingError.parsingFailed
            }
        } else if httpResponse.statusCode == 401 {
            throw TranscriptProcessingError.authenticationFailed
        } else {
            let errorMsg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw TranscriptProcessingError.serverError(errorMsg ?? "Server error \(httpResponse.statusCode)")
        }
    }
}

// MARK: - Errors

enum TranscriptProcessingError: LocalizedError {
    case invalidURL
    case authenticationFailed
    case invalidResponse
    case parsingFailed
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .authenticationFailed:
            return "Authentication failed. Please log in again."
        case .invalidResponse:
            return "Invalid response from server"
        case .parsingFailed:
            return "Failed to parse server response"
        case .serverError(let message):
            return message
        }
    }
}
