//
//  MeetingIntelligenceApp.swift
//  MeetingIntelligence
//
//  Created by GERALD NYAH on 2/4/26.
//

import SwiftUI
import FirebaseCore

@main
struct MeetingIntelligenceApp: App {
    
    // Use AppDelegate for Firebase Auth
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    init() {
        print("🚀 MeetingIntelligence App Starting...")
        
        // Clean up any pending audio deletions from previous session
        // This ensures audio is deleted even if user quit the app during deletion
        Task { @MainActor in
            ComplianceService.shared.performPendingDeletionsOnLaunch()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
