//
//  OTPInputView.swift
//  MeetingIntelligence
//
//  Phase 1 - Professional OTP Verification UI
//

import SwiftUI

struct OTPInputView: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var isOTPFocused: Bool
    @State private var resendCountdown: Int = 0
    @State private var timer: Timer?
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.green.opacity(0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Navigation Bar
                HStack {
                    Button {
                        viewModel.goBackToPhone()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                            Text("Back")
                        }
                        .foregroundColor(.blue)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                Spacer()
                    .frame(height: 40)
                
                // Header with Logo
                VStack(spacing: 20) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
                    
                    VStack(spacing: 8) {
                        Text("Verification Code")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("We've sent a 6-digit code to")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(viewModel.formattedPhoneNumber)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                    .frame(height: 40)
                
                // OTP Input Section
                VStack(spacing: 24) {
                    OTPTextField(code: $viewModel.otpCode, isDisabled: viewModel.authState.isLoading)
                        .focused($isOTPFocused)
                    
                    // Error Message
                    if let error = viewModel.errorMessage {
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
                        .padding(.horizontal, 24)
                    }
                    
                    // Resend option
                    HStack(spacing: 4) {
                        Text("Didn't receive the code?")
                            .foregroundColor(.secondary)
                        
                        if resendCountdown > 0 {
                            Text("Resend in \(resendCountdown)s")
                                .foregroundColor(.secondary)
                                .fontWeight(.medium)
                        } else {
                            Button("Resend Code") {
                                Task {
                                    startResendCountdown()
                                    viewModel.otpCode = ""
                                    viewModel.goBackToPhone()
                                    try? await Task.sleep(nanoseconds: 300_000_000)
                                    await viewModel.requestOTP()
                                }
                            }
                            .foregroundColor(.blue)
                            .fontWeight(.semibold)
                        }
                    }
                    .font(.subheadline)
                }
                
                Spacer()
                
                // Verify Button
                VStack(spacing: 16) {
                    Button {
                        isOTPFocused = false
                        Task {
                            await viewModel.verifyOTP()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.authState.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Verify & Continue")
                                    .fontWeight(.semibold)
                                
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Group {
                                if viewModel.isOTPValid {
                                    LinearGradient(
                                        colors: [Color.green, Color.green.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                } else {
                                    LinearGradient(
                                        colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.4)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                }
                            }
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: viewModel.isOTPValid ? Color.green.opacity(0.3) : Color.clear, radius: 10, x: 0, y: 5)
                    }
                    .disabled(!viewModel.isOTPValid || viewModel.authState.isLoading)
                    
                    // Security note
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text("Your information is secure and encrypted")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            isOTPFocused = true
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startResendCountdown() {
        resendCountdown = 30
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if resendCountdown > 0 {
                resendCountdown -= 1
            } else {
                timer?.invalidate()
            }
        }
    }
}

// MARK: - OTP Text Field Component
struct OTPTextField: View {
    @Binding var code: String
    let isDisabled: Bool
    
    private let codeLength = 6
    
    var body: some View {
        ZStack {
            // Hidden TextField for input
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .onChange(of: code) { _, newValue in
                    let filtered = String(newValue.filter { $0.isNumber }.prefix(codeLength))
                    if filtered != newValue {
                        code = filtered
                    }
                }
                .disabled(isDisabled)
            
            // Visual OTP boxes
            HStack(spacing: 10) {
                ForEach(0..<codeLength, id: \.self) { index in
                    OTPDigitBox(
                        digit: getDigit(at: index),
                        isActive: index == code.count && !isDisabled,
                        isFilled: index < code.count
                    )
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    private func getDigit(at index: Int) -> String {
        guard index < code.count else { return "" }
        return String(code[code.index(code.startIndex, offsetBy: index)])
    }
}

struct OTPDigitBox: View {
    let digit: String
    let isActive: Bool
    let isFilled: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(isFilled ? Color.green.opacity(0.1) : Color(.secondarySystemBackground))
                .frame(height: 60)
            
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isActive ? Color.green :
                    isFilled ? Color.green.opacity(0.5) : Color.clear,
                    lineWidth: isActive ? 2 : 1.5
                )
                .frame(height: 60)
            
            if digit.isEmpty {
                if isActive {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.green)
                        .frame(width: 2, height: 28)
                        .opacity(0.8)
                } else {
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 10, height: 10)
                }
            } else {
                Text(digit)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
    }
}

#Preview {
    let vm = AuthViewModel()
    vm.phoneNumber = "1234567890"
    vm.authState = .enteringOTP(verificationID: "test")
    return OTPInputView(viewModel: vm)
}
