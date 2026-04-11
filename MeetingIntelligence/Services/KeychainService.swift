//
//  KeychainService.swift
//  MeetingIntelligence
//
//  Secure storage wrapper for iOS Keychain.
//  Use this instead of UserDefaults for sensitive data
//  (API keys, tokens, user IDs, organization IDs).
//

import Foundation
import Security
import LocalAuthentication

final class KeychainService {
    static let shared = KeychainService()
    
    private let serviceName = "com.dashmet.MeetingIntelligence"
    
    private init() {}
    
    // MARK: - Public API
    
    /// Save a string value to the Keychain
    @discardableResult
    func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return save(data: data, forKey: key)
    }
    
    /// Retrieve a string value from the Keychain
    func getString(forKey key: String) -> String? {
        guard let data = getData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Save raw data to the Keychain
    @discardableResult
    func save(data: Data, forKey key: String) -> Bool {
        // Delete existing item first
        delete(forKey: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Retrieve raw data from the Keychain
    func getData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
    
    /// Delete a value from the Keychain
    @discardableResult
    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Clear all Keychain items for this app
    func clearAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Biometric-Protected Storage
    
    /// Save a value protected by Face ID / Touch ID.
    /// The value can only be retrieved after successful biometric authentication.
    @discardableResult
    func saveBiometric(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        // Delete existing item first
        delete(forKey: key)
        
        // Create access control requiring biometric authentication
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            nil
        ) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl,
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Retrieve a biometric-protected value. Triggers Face ID / Touch ID prompt.
    func getBiometric(forKey key: String, reason: String = "Authenticate to access your account") -> String? {
        let context = LAContext()
        context.localizedReason = reason
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Check if biometric authentication is available on this device
    static var isBiometricAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }
    
    /// Get the biometric type available (Face ID, Touch ID, or none)
    static var biometricType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }
    
    // MARK: - Convenience Keys
    
    struct Keys {
        static let userId = "secure_user_id"
        static let organizationId = "secure_organization_id"
        static let openAIAPIKey = "secure_openai_api_key"
        static let authToken = "secure_auth_token"
    }
}
