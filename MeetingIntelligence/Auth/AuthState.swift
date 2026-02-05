//
//  AuthState.swift
//  MeetingIntelligence
//
//  Phase 1 - Authentication State
//

import Foundation

/// Authentication states for the login flow
enum AuthState: Equatable {
    case idle
    case enteringPhone
    case sendingOTP
    case enteringOTP(verificationID: String)
    case verifyingOTP
    case authenticated(userID: String)
    case error(message: String)
    
    var isLoading: Bool {
        switch self {
        case .sendingOTP, .verifyingOTP:
            return true
        default:
            return false
        }
    }
}
