//
//  PushNotificationManager.swift
//  MeetingIntelligence
//
//  Manages push notification device token registration with the backend
//

import Foundation
import UIKit
import Combine

/// Manages push notification device token registration and handles incoming notifications
class PushNotificationManager: ObservableObject {
    static let shared = PushNotificationManager()
    
    /// Current device token (FCM token)
    @Published private(set) var currentToken: String?
    
    /// Whether the device token has been registered with the backend
    @Published private(set) var isRegistered: Bool = false
    
    /// Last registration error
    @Published private(set) var lastError: String?
    
    /// Current user ID for registration
    private var currentUserId: String?
    
    /// Cancellables for subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotificationObservers()
        
        // Load any previously stored token
        if let storedToken = UserDefaults.standard.string(forKey: "fcmToken") {
            currentToken = storedToken
            print("📬 Loaded stored FCM token")
        }
    }
    
    // MARK: - Setup
    
    private func setupNotificationObservers() {
        // Listen for FCM token refresh
        NotificationCenter.default.publisher(for: .fcmTokenRefreshed)
            .sink { [weak self] notification in
                if let token = notification.userInfo?["token"] as? String {
                    self?.handleNewToken(token)
                }
            }
            .store(in: &cancellables)
        
        // Listen for push notifications received
        NotificationCenter.default.publisher(for: .didReceivePushNotification)
            .sink { [weak self] notification in
                self?.handlePushNotification(notification.userInfo ?? [:])
            }
            .store(in: &cancellables)
        
        // Listen for navigate to task notifications
        NotificationCenter.default.publisher(for: .navigateToTask)
            .sink { notification in
                if let taskId = notification.userInfo?["taskId"] as? String {
                    print("📬 Navigate to task: \(taskId)")
                    // This notification can be observed by views that need to navigate
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Token Management
    
    private func handleNewToken(_ token: String) {
        print("📬 Received new FCM token")
        currentToken = token
        
        // If we have a user ID, register the token
        if let userId = currentUserId {
            Task {
                await registerTokenWithBackend(userId: userId, token: token)
            }
        }
    }
    
    /// Set the current user and register the token if available
    func setUser(userId: String) {
        print("📬 Setting user for push notifications: \(userId)")
        currentUserId = userId
        
        // Register the token if we have one
        if let token = currentToken {
            Task {
                await registerTokenWithBackend(userId: userId, token: token)
            }
        }
    }
    
    /// Clear the current user (on logout)
    func clearUser() {
        guard let userId = currentUserId, let token = currentToken else {
            currentUserId = nil
            isRegistered = false
            return
        }
        
        print("📬 Clearing user from push notifications")
        
        // Unregister the token from the backend
        Task {
            await unregisterTokenFromBackend(userId: userId, token: token)
        }
        
        currentUserId = nil
        isRegistered = false
    }
    
    // MARK: - Backend Registration
    
    private func registerTokenWithBackend(userId: String, token: String) async {
        do {
            let deviceId = UIDevice.current.identifierForVendor?.uuidString
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            
            let success = try await APIService.shared.registerDeviceToken(
                userId: userId,
                token: token,
                platform: "IOS",
                deviceId: deviceId,
                appVersion: appVersion
            )
            
            await MainActor.run {
                if success {
                    self.isRegistered = true
                    self.lastError = nil
                    print("✅ Device token registered with backend")
                } else {
                    self.lastError = "Registration returned false"
                    print("⚠️ Device token registration returned false")
                }
            }
        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
                print("❌ Failed to register device token: \(error)")
            }
        }
    }
    
    private func unregisterTokenFromBackend(userId: String, token: String) async {
        do {
            let success = try await APIService.shared.unregisterDeviceToken(
                userId: userId,
                token: token
            )
            
            if success {
                print("✅ Device token unregistered from backend")
            } else {
                print("⚠️ Device token unregistration returned false")
            }
        } catch {
            print("❌ Failed to unregister device token: \(error)")
            // Don't throw - this is a cleanup operation
        }
    }
    
    // MARK: - Notification Handling
    
    private func handlePushNotification(_ userInfo: [AnyHashable: Any]) {
        print("📬 Handling push notification: \(userInfo)")
        
        // Extract notification type
        guard let type = userInfo["type"] as? String else {
            print("⚠️ Push notification missing type")
            return
        }
        
        switch type {
        case "TASK_ACTIVITY":
            handleTaskActivityNotification(userInfo)
        default:
            print("⚠️ Unknown notification type: \(type)")
        }
    }
    
    private func handleTaskActivityNotification(_ userInfo: [AnyHashable: Any]) {
        guard let taskId = userInfo["taskId"] as? String else {
            print("⚠️ Task activity notification missing taskId")
            return
        }
        
        let action = userInfo["action"] as? String ?? "unknown"
        print("📬 Task activity notification - taskId: \(taskId), action: \(action)")
        
        // The notification will be handled by the UI via .navigateToTask notification
        // when the user taps on it
    }
    
    // MARK: - Manual Registration
    
    /// Manually trigger token registration (e.g., if initial registration failed)
    func retryRegistration() {
        guard let userId = currentUserId, let token = currentToken else {
            print("⚠️ Cannot retry registration - missing userId or token")
            return
        }
        
        Task {
            await registerTokenWithBackend(userId: userId, token: token)
        }
    }
    
    /// Check if push notifications are enabled at the system level
    func checkNotificationPermissions() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .denied, .notDetermined, .ephemeral:
            return false
        @unknown default:
            return false
        }
    }
    
    /// Request notification permissions if not already granted
    func requestNotificationPermissions() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            
            return granted
        } catch {
            print("❌ Failed to request notification permissions: \(error)")
            return false
        }
    }
}

// Import for UNUserNotificationCenter
import UserNotifications
