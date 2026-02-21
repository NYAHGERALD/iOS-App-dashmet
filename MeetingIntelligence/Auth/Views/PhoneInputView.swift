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
    
    /// Resolved country from the selected code
    private var currentCountry: CountryCode {
        CountryCode.from(code: viewModel.countryCode)
    }
    
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
                                TextField(currentCountry.placeholder, text: $viewModel.phoneNumber)
                                    .keyboardType(.phonePad)
                                    .textContentType(.telephoneNumber)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .focused($isPhoneFocused)
                                    .onChange(of: viewModel.phoneNumber) { _, newValue in
                                        var digits = newValue.filter { $0.isNumber }
                                        let country = currentCountry
                                        
                                        // Strip area code if user accidentally typed it
                                        digits = country.stripAreaCode(from: digits)
                                        
                                        // Enforce max digit count for this country
                                        if digits.count > country.digitCount {
                                            digits = String(digits.prefix(country.digitCount))
                                        }
                                        
                                        // Format the number for display
                                        let formatted = digits.isEmpty ? "" : country.formatPhone(digits)
                                        if viewModel.phoneNumber != formatted {
                                            viewModel.phoneNumber = formatted
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
        .onChange(of: viewModel.countryCode) { _, _ in
            // Clear phone number when user switches country
            viewModel.phoneNumber = ""
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
    
    /// The area code digits without the "+" prefix (used to strip accidental entry)
    var areaCodeDigits: String {
        String(code.dropFirst()) // e.g. "+1" → "1", "+44" → "44"
    }
    
    /// Expected number of local digits (without country code)
    var digitCount: Int {
        switch self {
        case .us:        return 10  // (XXX) XXX-XXXX
        case .uk:        return 10  // XXXX XXX XXXX
        case .india:     return 10  // XXXXX XXXXX
        case .china:     return 11  // XXX XXXX XXXX
        case .japan:     return 10  // XX XXXX XXXX
        case .singapore: return 8   // XXXX XXXX
        case .australia: return 9   // XXX XXX XXX
        case .canada:    return 10  // (XXX) XXX-XXXX
        case .germany:   return 11  // XXXX XXXXXXX
        case .france:    return 9   // X XX XX XX XX
        }
    }
    
    /// Placeholder showing the expected format
    var placeholder: String {
        switch self {
        case .us, .canada: return "(000) 000-0000"
        case .uk:          return "0000 000 0000"
        case .india:       return "00000 00000"
        case .china:       return "000 0000 0000"
        case .japan:       return "00 0000 0000"
        case .singapore:   return "0000 0000"
        case .australia:   return "000 000 000"
        case .germany:     return "0000 0000000"
        case .france:      return "0 00 00 00 00"
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
    
    /// Resolve enum case from a code string like "+1", "+44"
    /// For "+1" defaults to .us (not .canada) since they share the code
    static func from(code: String) -> CountryCode {
        switch code {
        case "+1":  return .us
        case "+44": return .uk
        case "+91": return .india
        case "+86": return .china
        case "+81": return .japan
        case "+65": return .singapore
        case "+61": return .australia
        case "+49": return .germany
        case "+33": return .france
        default:     return .us
        }
    }
    
    /// Format raw digits into a human-readable phone number
    func formatPhone(_ digits: String) -> String {
        let d = digits
        let c = d.count
        switch self {
        case .us, .canada:
            // (XXX) XXX-XXXX
            if c <= 3 {
                return "(\(d)"
            } else if c <= 6 {
                return "(\(d.prefix(3))) \(d.dropFirst(3))"
            } else {
                return "(\(d.prefix(3))) \(d.dropFirst(3).prefix(3))-\(d.dropFirst(6))"
            }
        case .uk:
            // XXXX XXX XXXX
            if c <= 4 {
                return d
            } else if c <= 7 {
                return "\(d.prefix(4)) \(d.dropFirst(4))"
            } else {
                return "\(d.prefix(4)) \(d.dropFirst(4).prefix(3)) \(d.dropFirst(7))"
            }
        case .india:
            // XXXXX XXXXX
            if c <= 5 {
                return d
            } else {
                return "\(d.prefix(5)) \(d.dropFirst(5))"
            }
        case .china:
            // XXX XXXX XXXX
            if c <= 3 {
                return d
            } else if c <= 7 {
                return "\(d.prefix(3)) \(d.dropFirst(3))"
            } else {
                return "\(d.prefix(3)) \(d.dropFirst(3).prefix(4)) \(d.dropFirst(7))"
            }
        case .japan:
            // XX XXXX XXXX
            if c <= 2 {
                return d
            } else if c <= 6 {
                return "\(d.prefix(2)) \(d.dropFirst(2))"
            } else {
                return "\(d.prefix(2)) \(d.dropFirst(2).prefix(4)) \(d.dropFirst(6))"
            }
        case .singapore:
            // XXXX XXXX
            if c <= 4 {
                return d
            } else {
                return "\(d.prefix(4)) \(d.dropFirst(4))"
            }
        case .australia:
            // XXX XXX XXX
            if c <= 3 {
                return d
            } else if c <= 6 {
                return "\(d.prefix(3)) \(d.dropFirst(3))"
            } else {
                return "\(d.prefix(3)) \(d.dropFirst(3).prefix(3)) \(d.dropFirst(6))"
            }
        case .germany:
            // XXXX XXXXXXX
            if c <= 4 {
                return d
            } else {
                return "\(d.prefix(4)) \(d.dropFirst(4))"
            }
        case .france:
            // X XX XX XX XX
            if c <= 1 {
                return d
            } else if c <= 3 {
                return "\(d.prefix(1)) \(d.dropFirst(1))"
            } else if c <= 5 {
                return "\(d.prefix(1)) \(d.dropFirst(1).prefix(2)) \(d.dropFirst(3))"
            } else if c <= 7 {
                return "\(d.prefix(1)) \(d.dropFirst(1).prefix(2)) \(d.dropFirst(3).prefix(2)) \(d.dropFirst(5))"
            } else {
                return "\(d.prefix(1)) \(d.dropFirst(1).prefix(2)) \(d.dropFirst(3).prefix(2)) \(d.dropFirst(5).prefix(2)) \(d.dropFirst(7))"
            }
        }
    }
    
    /// Strip area code digits if the user accidentally typed them at the start
    func stripAreaCode(from digits: String) -> String {
        let ac = areaCodeDigits
        // Only strip if the resulting digit count would match expected length
        // For "+1" countries: if user types 11 digits starting with "1", strip the leading "1"
        // For "+44" countries: if user types 12 digits starting with "44", strip "44"
        if digits.count > digitCount && digits.hasPrefix(ac) {
            let stripped = String(digits.dropFirst(ac.count))
            if stripped.count == digitCount {
                return stripped
            }
        }
        return digits
    }
}

#Preview {
    PhoneInputView(viewModel: AuthViewModel())
}
