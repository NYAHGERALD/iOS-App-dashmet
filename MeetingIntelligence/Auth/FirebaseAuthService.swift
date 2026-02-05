//
//  FirebaseAuthService.swift
//  MeetingIntelligence
//
//  Phase 1, Step 1.2 - Firebase Phone Authentication Service
//

import Foundation
import Combine
import FirebaseAuth

/// Service for handling Firebase Phone Authentication
@MainActor
class FirebaseAuthService: ObservableObject {
    
    static let shared = FirebaseAuthService()
    
    // MARK: - Properties
    private var verificationID: String?
    
    var currentUser: User? {
        Auth.auth().currentUser
    }
    
    var isAuthenticated: Bool {
        currentUser != nil
    }
    
    var firebaseUID: String? {
        currentUser?.uid
    }
    
    // MARK: - Phone Authentication
    
    /// Send OTP to phone number
    /// - Parameter phoneNumber: Full phone number with country code (e.g., "+11234567890")
    /// - Returns: Verification ID for OTP verification
    func sendOTP(to phoneNumber: String) async throws -> String {
        print("📱 Sending OTP to: \(phoneNumber)")
        
        return try await withCheckedThrowingContinuation { continuation in
            PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { [weak self] verificationID, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Failed to send OTP: \(error.localizedDescription)")
                        continuation.resume(throwing: AuthError.otpSendFailed(error.localizedDescription))
                        return
                    }
                    
                    guard let verificationID = verificationID else {
                        continuation.resume(throwing: AuthError.otpSendFailed("No verification ID returned"))
                        return
                    }
                    
                    print("✅ OTP sent successfully. Verification ID: \(verificationID.prefix(10))...")
                    self?.verificationID = verificationID
                    continuation.resume(returning: verificationID)
                }
            }
        }
    }
    
    /// Verify OTP code and sign in
    /// - Parameters:
    ///   - code: 6-digit OTP code
    ///   - verificationID: Verification ID from sendOTP
    /// - Returns: Firebase ID token
    func verifyOTP(code: String, verificationID: String) async throws -> String {
        print("🔐 Verifying OTP code...")
        
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: code
        )
        
        do {
            let authResult = try await Auth.auth().signIn(with: credential)
            let user = authResult.user
            
            print("✅ User signed in: \(user.uid)")
            
            // Get ID token for backend verification
            let idToken = try await user.getIDToken()
            print("🎫 ID Token obtained (length: \(idToken.count))")
            
            return idToken
            
        } catch {
            print("❌ OTP verification failed: \(error.localizedDescription)")
            throw AuthError.otpVerificationFailed(error.localizedDescription)
        }
    }
    
    /// Get current user's ID token (refreshed if needed)
    func getIDToken() async throws -> String {
        guard let user = currentUser else {
            throw AuthError.notAuthenticated
        }
        
        return try await user.getIDToken()
    }
    
    /// Sign out the current user
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            verificationID = nil
            print("👋 User signed out")
        } catch {
            print("❌ Sign out failed: \(error.localizedDescription)")
            throw AuthError.signOutFailed(error.localizedDescription)
        }
    }
    
    /// Listen for auth state changes
    func addAuthStateListener(_ callback: @escaping (User?) -> Void) -> AuthStateDidChangeListenerHandle {
        return Auth.auth().addStateDidChangeListener { _, user in
            callback(user)
        }
    }
    
    func removeAuthStateListener(_ handle: AuthStateDidChangeListenerHandle) {
        Auth.auth().removeStateDidChangeListener(handle)
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case otpSendFailed(String)
    case otpVerificationFailed(String)
    case notAuthenticated
    case signOutFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .otpSendFailed(let message):
            return "Failed to send verification code: \(message)"
        case .otpVerificationFailed(let message):
            return "Invalid verification code: \(message)"
        case .notAuthenticated:
            return "User is not authenticated"
        case .signOutFailed(let message):
            return "Failed to sign out: \(message)"
        }
    }
}
