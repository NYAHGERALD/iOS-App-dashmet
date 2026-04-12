//
//  PhoneChangeVerificationView.swift
//  MeetingIntelligence
//
//  Shown after phone login when the user's phone number has been changed.
//  Requires email OTP verification before granting app access.
//

import SwiftUI

struct PhoneChangeVerificationView: View {
    let userId: String
    let email: String
    let onVerified: () -> Void
    let onCancel: () -> Void
    
    // MARK: - State
    @State private var verificationCode: String = ""
    @State private var isSending: Bool = false
    @State private var isVerifying: Bool = false
    @State private var codeSent: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    // MARK: - Animation
    @State private var iconAppeared = false
    @State private var contentAppeared = false
    
    @FocusState private var isCodeFocused: Bool
    
    private var maskedEmail: String {
        guard email.contains("@") else { return email }
        let parts = email.split(separator: "@", maxSplits: 1)
        guard let local = parts.first, let domain = parts.last else { return email }
        if local.count <= 2 {
            return "\(local)***@\(domain)"
        }
        let prefix = local.prefix(2)
        return "\(prefix)***@\(domain)"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                // MARK: - Security Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.12), Color.orange.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.orange, Color.red.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(iconAppeared ? 1.0 : 0.5)
                .opacity(iconAppeared ? 1.0 : 0)
                
                // MARK: - Title & Description
                VStack(spacing: 12) {
                    Text("Phone Number Changed")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("We detected that your phone number has been changed. For your security, please verify your identity by entering a code sent to your email.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                    
                    if !email.isEmpty {
                        Text(maskedEmail)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 20)
                
                // MARK: - Send Code / Enter Code
                VStack(spacing: 16) {
                    if !codeSent {
                        // Send verification code button
                        Button {
                            Task { await sendCode() }
                        } label: {
                            HStack(spacing: 8) {
                                if isSending {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "envelope.fill")
                                    Text("Send Verification Code")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(isSending)
                    } else {
                        // Code input field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Verification Code")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("Enter 6-digit code", text: $verificationCode)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.center)
                                .padding(16)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(14)
                                .focused($isCodeFocused)
                                .onChange(of: verificationCode) { _, newValue in
                                    // Limit to 6 digits
                                    let digits = newValue.filter { $0.isNumber }
                                    if digits.count > 6 {
                                        verificationCode = String(digits.prefix(6))
                                    } else if digits != newValue {
                                        verificationCode = digits
                                    }
                                }
                        }
                        
                        // Verify button
                        Button {
                            Task { await verifyCode() }
                        } label: {
                            HStack(spacing: 8) {
                                if isVerifying {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "checkmark.shield.fill")
                                    Text("Verify Identity")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                verificationCode.count == 6
                                    ? LinearGradient(colors: [Color.green, Color.green.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(verificationCode.count != 6 || isVerifying)
                        
                        // Resend button
                        Button {
                            Task { await sendCode() }
                        } label: {
                            Text("Resend Code")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .disabled(isSending)
                    }
                    
                    // Error message
                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Success message
                    if let success = successMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(success)
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .opacity(contentAppeared ? 1 : 0)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // MARK: - Sign Out Button
            Button {
                onCancel()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left")
                    Text("Sign Out")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                iconAppeared = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                contentAppeared = true
            }
        }
    }
    
    // MARK: - Actions
    
    private func sendCode() async {
        isSending = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let response = try await APIService.shared.sendPhoneChangeVerification(userId: userId)
            if response.success {
                codeSent = true
                successMessage = response.message ?? "Verification code sent to your email"
                isCodeFocused = true
            } else {
                errorMessage = response.error ?? "Failed to send code"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSending = false
    }
    
    private func verifyCode() async {
        isVerifying = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let response = try await APIService.shared.verifyPhoneChange(userId: userId, code: verificationCode)
            if response.success {
                successMessage = "Identity verified!"
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                onVerified()
            } else {
                errorMessage = response.error ?? "Verification failed"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isVerifying = false
    }
}
