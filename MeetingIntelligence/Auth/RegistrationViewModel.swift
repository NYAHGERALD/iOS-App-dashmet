//
//  RegistrationViewModel.swift
//  MeetingIntelligence
//
//  Handles user registration flow with email-first validation + email OTP verification
//

import Foundation
import Combine
import LocalAuthentication

@MainActor
class RegistrationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var email: String = ""
    
    // Email validation state
    @Published var isEmailValidated: Bool = false
    @Published var isCheckingEmail: Bool = false
    @Published var emailError: String?
    @Published var isEmailFromDatabase: Bool = false
    @Published var existingUserId: String?
    
    // Name fields state
    @Published var isNameEditable: Bool = true
    
    // Email OTP Verification
    @Published var verificationCode: String = ""
    @Published var isCodeSent: Bool = false
    @Published var isSendingCode: Bool = false
    @Published var isVerifying: Bool = false
    @Published var isVerified: Bool = false
    @Published var verificationError: String?
    @Published var cooldownRemaining: Int = 0
    
    // State
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Registration complete
    @Published var registrationComplete: Bool = false
    @Published var registeredUser: RegisteredUser?
    
    // Phone number (passed from auth flow)
    var phoneNumber: String = ""
    var fullPhoneNumber: String = ""
    var countryCode: String = "+1"
    
    // Cooldown timer
    private var cooldownTimer: Timer?
    
    // MARK: - Computed Properties
    var isEmailFormatValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    var canCheckEmail: Bool {
        isEmailFormatValid && !isCheckingEmail && !isEmailValidated
    }
    
    var isFirstNameValid: Bool {
        firstName.trimmingCharacters(in: .whitespaces).count >= 2
    }
    
    var isLastNameValid: Bool {
        lastName.trimmingCharacters(in: .whitespaces).count >= 2
    }
    
    var canSendVerification: Bool {
        isEmailValidated &&
        isFirstNameValid &&
        isLastNameValid &&
        !isSendingCode &&
        !isVerified &&
        cooldownRemaining == 0
    }
    
    var canVerifyCode: Bool {
        verificationCode.trimmingCharacters(in: .whitespaces).count == 6 &&
        isCodeSent &&
        !isVerifying &&
        !isVerified
    }
    
    var canRegister: Bool {
        isEmailValidated &&
        isFirstNameValid &&
        isLastNameValid &&
        isVerified &&
        !isLoading
    }
    
    // MARK: - Email Validation
    
    func checkEmail() async {
        guard canCheckEmail else { return }
        
        isCheckingEmail = true
        emailError = nil
        
        do {
            let response = try await APIService.shared.checkEmail(email.trimmingCharacters(in: .whitespaces).lowercased())
            
            isEmailValidated = true
            
            if response.exists {
                isEmailFromDatabase = true
                existingUserId = response.userId
                firstName = response.firstName ?? ""
                lastName = response.lastName ?? ""
                isNameEditable = false
            } else {
                isEmailFromDatabase = false
                existingUserId = nil
                isNameEditable = true
            }
        } catch {
            emailError = error.localizedDescription
            isEmailValidated = false
        }
        
        isCheckingEmail = false
    }
    
    func resetEmailValidation() {
        isEmailValidated = false
        isEmailFromDatabase = false
        existingUserId = nil
        emailError = nil
        if !isEmailFromDatabase {
            firstName = ""
            lastName = ""
        }
        isNameEditable = true
        resetVerification()
    }
    
    // MARK: - Email OTP Verification
    
    func sendVerificationCode() async {
        guard canSendVerification else { return }
        
        isSendingCode = true
        verificationError = nil
        
        // Register user first if needed (to get userId for OTP)
        if existingUserId == nil {
            do {
                let request = RegistrationRequest(
                    firstName: firstName.trimmingCharacters(in: .whitespaces),
                    lastName: lastName.trimmingCharacters(in: .whitespaces),
                    email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                    phone: fullPhoneNumber,
                    countryCode: countryCode,
                    accessCodeId: nil,
                    facilityId: nil,
                    firebaseUid: nil
                )
                let response = try await APIService.shared.registerUser(request)
                if response.success, let user = response.user {
                    existingUserId = user.id
                } else {
                    verificationError = response.error ?? "Failed to create profile"
                    isSendingCode = false
                    return
                }
            } catch {
                verificationError = error.localizedDescription
                isSendingCode = false
                return
            }
        }
        
        guard let userId = existingUserId else {
            verificationError = "Unable to identify user"
            isSendingCode = false
            return
        }
        
        do {
            let response = try await APIService.shared.sendVerification(
                userId: userId,
                email: email.trimmingCharacters(in: .whitespaces).lowercased()
            )
            
            if response.success {
                isCodeSent = true
                startCooldown()
            } else {
                verificationError = response.error ?? "Failed to send code"
            }
        } catch {
            verificationError = error.localizedDescription
        }
        
        isSendingCode = false
    }
    
    func verifyCode() async {
        guard canVerifyCode, let userId = existingUserId else { return }
        
        isVerifying = true
        verificationError = nil
        
        do {
            let response = try await APIService.shared.verifyCode(
                userId: userId,
                code: verificationCode.trimmingCharacters(in: .whitespaces)
            )
            
            if response.success {
                isVerified = true
                registeredUser = response.user
                // Store auth token with biometric protection
                if let user = response.user {
                    KeychainService.shared.saveBiometric(user.id, forKey: KeychainService.Keys.userId)
                    KeychainService.shared.save(user.organizationId, forKey: KeychainService.Keys.organizationId)
                }
            } else {
                verificationError = response.error ?? "Invalid code"
            }
        } catch {
            verificationError = error.localizedDescription
        }
        
        isVerifying = false
    }
    
    func completeRegistration() {
        guard isVerified else { return }
        registrationComplete = true
    }
    
    private func resetVerification() {
        verificationCode = ""
        isCodeSent = false
        isSendingCode = false
        isVerifying = false
        isVerified = false
        verificationError = nil
        cooldownRemaining = 0
        cooldownTimer?.invalidate()
        cooldownTimer = nil
    }
    
    private func startCooldown() {
        cooldownRemaining = 60
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else { timer.invalidate(); return }
                if self.cooldownRemaining > 0 {
                    self.cooldownRemaining -= 1
                } else {
                    timer.invalidate()
                    self.cooldownTimer = nil
                }
            }
        }
    }
    
    func reset() {
        firstName = ""
        lastName = ""
        email = ""
        isEmailValidated = false
        isCheckingEmail = false
        emailError = nil
        isEmailFromDatabase = false
        existingUserId = nil
        isNameEditable = true
        isLoading = false
        errorMessage = nil
        registrationComplete = false
        registeredUser = nil
        resetVerification()
    }
}
