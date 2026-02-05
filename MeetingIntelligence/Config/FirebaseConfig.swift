//
//  FirebaseConfig.swift
//  MeetingIntelligence
//
//  Phase 1, Step 1.2 - Firebase Configuration
//

import Foundation
import FirebaseCore

/// Firebase configuration and initialization
enum FirebaseConfig {
    
    /// Initialize Firebase
    /// Call this in AppDelegate or App init
    static func configure() {
        // Firebase will automatically use GoogleService-Info.plist
        // Make sure to add the file to your project
        
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("🔥 Firebase configured successfully")
        } else {
            print("🔥 Firebase already configured")
        }
    }
    
    /// Check if Firebase is configured
    static var isConfigured: Bool {
        FirebaseApp.app() != nil
    }
}
