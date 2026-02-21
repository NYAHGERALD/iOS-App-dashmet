//
//  AppDelegate.swift
//  MeetingIntelligence
//
//  Phase 1, Step 1.2 - App Delegate for Firebase Auth + Push Notifications
//

import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseAppCheck
import FirebaseMessaging
import UserNotifications

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
        
        // Setup push notifications
        setupPushNotifications(application: application)
        
        return true
    }
    
    // MARK: - Push Notification Setup
    
    private func setupPushNotifications(application: UIApplication) {
        // Set the messaging delegate
        Messaging.messaging().delegate = self
        
        // Set the notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            if let error = error {
                print("❌ Push notification authorization error: \(error)")
                return
            }
            
            if granted {
                print("✅ Push notification permission granted")
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            } else {
                print("⚠️ Push notification permission denied")
            }
        }
        
        print("📬 Push notification setup complete")
    }
    
    // MARK: - APNs Token Handling
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Pass device token to Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 APNs device token: \(tokenString)")
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
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
    
    // Handle remote notifications for phone auth and push notifications
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Let Firebase Auth handle the notification if it's for phone auth
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        
        // Handle push notification data
        print("📬 Received remote notification: \(userInfo)")
        
        // Post notification for the app to handle
        NotificationCenter.default.post(
            name: .didReceivePushNotification,
            object: nil,
            userInfo: userInfo
        )
        
        completionHandler(.newData)
    }
}

// MARK: - Firebase Messaging Delegate

extension AppDelegate: MessagingDelegate {
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else {
            print("⚠️ FCM token is nil")
            return
        }
        
        print("🔑 FCM registration token: \(token)")
        
        // Store the token and notify the app
        UserDefaults.standard.set(token, forKey: "fcmToken")
        
        // Post notification so the app can register the token with the backend
        NotificationCenter.default.post(
            name: .fcmTokenRefreshed,
            object: nil,
            userInfo: ["token": token]
        )
    }
}

// MARK: - UNUserNotificationCenter Delegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("📬 Notification received in foreground: \(userInfo)")
        
        // Show the notification even when the app is in foreground
        completionHandler([.banner, .badge, .sound])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("👆 Notification tapped: \(userInfo)")
        
        // Handle the notification tap - navigate to the relevant screen
        handleNotificationTap(userInfo: userInfo)
        
        completionHandler()
    }
    
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        // Extract notification data
        guard let type = userInfo["type"] as? String else { return }
        
        switch type {
        case "TASK_ACTIVITY":
            if let taskId = userInfo["taskId"] as? String {
                // Post notification to navigate to the task
                NotificationCenter.default.post(
                    name: .navigateToTask,
                    object: nil,
                    userInfo: ["taskId": taskId]
                )
            }
        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let fcmTokenRefreshed = Notification.Name("fcmTokenRefreshed")
    static let didReceivePushNotification = Notification.Name("didReceivePushNotification")
    static let navigateToTask = Notification.Name("navigateToTask")
}
