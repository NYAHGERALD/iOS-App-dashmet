//
//  RegistrationViewModel.swift
//  MeetingIntelligence
//
//  Handles user registration flow with email-first validation
//

import Foundation
import Combine

@MainActor
class RegistrationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var email: String = ""
    @Published var accessCode: String = ""
    
    // Email validation state
    @Published var isEmailValidated: Bool = false
    @Published var isCheckingEmail: Bool = false
    @Published var emailError: String?
    @Published var isEmailFromDatabase: Bool = false
    @Published var existingUserId: String?
    
    // Name fields state
    @Published var isNameEditable: Bool = true
    
    // Access Code Validation Results
    @Published var isAccessCodeValidated: Bool = false
    @Published var validatedRole: String = ""
    @Published var organizationName: String = ""
    @Published var facilities: [FacilityInfo] = []
    @Published var selectedFacility: FacilityInfo?
    
    // State
    @Published var isLoading: Bool = false
    @Published var isValidatingCode: Bool = false
    @Published var errorMessage: String?
    @Published var accessCodeError: String?
    
    // Registration complete
    @Published var registrationComplete: Bool = false
    @Published var registeredUser: RegisteredUser?
    
    // Phone number (passed from auth flow)
    var phoneNumber: String = ""
    var fullPhoneNumber: String = ""
    
    // Access code ID for registration
    private var accessCodeId: String = ""
    private var organizationId: String = ""
    
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
    
    var isAccessCodeValid: Bool {
        accessCode.trimmingCharacters(in: .whitespaces).count >= 4
    }
    
    var canValidateAccessCode: Bool {
        isAccessCodeValid && !isValidatingCode && isEmailValidated
    }
    
    var canRegister: Bool {
        isEmailValidated &&
        isFirstNameValid &&
        isLastNameValid &&
        isAccessCodeValidated &&
        selectedFacility != nil &&
        !isLoading
    }
    
    var roleDisplayName: String {
        switch validatedRole {
        case "ADMIN": return "Administrator"
        case "SUPERVISOR": return "Supervisor"
        case "OPERATOR": return "Operator"
        case "VIEWER": return "Viewer"
        case "SYSTEM_ADMIN": return "System Administrator"
        default: return validatedRole.capitalized
        }
    }
    
    // MARK: - Email Validation
    
    /// Check if email exists in database and auto-fill user info if found
    func checkEmail() async {
        guard canCheckEmail else { return }
        
        isCheckingEmail = true
        emailError = nil
        
        do {
            let response = try await APIService.shared.checkEmail(email.trimmingCharacters(in: .whitespaces).lowercased())
            
            isEmailValidated = true
            
            if response.exists {
                // Email exists - auto-fill and lock name fields
                isEmailFromDatabase = true
                existingUserId = response.userId
                firstName = response.firstName ?? ""
                lastName = response.lastName ?? ""
                isNameEditable = false
            } else {
                // New email - allow user to enter name
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
    
    /// Reset email validation when email changes
    func resetEmailValidation() {
        isEmailValidated = false
        isEmailFromDatabase = false
        existingUserId = nil
        emailError = nil
        // Also reset dependent fields
        if !isEmailFromDatabase {
            firstName = ""
            lastName = ""
        }
        isNameEditable = true
        resetAccessCodeValidation()
    }
    
    // MARK: - Access Code Validation
    
    /// Validate the access code
    func validateAccessCode() async {
        guard canValidateAccessCode else { return }
        
        isValidatingCode = true
        accessCodeError = nil
        
        do {
            let response = try await APIService.shared.validateAccessCode(accessCode.trimmingCharacters(in: .whitespaces))
            
            if response.valid {
                isAccessCodeValidated = true
                validatedRole = response.role ?? ""
                organizationName = response.organizationName ?? ""
                accessCodeId = response.accessCodeId ?? ""
                organizationId = response.organizationId ?? ""
                facilities = response.facilities ?? []
                
                // Auto-select if only one facility
                if facilities.count == 1 {
                    selectedFacility = facilities.first
                }
            } else {
                isAccessCodeValidated = false
                accessCodeError = response.error ?? "Invalid access code"
            }
        } catch {
            accessCodeError = error.localizedDescription
            isAccessCodeValidated = false
        }
        
        isValidatingCode = false
    }
    
    /// Reset access code validation
    func resetAccessCodeValidation() {
        isAccessCodeValidated = false
        validatedRole = ""
        organizationName = ""
        facilities = []
        selectedFacility = nil
        accessCodeError = nil
        accessCodeId = ""
        organizationId = ""
    }
    
    /// Register the user
    func register() async {
        guard canRegister else { return }
        guard let facility = selectedFacility else { return }
        
        isLoading = true
        errorMessage = nil
        
        let request = RegistrationRequest(
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces).lowercased(),
            phone: fullPhoneNumber,
            accessCodeId: accessCodeId,
            facilityId: facility.id,
            firebaseUid: nil // Will be linked after phone auth
        )
        
        do {
            let response = try await APIService.shared.registerUser(request)
            
            if response.success {
                registeredUser = response.user
                registrationComplete = true
            } else {
                errorMessage = response.error ?? "Registration failed"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Reset all fields
    func reset() {
        firstName = ""
        lastName = ""
        email = ""
        accessCode = ""
        isEmailValidated = false
        isCheckingEmail = false
        emailError = nil
        isEmailFromDatabase = false
        existingUserId = nil
        isNameEditable = true
        isAccessCodeValidated = false
        validatedRole = ""
        organizationName = ""
        facilities = []
        selectedFacility = nil
        isLoading = false
        isValidatingCode = false
        errorMessage = nil
        accessCodeError = nil
        registrationComplete = false
        registeredUser = nil
        accessCodeId = ""
        organizationId = ""
    }
    
    /// Get organization ID for the registered user
    var userOrganizationId: String {
        organizationId
    }
}
