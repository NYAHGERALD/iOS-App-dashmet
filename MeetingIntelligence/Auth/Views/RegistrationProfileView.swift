//
//  RegistrationProfileView.swift
//  MeetingIntelligence
//
//  Modern registration form with email-first validation flow
//

import SwiftUI

struct RegistrationProfileView: View {
    @ObservedObject var viewModel: RegistrationViewModel
    let onRegistrationComplete: () -> Void
    let onCancel: () -> Void
    
    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedField: Field?
    @State private var showContent = false
    
    enum Field: Int, CaseIterable {
        case email, firstName, lastName, accessCode
    }
    
    // MARK: - Theme Colors
    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark 
                ? [Color(hex: "6366F1"), Color(hex: "8B5CF6")]
                : [Color(hex: "4F46E5"), Color(hex: "7C3AED")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1E1E2E") : Color.white
    }
    
    private var fieldBackground: Color {
        colorScheme == .dark ? Color(hex: "2A2A3E") : Color(hex: "F8FAFC")
    }
    
    private var disabledFieldBackground: Color {
        colorScheme == .dark ? Color(hex: "1A1A28") : Color(hex: "F1F5F9")
    }
    
    private var subtleText: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "6B7280")
    }
    
    private var primaryText: Color {
        colorScheme == .dark ? Color.white : Color(hex: "111827")
    }
    
    var body: some View {
        ZStack {
            // Animated Background
            backgroundGradient
            
            // Main Content
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Compact Header
                        headerSection
                            .padding(.top, 20)
                            .id("top")
                        
                        // Form Content
                        VStack(spacing: 16) {
                            // Step 1: Email Card (Always active)
                            emailCard
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 20)
                            
                            // Step 2: Personal Info Card (Active after email validated)
                            personalInfoCard
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 20)
                            
                            // Step 3: Access Code Card (Active after email validated)
                            accessCodeCard
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 20)
                            
                            // Step 4: Organization Card (After access code validated)
                            if viewModel.isAccessCodeValidated {
                                organizationCard
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .offset(y: -10)),
                                        removal: .opacity
                                    ))
                            }
                            
                            // Phone Display (Always shown)
                            phoneDisplayCard
                                .opacity(showContent ? 1 : 0)
                            
                            // Error Message
                            if let error = viewModel.errorMessage {
                                errorCard(message: error)
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }
                            
                            // Action Button
                            actionButtons
                                .padding(.top, 8)
                                .opacity(showContent ? 1 : 0)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                    }
                }
                .onChange(of: focusedField) { newField in
                    if newField != nil {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(newField, anchor: .center)
                        }
                    }
                }
            }
            
            // Loading Overlay
            if viewModel.isLoading {
                loadingOverlay
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.isAccessCodeValidated)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isEmailValidated)
        .animation(.easeInOut(duration: 0.3), value: viewModel.errorMessage)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                showContent = true
            }
        }
        .onChange(of: viewModel.registrationComplete) { complete in
            if complete {
                onRegistrationComplete()
            }
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        ZStack {
            (colorScheme == .dark ? Color(hex: "0F0F1A") : Color(hex: "F1F5F9"))
                .ignoresSafeArea()
            
            GeometryReader { geo in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "6366F1").opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: -50, y: -100)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "8B5CF6").opacity(0.25), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 250, height: 250)
                    .blur(radius: 50)
                    .offset(x: geo.size.width - 100, y: geo.size.height - 200)
            }
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    onCancel()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundColor(subtleText)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 4) {
                Text("Create Profile")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(primaryText)
                
                Text("Start with your email address")
                    .font(.subheadline)
                    .foregroundColor(subtleText)
            }
        }
    }
    
    // MARK: - Email Card (Step 1 - Always Active)
    private var emailCard: some View {
        VStack(spacing: 16) {
            // Section Header
            HStack {
                ZStack {
                    Circle()
                        .fill(accentGradient)
                        .frame(width: 24, height: 24)
                    Text("1")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                Text("Email Address")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(primaryText)
                Spacer()
                
                if viewModel.isEmailValidated {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.isEmailFromDatabase ? "person.fill.checkmark" : "checkmark.seal.fill")
                            .font(.system(size: 12))
                        Text(viewModel.isEmailFromDatabase ? "Found" : "New")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(viewModel.isEmailFromDatabase ? Color(hex: "3B82F6") : Color(hex: "10B981"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((viewModel.isEmailFromDatabase ? Color(hex: "3B82F6") : Color(hex: "10B981")).opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            
            HStack(spacing: 10) {
                // Email Input
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(focusedField == .email ? Color(hex: "6366F1") : subtleText)
                    
                    TextField("Enter your email", text: $viewModel.email)
                        .font(.system(size: 15, weight: .medium))
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textContentType(.emailAddress)
                        .disabled(viewModel.isEmailValidated)
                        .focused($focusedField, equals: .email)
                        .onChange(of: viewModel.email) { _ in
                            if viewModel.isEmailValidated {
                                viewModel.resetEmailValidation()
                            }
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(viewModel.isEmailValidated ? Color(hex: "10B981").opacity(0.1) : fieldBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    viewModel.isEmailValidated 
                                        ? Color(hex: "10B981").opacity(0.3)
                                        : (focusedField == .email ? Color(hex: "6366F1") : Color.clear),
                                    lineWidth: focusedField == .email ? 2 : 1
                                )
                        )
                )
                .id(Field.email)
                
                // Check Button
                Button {
                    focusedField = nil
                    Task { await viewModel.checkEmail() }
                } label: {
                    Group {
                        if viewModel.isCheckingEmail {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.9)
                        } else if viewModel.isEmailValidated {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                        } else {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .frame(width: 52, height: 52)
                    .background(
                        viewModel.isEmailValidated 
                            ? Color(hex: "10B981")
                            : (viewModel.canCheckEmail ? Color(hex: "6366F1") : Color.gray.opacity(0.3))
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(
                        color: viewModel.canCheckEmail && !viewModel.isEmailValidated
                            ? Color(hex: "6366F1").opacity(0.4) 
                            : Color.clear,
                        radius: 8, x: 0, y: 4
                    )
                }
                .disabled(!viewModel.canCheckEmail || viewModel.isCheckingEmail)
                .scaleEffect(viewModel.isCheckingEmail ? 0.95 : 1)
                .animation(.spring(response: 0.3), value: viewModel.isCheckingEmail)
            }
            
            // Email Error
            if let error = viewModel.emailError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                    Text(error)
                        .font(.system(size: 13))
                }
                .foregroundColor(Color(hex: "EF4444"))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Helper text
            if !viewModel.isEmailValidated {
                Text("We'll check if you already have an account")
                    .font(.system(size: 12))
                    .foregroundColor(subtleText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if viewModel.isEmailFromDatabase {
                Text("Welcome back! Your profile info has been loaded")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "3B82F6"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 15, x: 0, y: 5)
        )
    }
    
    // MARK: - Personal Info Card (Step 2)
    private var personalInfoCard: some View {
        let isActive = viewModel.isEmailValidated
        
        return VStack(spacing: 16) {
            // Section Header
            HStack {
                ZStack {
                    Circle()
                        .fill(isActive ? accentGradient : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 24, height: 24)
                    Text("2")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                Text("Personal Details")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isActive ? primaryText : subtleText)
                Spacer()
                
                if !viewModel.isNameEditable && isActive {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                        Text("Auto-filled")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(subtleText)
                }
            }
            
            VStack(spacing: 12) {
                // Name Row (side by side)
                HStack(spacing: 12) {
                    // First Name
                    HStack(spacing: 8) {
                        Image(systemName: "person")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(focusedField == .firstName ? Color(hex: "6366F1") : subtleText)
                            .frame(width: 20)
                        
                        TextField("First Name", text: $viewModel.firstName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(primaryText)
                            .disabled(!isActive || !viewModel.isNameEditable)
                            .focused($focusedField, equals: .firstName)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(!isActive ? disabledFieldBackground : (!viewModel.isNameEditable ? disabledFieldBackground : fieldBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        focusedField == .firstName ? Color(hex: "6366F1") : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    )
                    .id(Field.firstName)
                    
                    // Last Name
                    HStack(spacing: 8) {
                        TextField("Last Name", text: $viewModel.lastName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(primaryText)
                            .disabled(!isActive || !viewModel.isNameEditable)
                            .focused($focusedField, equals: .lastName)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(!isActive ? disabledFieldBackground : (!viewModel.isNameEditable ? disabledFieldBackground : fieldBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        focusedField == .lastName ? Color(hex: "6366F1") : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    )
                    .id(Field.lastName)
                }
            }
            
            if !isActive {
                Text("Enter your email first to continue")
                    .font(.system(size: 12))
                    .foregroundColor(subtleText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBackground)
                .opacity(isActive ? 1 : 0.7)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 15, x: 0, y: 5)
        )
    }
    
    // MARK: - Access Code Card (Step 3)
    private var accessCodeCard: some View {
        let isActive = viewModel.isEmailValidated
        
        return VStack(spacing: 16) {
            // Section Header
            HStack {
                ZStack {
                    Circle()
                        .fill(isActive ? accentGradient : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 24, height: 24)
                    Text("3")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                Text("Access Code")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isActive ? primaryText : subtleText)
                Spacer()
                
                if viewModel.isAccessCodeValidated {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                        Text("Verified")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "10B981"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "10B981").opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            
            HStack(spacing: 10) {
                // Code Input
                HStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(focusedField == .accessCode ? Color(hex: "6366F1") : subtleText)
                    
                    TextField("Enter 6-digit code", text: $viewModel.accessCode)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .keyboardType(.numberPad)
                        .disabled(!isActive || viewModel.isAccessCodeValidated)
                        .focused($focusedField, equals: .accessCode)
                        .onChange(of: viewModel.accessCode) { newValue in
                            if newValue.count > 6 {
                                viewModel.accessCode = String(newValue.prefix(6))
                            }
                            if viewModel.isAccessCodeValidated {
                                viewModel.resetAccessCodeValidation()
                            }
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(!isActive ? disabledFieldBackground : (viewModel.isAccessCodeValidated ? Color(hex: "10B981").opacity(0.1) : fieldBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    viewModel.isAccessCodeValidated 
                                        ? Color(hex: "10B981").opacity(0.3)
                                        : (focusedField == .accessCode ? Color(hex: "6366F1") : Color.clear),
                                    lineWidth: focusedField == .accessCode ? 2 : 1
                                )
                        )
                )
                .id(Field.accessCode)
                
                // Validate Button
                Button {
                    focusedField = nil
                    Task { await viewModel.validateAccessCode() }
                } label: {
                    Group {
                        if viewModel.isValidatingCode {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.9)
                        } else if viewModel.isAccessCodeValidated {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                        } else {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .frame(width: 52, height: 52)
                    .background(
                        viewModel.isAccessCodeValidated 
                            ? Color(hex: "10B981")
                            : (viewModel.canValidateAccessCode ? Color(hex: "6366F1") : Color.gray.opacity(0.3))
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(
                        color: viewModel.canValidateAccessCode && !viewModel.isAccessCodeValidated
                            ? Color(hex: "6366F1").opacity(0.4) 
                            : Color.clear,
                        radius: 8, x: 0, y: 4
                    )
                }
                .disabled(!viewModel.canValidateAccessCode || viewModel.isValidatingCode)
                .scaleEffect(viewModel.isValidatingCode ? 0.95 : 1)
                .animation(.spring(response: 0.3), value: viewModel.isValidatingCode)
            }
            
            // Error Message
            if let error = viewModel.accessCodeError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                    Text(error)
                        .font(.system(size: 13))
                }
                .foregroundColor(Color(hex: "EF4444"))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if !isActive {
                Text("Enter your email first to continue")
                    .font(.system(size: 12))
                    .foregroundColor(subtleText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBackground)
                .opacity(isActive ? 1 : 0.7)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 15, x: 0, y: 5)
        )
    }
    
    // MARK: - Organization Card (Step 4)
    private var organizationCard: some View {
        VStack(spacing: 16) {
            // Section Header
            HStack {
                ZStack {
                    Circle()
                        .fill(accentGradient)
                        .frame(width: 24, height: 24)
                    Text("4")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                Text("Organization")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(primaryText)
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Organization Name
                InfoRow(
                    icon: "building.2",
                    iconColor: Color(hex: "6366F1"),
                    label: "Organization",
                    value: viewModel.organizationName,
                    colorScheme: colorScheme
                )
                
                // Role
                InfoRow(
                    icon: "shield.checkered",
                    iconColor: Color(hex: "8B5CF6"),
                    label: "Your Role",
                    value: viewModel.roleDisplayName,
                    colorScheme: colorScheme,
                    isHighlighted: true
                )
                
                // Facility Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Facility")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(subtleText)
                    
                    Menu {
                        ForEach(viewModel.facilities) { facility in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    viewModel.selectedFacility = facility
                                }
                            } label: {
                                HStack {
                                    Text(facility.name)
                                    if viewModel.selectedFacility?.id == facility.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "F59E0B").opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(hex: "F59E0B"))
                            }
                            
                            Text(viewModel.selectedFacility?.name ?? "Select facility")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(viewModel.selectedFacility == nil ? subtleText : primaryText)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(subtleText)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(fieldBackground)
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "6366F1").opacity(0.3), Color(hex: "8B5CF6").opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color(hex: "6366F1").opacity(0.15), radius: 20, x: 0, y: 10)
        )
    }
    
    // MARK: - Phone Display Card
    private var phoneDisplayCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "10B981").opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "phone.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "10B981"))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Phone Number")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(subtleText)
                Text(viewModel.fullPhoneNumber.isEmpty ? viewModel.phoneNumber : viewModel.fullPhoneNumber)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(primaryText)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(hex: "10B981"))
                .font(.system(size: 18))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "10B981").opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Error Card
    private func errorCard(message: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "EF4444").opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "EF4444"))
            }
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "EF4444"))
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "EF4444").opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "EF4444").opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                focusedField = nil
                Task { await viewModel.register() }
            } label: {
                HStack(spacing: 10) {
                    Text("Create Account")
                        .font(.system(size: 17, weight: .semibold))
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Group {
                        if viewModel.canRegister {
                            accentGradient
                        } else {
                            LinearGradient(
                                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(
                    color: viewModel.canRegister ? Color(hex: "6366F1").opacity(0.4) : Color.clear,
                    radius: 12, x: 0, y: 6
                )
            }
            .disabled(!viewModel.canRegister)
            .scaleEffect(viewModel.canRegister ? 1 : 0.98)
            .animation(.spring(response: 0.3), value: viewModel.canRegister)
        }
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .blur(radius: 1)
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: "6366F1").opacity(0.2), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            accentGradient,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .modifier(RotatingModifier())
                }
                
                VStack(spacing: 6) {
                    Text("Creating Account")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(primaryText)
                    
                    Text("Please wait...")
                        .font(.system(size: 14))
                        .foregroundColor(subtleText)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(cardBackground)
                    .shadow(color: Color.black.opacity(0.2), radius: 30, x: 0, y: 15)
            )
        }
    }
}

// MARK: - Info Row Component
struct InfoRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    var colorScheme: ColorScheme
    var isHighlighted: Bool = false
    
    private var fieldBackground: Color {
        colorScheme == .dark ? Color(hex: "2A2A3E") : Color(hex: "F8FAFC")
    }
    
    private var subtleText: Color {
        colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "6B7280")
    }
    
    private var primaryText: Color {
        colorScheme == .dark ? Color.white : Color(hex: "111827")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(subtleText)
            
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(iconColor)
                }
                
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(primaryText)
                
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHighlighted ? iconColor.opacity(0.1) : fieldBackground)
            )
        }
    }
}

// MARK: - Rotating Animation Modifier
struct RotatingModifier: ViewModifier {
    @State private var rotation: Double = 0
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct RegistrationProfileView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RegistrationProfileView(
                viewModel: RegistrationViewModel(),
                onRegistrationComplete: {},
                onCancel: {}
            )
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")
            
            RegistrationProfileView(
                viewModel: RegistrationViewModel(),
                onRegistrationComplete: {},
                onCancel: {}
            )
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}
