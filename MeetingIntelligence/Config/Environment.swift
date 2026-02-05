//
//  Environment.swift
//  MeetingIntelligence
//
//  Phase 0 - Environment Configuration
//

import Foundation

/// Environment configuration with placeholder values
/// Replace placeholders with actual values before deployment
enum Environment {
    
    // MARK: - Firebase Configuration
    static let firebaseProjectID = "YOUR_FIREBASE_PROJECT_ID"
    
    // MARK: - Backend Configuration
    static let apiBaseURL = "https://YOUR_API_URL"
    static let workerBaseURL = "https://YOUR_WORKER_URL"
    
    // MARK: - Database (for reference - actual connection is backend-side)
    static let databaseURL = "postgresql://YOUR_DATABASE_URL"
    
    // MARK: - Environment Detection
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Validation
    static func validateConfiguration() -> Bool {
        let placeholders = [
            firebaseProjectID,
            apiBaseURL,
            workerBaseURL
        ]
        
        let hasPlaceholders = placeholders.contains { $0.contains("YOUR_") }
        
        if hasPlaceholders && !isDebug {
            print("⚠️ WARNING: Environment contains placeholder values!")
            return false
        }
        
        print("✅ Environment configuration loaded")
        return true
    }
}
