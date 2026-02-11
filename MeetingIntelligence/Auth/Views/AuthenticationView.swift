//
//  AuthenticationView.swift
//  MeetingIntelligence
//
//  Phase 1 - Main Authentication View with Registration Flow
//

import SwiftUI

struct AuthenticationView: View {
    @ObservedObject var viewModel: AuthViewModel
    @EnvironmentObject var appState: AppState
    let onAuthenticated: (String, String?) -> Void  // (userID, idToken)
    
    @State private var currentScreen: AuthScreen = .phone
    @StateObject private var registrationViewModel = RegistrationViewModel()
    
    enum AuthScreen {
        case phone, otp, success, error, registration, registrationSuccess
    }
    
    var body: some View {
        ZStack {
            // Main content
            Group {
                switch currentScreen {
                case .phone:
                    PhoneInputView(viewModel: viewModel)
                        .onAppear {
                            if !viewModel.showOTPScreen {
                                viewModel.clearOTPCode()
                            }
                        }
                case .otp:
                    OTPInputView(viewModel: viewModel)
                case .success:
                    AuthSuccessView(userID: viewModel.currentUserID ?? "")
                        .onAppear {
                            // Link Firebase UID to user in database and get profile
                            Task {
                                if let user = await viewModel.linkFirebaseUID() {
                                    // Save user profile to AppState
                                    appState.setUserProfile(
                                        userId: user.id,
                                        firstName: user.firstName,
                                        lastName: user.lastName,
                                        organizationId: user.organizationId ?? "",
                                        facilityId: user.facilityId,
                                        role: user.role ?? ""
                                    )
                                }
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                // Use database user ID if available, fallback to Firebase UID
                                let userID = appState.currentUserID ?? viewModel.currentUserID ?? ""
                                onAuthenticated(userID, viewModel.idToken)
                            }
                        }
                case .error:
                    AuthErrorView(message: viewModel.errorMessage ?? "Unknown error") {
                        viewModel.resetToPhoneInput()
                        currentScreen = .phone
                    }
                case .registration:
                    RegistrationProfileView(
                        viewModel: registrationViewModel,
                        onRegistrationComplete: {
                            // Save user profile to AppState
                            if let user = registrationViewModel.registeredUser {
                                appState.setUserProfile(
                                    userId: user.id,
                                    firstName: user.firstName,
                                    lastName: user.lastName,
                                    organizationId: user.organizationId,
                                    facilityId: user.facilityId,
                                    role: user.role
                                )
                            }
                            viewModel.registrationCompleted()
                        },
                        onCancel: {
                            viewModel.goBackFromRegistration()
                        }
                    )
                    .onAppear {
                        // Pass phone number to registration view model
                        registrationViewModel.phoneNumber = viewModel.phoneNumber
                        registrationViewModel.fullPhoneNumber = viewModel.formattedPhoneNumber
                    }
                case .registrationSuccess:
                    RegistrationSuccessView {
                        viewModel.proceedToLoginAfterRegistration()
                    }
                }
            }
            
            // Loading overlay during OTP send
            if viewModel.isSendingOTP {
                loadingOverlay(message: "Sending verification code...")
            }
            
            // Loading overlay during phone check
            if viewModel.isCheckingPhone {
                loadingOverlay(message: "Verifying phone number...")
            }
        }
        .onAppear {
            if !viewModel.showOTPScreen && !viewModel.showSuccessScreen && !viewModel.showRegistration {
                currentScreen = .phone
            }
        }
        .onChange(of: viewModel.showOTPScreen) { _, newValue in
            print("🔄 onChange showOTPScreen: \(newValue)")
            if newValue {
                currentScreen = .otp
            } else if !viewModel.showSuccessScreen && !viewModel.showRegistration && !viewModel.showRegistrationSuccess {
                currentScreen = .phone
            }
        }
        .onChange(of: viewModel.showSuccessScreen) { _, newValue in
            print("🔄 onChange showSuccessScreen: \(newValue)")
            if newValue {
                currentScreen = .success
            }
        }
        .onChange(of: viewModel.showErrorScreen) { _, newValue in
            print("🔄 onChange showErrorScreen: \(newValue)")
            if newValue {
                currentScreen = .error
            }
        }
        .onChange(of: viewModel.showRegistration) { _, newValue in
            print("🔄 onChange showRegistration: \(newValue)")
            if newValue {
                currentScreen = .registration
            } else if !viewModel.showRegistrationSuccess {
                currentScreen = .phone
            }
        }
        .onChange(of: viewModel.showRegistrationSuccess) { _, newValue in
            print("🔄 onChange showRegistrationSuccess: \(newValue)")
            if newValue {
                currentScreen = .registrationSuccess
            } else if !viewModel.showOTPScreen {
                currentScreen = .phone
            }
        }
        .onReceive(viewModel.$showOTPScreen) { value in
            if value && currentScreen != .otp {
                currentScreen = .otp
            }
        }
    }
    
    // MARK: - Loading Overlay
    private func loadingOverlay(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 70, height: 70)
                    ProgressView()
                        .scaleEffect(1.3)
                        .tint(.blue)
                }
                Text(message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(width: 240, height: 160)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
            )
        }
    }
}

// MARK: - Success View
struct AuthSuccessView: View {
    let userID: String
    @State private var showCheckmark = false
    @State private var showText = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.green.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Animated checkmark
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 140, height: 140)
                        .scaleEffect(showCheckmark ? 1 : 0.5)
                        .opacity(showCheckmark ? 1 : 0)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: Color.green.opacity(0.3), radius: 20, x: 0, y: 10)
                        .scaleEffect(showCheckmark ? 1 : 0)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(showCheckmark ? 1 : 0)
                }
                
                VStack(spacing: 12) {
                    Text("Welcome!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .opacity(showText ? 1 : 0)
                        .offset(y: showText ? 0 : 20)
                    
                    Text("Authentication successful")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .opacity(showText ? 1 : 0)
                        .offset(y: showText ? 0 : 20)
                }
                
                Spacer()
                
                // Loading indicator
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Setting up your account...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .opacity(showText ? 1 : 0)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showCheckmark = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                showText = true
            }
        }
    }
}

// MARK: - Error View
struct AuthErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.red.opacity(0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Error Icon
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.red, Color.red.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                VStack(spacing: 12) {
                    Text("Authentication Failed")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Spacer()
                
                // Retry Button
                Button {
                    onRetry()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.subheadline.weight(.semibold))
                        Text("Try Again")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    AuthenticationView(viewModel: AuthViewModel()) { userID, token in
        print("Authenticated: \(userID), token: \(token?.prefix(20) ?? "none")...")
    }
    .environmentObject(AppState())
}
