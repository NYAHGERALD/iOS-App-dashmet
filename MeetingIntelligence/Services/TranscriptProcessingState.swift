//
//  TranscriptProcessingState.swift
//  MeetingIntelligence
//
//  Shared state for transcript processing workflow
//  Tracks AI processing attempts, save status, and transcript versions
//

import Foundation
import SwiftUI
import Combine

/// Observable state manager for transcript processing workflow
@MainActor
class TranscriptProcessingState: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The original raw transcript from Whisper
    @Published var rawTranscript: GeneratedTranscript?
    
    /// The AI-processed transcript with speaker formatting
    @Published var processedTranscript: GeneratedTranscript?
    
    /// Number of AI processing attempts used (max 3)
    @Published var aiProcessingAttempts: Int = 0
    
    /// Whether the processed transcript has been saved
    @Published var isProcessedTranscriptSaved: Bool = false
    
    /// Whether the user has viewed the full transcript
    @Published var hasViewedFullTranscript: Bool = false
    
    /// Whether AI processing is currently in progress
    @Published var isProcessingAI: Bool = false
    
    /// Error message from AI processing
    @Published var aiProcessingError: String?
    
    /// Whether raw transcript was auto-saved to database
    @Published var isRawTranscriptAutoSaved: Bool = false
    
    // MARK: - Constants
    
    /// Maximum number of AI processing attempts allowed
    static let maxAIAttempts = 3
    
    // MARK: - Computed Properties
    
    /// Whether AI processing is available (attempts remaining and not saved)
    var canProcessWithAI: Bool {
        aiProcessingAttempts < Self.maxAIAttempts && 
        !isProcessedTranscriptSaved &&
        !isProcessingAI
    }
    
    /// Number of AI processing attempts remaining
    var remainingAttempts: Int {
        max(0, Self.maxAIAttempts - aiProcessingAttempts)
    }
    
    /// Whether the Save button should be enabled
    var canSaveProcessedTranscript: Bool {
        processedTranscript != nil && 
        !isProcessedTranscriptSaved &&
        aiProcessingAttempts <= Self.maxAIAttempts
    }
    
    /// Whether Save to Cloud should be enabled
    /// Requires: viewed transcript + processed with AI + saved processed transcript
    var canSaveToCloud: Bool {
        hasViewedFullTranscript && 
        processedTranscript != nil && 
        isProcessedTranscriptSaved
    }
    
    /// Whether there are unsaved changes that would be lost
    var hasUnsavedChanges: Bool {
        processedTranscript != nil && !isProcessedTranscriptSaved
    }
    
    /// The current best transcript (processed if available, otherwise raw)
    var currentTranscript: GeneratedTranscript? {
        processedTranscript ?? rawTranscript
    }
    
    // MARK: - Methods
    
    /// Set the raw transcript and mark as viewed
    func setRawTranscript(_ transcript: GeneratedTranscript) {
        rawTranscript = transcript
    }
    
    /// Record that user viewed the full transcript
    func markFullTranscriptViewed() {
        hasViewedFullTranscript = true
    }
    
    /// Process transcript with AI
    func processWithAI() async throws {
        guard canProcessWithAI, let transcript = currentTranscript else {
            throw TranscriptProcessingError.serverError("Cannot process: no transcript or attempts exhausted")
        }
        
        isProcessingAI = true
        aiProcessingError = nil
        
        do {
            let processedText = try await TranscriptAIProcessor.shared.processTranscript(transcript.processedText)
            
            processedTranscript = GeneratedTranscript(
                rawText: transcript.rawText,
                processedText: processedText,
                segments: transcript.segments,
                duration: transcript.duration,
                wordCount: processedText.split(separator: " ").count,
                generatedAt: Date()
            )
            
            aiProcessingAttempts += 1
            isProcessingAI = false
            
        } catch {
            isProcessingAI = false
            aiProcessingAttempts += 1
            aiProcessingError = error.localizedDescription
            throw error
        }
    }
    
    /// Mark processed transcript as saved
    func markProcessedTranscriptSaved() {
        isProcessedTranscriptSaved = true
    }
    
    /// Mark raw transcript as auto-saved
    func markRawTranscriptAutoSaved() {
        isRawTranscriptAutoSaved = true
    }
    
    /// Reset state for new recording
    func reset() {
        rawTranscript = nil
        processedTranscript = nil
        aiProcessingAttempts = 0
        isProcessedTranscriptSaved = false
        hasViewedFullTranscript = false
        isProcessingAI = false
        aiProcessingError = nil
        isRawTranscriptAutoSaved = false
    }
}
