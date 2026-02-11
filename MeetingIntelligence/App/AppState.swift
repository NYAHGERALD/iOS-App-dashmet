//
//  AppState.swift
//  MeetingIntelligence
//
//  Phase 0 - Application State Management
//

import Foundation
import SwiftUI
import Combine
import FirebaseAuth

/// Central application state observable
@MainActor
class AppState: ObservableObject {
    
    // MARK: - Dependencies
    private let authService = FirebaseAuthService.shared
    
    // MARK: - App Status
    @Published var isInitialized: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Authentication
    @Published var isAuthenticated: Bool = false
    @Published var currentUserID: String?
    @Published var idToken: String?
    
    // MARK: - User Profile (stored after registration/login)
    @Published var organizationId: String?
    @Published var facilityId: String?
    @Published var firstName: String?
    @Published var lastName: String?
    @Published var userRole: String?
    @Published var email: String?
    @Published var profilePictureUrl: String?
    
    // UserDefaults keys for persistence
    private enum UserDefaultsKeys {
        static let userId = "user_id"
        static let organizationId = "organization_id"
        static let facilityId = "facility_id"
        static let firstName = "first_name"
        static let lastName = "last_name"
        static let userRole = "user_role"
        static let email = "user_email"
        static let profilePicture = "profile_picture_url"
    }
    
    // MARK: - Initialization
    func initialize() async {
        isLoading = true
        
        // Validate environment configuration
        let configValid = AppEnvironment.validateConfiguration()
        
        if !configValid {
            errorMessage = "Invalid environment configuration"
        }
        
        // Load persisted user data
        loadPersistedUserData()
        
        // Check for existing Firebase auth session
        if let user = authService.currentUser {
            currentUserID = user.uid
            isAuthenticated = true
            
            // Get fresh ID token
            do {
                idToken = try await authService.getIDToken()
                print("✅ Existing session restored for user: \(user.uid)")
            } catch {
                print("⚠️ Failed to get ID token: \(error.localizedDescription)")
            }
        } else {
            isAuthenticated = false
            currentUserID = nil
        }
        
        // Small delay for smooth UI
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        isLoading = false
        isInitialized = true
        
        print("✅ App initialized successfully")
    }
    
    // MARK: - Load Persisted Data
    private func loadPersistedUserData() {
        let defaults = UserDefaults.standard
        currentUserID = defaults.string(forKey: UserDefaultsKeys.userId)
        organizationId = defaults.string(forKey: UserDefaultsKeys.organizationId)
        facilityId = defaults.string(forKey: UserDefaultsKeys.facilityId)
        firstName = defaults.string(forKey: UserDefaultsKeys.firstName)
        lastName = defaults.string(forKey: UserDefaultsKeys.lastName)
        userRole = defaults.string(forKey: UserDefaultsKeys.userRole)
        email = defaults.string(forKey: UserDefaultsKeys.email)
        profilePictureUrl = defaults.string(forKey: UserDefaultsKeys.profilePicture)
        
        if currentUserID != nil {
            print("📦 Loaded persisted user data: \(firstName ?? "") \(lastName ?? "")")
        }
    }
    
    // MARK: - Authentication
    func setAuthenticated(userID: String, token: String? = nil) {
        currentUserID = userID
        idToken = token
        isAuthenticated = true
        print("✅ User authenticated: \(userID)")
    }
    
    /// Set user profile data after successful registration/login
    func setUserProfile(
        userId: String,
        firstName: String,
        lastName: String,
        organizationId: String,
        facilityId: String?,
        role: String,
        email: String? = nil,
        profilePictureUrl: String? = nil
    ) {
        self.currentUserID = userId
        self.firstName = firstName
        self.lastName = lastName
        self.organizationId = organizationId
        self.facilityId = facilityId
        self.userRole = role
        self.email = email
        self.profilePictureUrl = profilePictureUrl
        
        // Persist to UserDefaults
        let defaults = UserDefaults.standard
        defaults.set(userId, forKey: UserDefaultsKeys.userId)
        defaults.set(firstName, forKey: UserDefaultsKeys.firstName)
        defaults.set(lastName, forKey: UserDefaultsKeys.lastName)
        defaults.set(organizationId, forKey: UserDefaultsKeys.organizationId)
        defaults.set(facilityId, forKey: UserDefaultsKeys.facilityId)
        defaults.set(role, forKey: UserDefaultsKeys.userRole)
        if let email = email {
            defaults.set(email, forKey: UserDefaultsKeys.email)
        }
        if let profilePictureUrl = profilePictureUrl {
            defaults.set(profilePictureUrl, forKey: UserDefaultsKeys.profilePicture)
        }
        
        print("✅ User profile saved: \(firstName) \(lastName)")
    }
    
    /// Update just the profile picture URL
    func updateProfilePicture(_ url: String?) {
        self.profilePictureUrl = url
        let defaults = UserDefaults.standard
        if let url = url {
            defaults.set(url, forKey: UserDefaultsKeys.profilePicture)
        } else {
            defaults.removeObject(forKey: UserDefaultsKeys.profilePicture)
        }
        print("✅ Profile picture updated")
    }
    
    func logout() {
        do {
            try authService.signOut()
            
            // Clear user data
            currentUserID = nil
            idToken = nil
            isAuthenticated = false
            organizationId = nil
            facilityId = nil
            firstName = nil
            lastName = nil
            userRole = nil
            email = nil
            profilePictureUrl = nil
            
            // Clear persisted data
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: UserDefaultsKeys.userId)
            defaults.removeObject(forKey: UserDefaultsKeys.organizationId)
            defaults.removeObject(forKey: UserDefaultsKeys.facilityId)
            defaults.removeObject(forKey: UserDefaultsKeys.firstName)
            defaults.removeObject(forKey: UserDefaultsKeys.lastName)
            defaults.removeObject(forKey: UserDefaultsKeys.userRole)
            defaults.removeObject(forKey: UserDefaultsKeys.email)
            defaults.removeObject(forKey: UserDefaultsKeys.profilePicture)
            
            print("👋 User logged out")
        } catch {
            errorMessage = "Failed to logout: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Error Handling
    func clearError() {
        errorMessage = nil
    }
}
