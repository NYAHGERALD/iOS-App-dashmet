//
//  AuthViewModel.swift
//  MeetingIntelligence
//
//  Phase 1 - Authentication View Model with Phone Registration Check
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private let authService = FirebaseAuthService.shared
    
    // MARK: - Published Properties
    @Published var phoneNumber: String = ""
    @Published var otpCode: String = ""
    @Published var authState: AuthState = .enteringPhone
    @Published var errorMessage: String?
    @Published var idToken: String?
    
    // MARK: - Navigation Flags (for SwiftUI refresh)
    @Published var showOTPScreen: Bool = false
    @Published var showSuccessScreen: Bool = false
    @Published var showErrorScreen: Bool = false
    @Published var isSendingOTP: Bool = false
    @Published var isCheckingPhone: Bool = false
    @Published var showRegistration: Bool = false
    @Published var showRegistrationSuccess: Bool = false
    @Published var currentUserID: String?
    @Published var currentVerificationID: String?
    
    // MARK: - Country Code
    @Published var countryCode: String = "+1"
    
    // MARK: - Validation
    var isPhoneValid: Bool {
        // Basic validation: at least 10 digits
        let digitsOnly = phoneNumber.filter { $0.isNumber }
        return digitsOnly.count >= 10
    }
    
    var isOTPValid: Bool {
        // OTP should be 6 digits
        let digitsOnly = otpCode.filter { $0.isNumber }
        return digitsOnly.count == 6
    }
    
    var formattedPhoneNumber: String {
        "\(countryCode)\(phoneNumber.filter { $0.isNumber })"
    }
    
    // MARK: - Actions
    
    /// Check if phone exists in database, then request OTP or show registration
    func checkPhoneAndRequestOTP() async {
        guard isPhoneValid else {
            errorMessage = "Please enter a valid phone number"
            return
        }
        
        errorMessage = nil
        showErrorScreen = false
        isCheckingPhone = true
        
        do {
            // First, check if phone exists in database
            let response = try await APIService.shared.checkPhone(formattedPhoneNumber)
            
            if response.exists {
                // Phone exists - proceed with OTP
                print("✅ Phone exists in database, sending OTP...")
                isCheckingPhone = false
                await requestOTP()
            } else {
                // Phone doesn't exist - show registration
                print("📝 Phone not registered, showing registration...")
                isCheckingPhone = false
                showRegistration = true
            }
        } catch {
            print("❌ Error checking phone: \(error)")
            // If API is unavailable, fall back to direct Firebase auth
            // This allows testing when backend isn't running
            isCheckingPhone = false
            errorMessage = "Unable to verify phone. Please try again."
        }
    }
    
    /// Request OTP for the entered phone number (call after phone check passes)
    func requestOTP() async {
        guard isPhoneValid else {
            errorMessage = "Please enter a valid phone number"
            return
        }
        
        errorMessage = nil
        showErrorScreen = false
        isSendingOTP = true
        authState = .sendingOTP
        print("📤 State: sendingOTP")
        
        do {
            let verificationID = try await authService.sendOTP(to: formattedPhoneNumber)
            print("📥 Got verification ID: \(verificationID.prefix(10))...")
            
            // Update state and navigation flag
            self.currentVerificationID = verificationID
            self.authState = .enteringOTP(verificationID: verificationID)
            self.isSendingOTP = false
            self.showOTPScreen = true
            print("📱 showOTPScreen = true")
            
            print("✅ OTP sent to \(formattedPhoneNumber)")
            
        } catch let error as AuthError {
            print("❌ AuthError: \(error.localizedDescription)")
            isSendingOTP = false
            authState = .error(message: error.localizedDescription)
            errorMessage = error.localizedDescription
            showErrorScreen = true
        } catch {
            print("❌ Error: \(error)")
            isSendingOTP = false
            authState = .error(message: "Failed to send OTP")
            errorMessage = "Failed to send OTP. Please try again."
            showErrorScreen = true
        }
    }
    
    /// Verify the entered OTP code
    func verifyOTP() async {
        guard isOTPValid else {
            errorMessage = "Please enter a valid 6-digit code"
            return
        }
        
        guard let verificationID = currentVerificationID else {
            errorMessage = "Invalid state. Please request OTP again."
            return
        }
        
        errorMessage = nil
        authState = .verifyingOTP
        
        do {
            // Verify OTP and get ID token
            let token = try await authService.verifyOTP(code: otpCode, verificationID: verificationID)
            self.idToken = token
            
            // Get Firebase UID
            guard let firebaseUID = authService.firebaseUID else {
                throw AuthError.notAuthenticated
            }
            
            self.currentUserID = firebaseUID
            authState = .authenticated(userID: firebaseUID)
            showOTPScreen = false
            showSuccessScreen = true
            
            print("✅ OTP verified successfully")
            print("👤 Firebase UID: \(firebaseUID)")
            print("🎫 ID Token obtained")
            
        } catch let error as AuthError {
            print("❌ Auth Error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        } catch let error as NSError {
            print("❌ NSError: \(error.domain) - \(error.code) - \(error.localizedDescription)")
            errorMessage = "Verification failed: \(error.localizedDescription)"
        } catch {
            print("❌ Unknown error: \(error)")
            errorMessage = "Invalid code. Please try again."
        }
    }
    
    /// Reset to phone input state
    func resetToPhoneInput() {
        phoneNumber = ""
        otpCode = ""
        errorMessage = nil
        idToken = nil
        currentVerificationID = nil
        currentUserID = nil
        showOTPScreen = false
        showSuccessScreen = false
        showErrorScreen = false
        isSendingOTP = false
        isCheckingPhone = false
        showRegistration = false
        showRegistrationSuccess = false
        authState = .enteringPhone
        print("🔄 Reset to phone input")
    }
    
    /// Full reset - call on logout
    func fullReset() {
        phoneNumber = ""
        otpCode = ""
        errorMessage = nil
        idToken = nil
        currentVerificationID = nil
        currentUserID = nil
        showOTPScreen = false
        showSuccessScreen = false
        showErrorScreen = false
        isSendingOTP = false
        isCheckingPhone = false
        showRegistration = false
        showRegistrationSuccess = false
        authState = .enteringPhone
        print("🔄 Full auth reset")
    }
    
    /// Go back from OTP to phone input
    func goBackToPhone() {
        otpCode = ""
        errorMessage = nil
        currentVerificationID = nil
        showOTPScreen = false
        isSendingOTP = false
        authState = .enteringPhone
        print("🔄 Go back to phone")
    }
    
    /// Go back from registration to phone input
    func goBackFromRegistration() {
        showRegistration = false
        errorMessage = nil
        print("🔄 Go back from registration")
    }
    
    /// Called after successful registration
    func registrationCompleted() {
        showRegistration = false
        showRegistrationSuccess = true
        print("✅ Registration completed")
    }
    
    /// Called when user taps login on registration success screen
    func proceedToLoginAfterRegistration() {
        showRegistrationSuccess = false
        // Phone number is already filled, just send OTP
        Task {
            await requestOTP()
        }
    }
    
    /// Clear OTP code (call when OTP screen appears)
    func clearOTPCode() {
        otpCode = ""
        errorMessage = nil
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
        showErrorScreen = false
        if case .error = authState {
            authState = .enteringPhone
        }
    }
    
    /// Link Firebase UID to existing user after OTP verification
    /// Returns user profile data if successful
    func linkFirebaseUID() async -> LinkedUserInfo? {
        guard let firebaseUID = authService.firebaseUID else {
            print("❌ No Firebase UID to link")
            return nil
        }
        
        do {
            let response = try await APIService.shared.linkFirebaseUID(
                phone: formattedPhoneNumber,
                firebaseUid: firebaseUID
            )
            
            if response.success, let user = response.user {
                print("✅ Firebase UID linked to user: \(user.id)")
                return user
            } else {
                print("⚠️ Failed to link Firebase UID: \(response.error ?? "Unknown")")
                return nil
            }
        } catch {
            print("⚠️ Error linking Firebase UID: \(error)")
            return nil
        }
    }
}
