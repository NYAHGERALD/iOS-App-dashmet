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
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
