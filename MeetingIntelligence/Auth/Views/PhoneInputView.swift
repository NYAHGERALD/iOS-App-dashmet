//
//  PhoneInputView.swift
//  MeetingIntelligence
//
//  Phase 1 - Professional Phone Number Input UI
//

import SwiftUI

struct PhoneInputView: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var isPhoneFocused: Bool
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)
                
                // Logo & Header
                VStack(spacing: 20) {
                    // App Logo
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                    
                    VStack(spacing: 8) {
                        Text("Meeting Intelligence")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Sign in to continue")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                    .frame(height: 50)
                
                // Phone Input Card
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Phone Number")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            // Country Code Picker
                            Menu {
                                ForEach(CountryCode.allCases, id: \.self) { country in
                                    Button {
                                        viewModel.countryCode = country.code
                                    } label: {
                                        HStack {
                                            Text(country.flag)
                                            Text(country.name)
                                            Spacer()
                                            Text(country.code)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(CountryCode.flag(for: viewModel.countryCode))
                                        .font(.title2)
                                    Text(viewModel.countryCode)
                                        .fontWeight(.semibold)
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 16)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(14)
                            }
                            
                            // Phone Number Field
                            HStack {
                                TextField("000 000 0000", text: $viewModel.phoneNumber)
                                    .keyboardType(.phonePad)
                                    .textContentType(.telephoneNumber)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .focused($isPhoneFocused)
                                    .onChange(of: viewModel.phoneNumber) { _, newValue in
                                        let digits = newValue.filter { $0.isNumber }
                                        if digits.count > 10 {
                                            viewModel.phoneNumber = String(digits.prefix(10))
                                        }
                                    }
                                
                                if !viewModel.phoneNumber.isEmpty {
                                    Button {
                                        viewModel.phoneNumber = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(14)
                        }
                    }
                    
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
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Bottom Section
                VStack(spacing: 16) {
                    // Continue Button
                    Button {
                        isPhoneFocused = false
                        Task {
                            await viewModel.checkPhoneAndRequestOTP()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.authState.isLoading || viewModel.isCheckingPhone {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Continue")
                                    .fontWeight(.semibold)
                                
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Group {
                                if viewModel.isPhoneValid {
                                    LinearGradient(
                                        colors: [Color.blue, Color.blue.opacity(0.8)],
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
                        .shadow(color: viewModel.isPhoneValid ? Color.blue.opacity(0.3) : Color.clear, radius: 10, x: 0, y: 5)
                    }
                    .disabled(!viewModel.isPhoneValid || viewModel.authState.isLoading || viewModel.isCheckingPhone)
                    
                    // Terms text
                    Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onTapGesture {
            isPhoneFocused = false
        }
    }
}

// MARK: - Country Code Helper
enum CountryCode: CaseIterable {
    case us, uk, india, china, japan, singapore, australia, canada, germany, france
    
    var code: String {
        switch self {
        case .us: return "+1"
        case .uk: return "+44"
        case .india: return "+91"
        case .china: return "+86"
        case .japan: return "+81"
        case .singapore: return "+65"
        case .australia: return "+61"
        case .canada: return "+1"
        case .germany: return "+49"
        case .france: return "+33"
        }
    }
    
    var flag: String {
        switch self {
        case .us: return "🇺🇸"
        case .uk: return "🇬🇧"
        case .india: return "🇮🇳"
        case .china: return "🇨🇳"
        case .japan: return "🇯🇵"
        case .singapore: return "🇸🇬"
        case .australia: return "🇦🇺"
        case .canada: return "🇨🇦"
        case .germany: return "🇩🇪"
        case .france: return "🇫🇷"
        }
    }
    
    var name: String {
        switch self {
        case .us: return "United States"
        case .uk: return "United Kingdom"
        case .india: return "India"
        case .china: return "China"
        case .japan: return "Japan"
        case .singapore: return "Singapore"
        case .australia: return "Australia"
        case .canada: return "Canada"
        case .germany: return "Germany"
        case .france: return "France"
        }
    }
    
    static func flag(for code: String) -> String {
        allCases.first { $0.code == code }?.flag ?? "🌍"
    }
}

#Preview {
    PhoneInputView(viewModel: AuthViewModel())
}
