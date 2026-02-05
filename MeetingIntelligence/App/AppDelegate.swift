//
//  AppDelegate.swift
//  MeetingIntelligence
//
//  Phase 1, Step 1.2 - App Delegate for Firebase Auth
//

import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseAppCheck

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        
        // Use debug App Check provider for simulator/debug builds
        #if DEBUG
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        print("🔧 App Check Debug Provider enabled")
        #endif
        
        FirebaseApp.configure()
        print("🔥 Firebase configured in AppDelegate")
        
        // Set language for auth
        Auth.auth().languageCode = "en"
        
        return true
    }
    
    // Handle URL for Firebase Auth (reCAPTCHA)
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }
        return false
    }
    
    // Handle remote notifications for phone auth
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        completionHandler(.noData)
    }
}
