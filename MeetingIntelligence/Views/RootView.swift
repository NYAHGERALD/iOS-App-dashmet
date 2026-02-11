//
//  RootView.swift
//  MeetingIntelligence
//
//  Phase 0 - Root View with initialization
//

import SwiftUI
import UIKit

struct RootView: View {
    @StateObject private var appState = AppState()
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        Group {
            if appState.isLoading {
                SplashView()
            } else if let error = appState.errorMessage {
                ErrorView(message: error) {
                    appState.clearError()
                }
            } else if !appState.isAuthenticated {
                // Phase 1: Show authentication
                AuthenticationView(viewModel: authViewModel) { userID, token in
                    appState.setAuthenticated(userID: userID, token: token)
                }
            } else {
                // Authenticated - show main app
                MainTabView(onLogout: {
                    authViewModel.fullReset()
                })
            }
        }
        .task {
            await appState.initialize()
        }
        .environmentObject(appState)
    }
}

// MARK: - Splash View (Loading)
struct SplashView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background gradient
            AppGradients.heroBackground
                .ignoresSafeArea()
            
            VStack(spacing: AppSpacing.lg) {
                // Animated logo
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 4)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: AppSpacing.xs) {
                    Text("MeetingIQ")
                        .font(AppTypography.title)
                        .foregroundColor(.white)
                    
                    Text("System-Powered Meeting Intelligence")
                        .font(AppTypography.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Error View
struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(AppGradients.warning)
            
            Text("Something went wrong")
                .font(AppTypography.title2)
                .foregroundColor(AppColors.textPrimary)
            
            Text(message)
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            
            Button(action: onRetry) {
                Text("Try Again")
                    .primaryButtonStyle()
            }
            .frame(width: 200)
        }
        .padding(AppSpacing.xl)
    }
}

// MARK: - Main Tab View (Authenticated Home)
struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Tab = .dashboard
    @State private var showProfile = false
    var onLogout: () -> Void
    
    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case meetings = "Meetings"
        case actionItems = "Action Items"
        case hrConflict = "HR"
        case aiVision = "System Vision"
        case toDo = "To Do"
        
        var icon: String {
            switch self {
            case .dashboard: return "square.grid.2x2"
            case .meetings: return "mic.fill"
            case .actionItems: return "checklist"
            case .hrConflict: return "person.2.badge.gearshape"
            case .aiVision: return "eye"
            case .toDo: return "checkmark.circle"
            }
        }
        
        var selectedIcon: String {
            switch self {
            case .dashboard: return "square.grid.2x2.fill"
            case .meetings: return "mic.fill"
            case .actionItems: return "checklist"
            case .hrConflict: return "person.2.badge.gearshape.fill"
            case .aiVision: return "eye.fill"
            case .toDo: return "checkmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView(onProfileTap: { showProfile = true })
                case .meetings:
                    MeetingListView()
                case .actionItems:
                    TaskListView()
                case .hrConflict:
                    ConflictResolutionView()
                case .aiVision:
                    AIVisionAssistantView()
                case .toDo:
                    ToDoView()
                }
            }
            .padding(.bottom, 80) // Space for custom tab bar
            
            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showProfile) {
            EnterpriseProfileView(onLogout: onLogout)
        }
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: MainTabView.Tab
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTabView.Tab.allCases, id: \.self) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            // Glassmorphism background with beveled edges
            ZStack {
                // Base glass layer
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                
                // Inner highlight for bevel effect (top-left light)
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                colorScheme == .dark ? Color.white.opacity(0.2) : Color.white.opacity(0.8),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                
                // Outer shadow for bevel effect (bottom-right dark)
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blur(radius: 0.5)
            }
        )
        // Floating shadow
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.5) : Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        // Floating margins
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }
}

struct TabBarButton: View {
    let tab: MainTabView.Tab
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    // Colorful icon colors for each tab
    var tabColor: Color {
        switch tab {
        case .dashboard: return Color(hex: "6366F1") // Indigo
        case .meetings: return Color(hex: "EF4444")  // Red
        case .actionItems: return Color(hex: "10B981") // Emerald
        case .hrConflict: return Color(hex: "8B5CF6") // Purple
        case .aiVision: return Color(hex: "3B82F6")  // Blue
        case .toDo: return Color(hex: "F59E0B")  // Amber
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? tabColor : (colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4)))
                    .frame(height: 24)
                
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? tabColor : (colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4)))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(tabColor.opacity(colorScheme == .dark ? 0.2 : 0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(tabColor.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Enterprise Profile View
struct EnterpriseProfileView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var meetingViewModel = MeetingViewModel()
    @StateObject private var taskViewModel = TaskViewModel()
    
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isUploadingPhoto = false
    @State private var showPhotoOptions = false
    @State private var isLoadingProfile = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var onLogout: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Profile Header
                    profileHeader
                    
                    // Stats Summary
                    statsSummary
                    
                    // Settings Sections
                    settingsSection
                    
                    // Logout
                    logoutSection
                }
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .refreshable {
                await loadUserProfile()
            }
            .task {
                // Configure view models
                if let userId = appState.currentUserID {
                    meetingViewModel.configure(userId: userId, organizationId: appState.organizationId)
                    taskViewModel.configure(userId: userId, organizationId: appState.organizationId)
                    await meetingViewModel.fetchMeetings()
                    await taskViewModel.fetchTasks()
                }
                // Load fresh profile data
                await loadUserProfile()
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .onChange(of: selectedImage) { _, newImage in
                if let image = newImage {
                    Task {
                        await uploadProfilePicture(image)
                    }
                }
            }
            .confirmationDialog("Profile Photo", isPresented: $showPhotoOptions) {
                Button("Choose from Library") {
                    showImagePicker = true
                }
                if appState.profilePictureUrl != nil {
                    Button("Remove Photo", role: .destructive) {
                        Task {
                            await deleteProfilePicture()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }
    
    private func loadUserProfile() async {
        guard let token = appState.idToken else { return }
        
        isLoadingProfile = true
        do {
            let response = try await APIService.shared.getCurrentUserProfile(token: token)
            if response.success, let userData = response.data?.user {
                await MainActor.run {
                    appState.setUserProfile(
                        userId: userData.id,
                        firstName: userData.firstName,
                        lastName: userData.lastName,
                        organizationId: userData.organizationId ?? appState.organizationId ?? "",
                        facilityId: appState.facilityId,
                        role: userData.role ?? appState.userRole ?? "user",
                        email: userData.email,
                        profilePictureUrl: userData.profilePicture
                    )
                }
            }
        } catch {
            print("❌ Error loading profile: \(error)")
        }
        isLoadingProfile = false
    }
    
    private func uploadProfilePicture(_ image: UIImage) async {
        guard let token = appState.idToken else { return }
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        isUploadingPhoto = true
        do {
            let response = try await APIService.shared.uploadProfilePicture(imageData: imageData, token: token)
            if response.success, let data = response.data {
                await MainActor.run {
                    appState.updateProfilePicture(data.profilePicture)
                    selectedImage = nil
                }
            } else {
                errorMessage = response.error ?? "Failed to upload photo"
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isUploadingPhoto = false
    }
    
    private func deleteProfilePicture() async {
        guard let token = appState.idToken else { return }
        
        isUploadingPhoto = true
        do {
            let response = try await APIService.shared.deleteProfilePicture(token: token)
            if response.success {
                await MainActor.run {
                    appState.updateProfilePicture(nil)
                }
            } else {
                errorMessage = response.error ?? "Failed to remove photo"
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isUploadingPhoto = false
    }
    
    private var profileHeader: some View {
        VStack(spacing: AppSpacing.md) {
            // Avatar with edit button
            ZStack {
                // Profile Picture
                if let urlString = appState.profilePictureUrl,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 100, height: 100)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        case .failure:
                            defaultAvatar
                        @unknown default:
                            defaultAvatar
                        }
                    }
                } else {
                    defaultAvatar
                }
                
                // Upload overlay
                if isUploadingPhoto {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 100, height: 100)
                    ProgressView()
                        .tint(.white)
                }
                
                // Edit button
                Button {
                    showPhotoOptions = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(AppColors.primary)
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                }
                .offset(x: 35, y: 35)
                .disabled(isUploadingPhoto)
            }
            
            VStack(spacing: 4) {
                Text(displayName)
                    .font(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
                
                if let email = appState.email {
                    Text(email)
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            // Role badge
            if let role = appState.userRole {
                HStack(spacing: 6) {
                    Image(systemName: roleIcon(for: role))
                        .font(.caption)
                    Text(roleDisplayName(for: role))
                        .font(AppTypography.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(roleColor(for: role))
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 6)
                .background(roleColor(for: role).opacity(0.15))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
        .background(AppColors.surfaceElevated)
    }
    
    private var defaultAvatar: some View {
        ZStack {
            Circle()
                .fill(AppGradients.primary)
                .frame(width: 100, height: 100)
            
            Text(initials)
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private var displayName: String {
        let first = appState.firstName ?? ""
        let last = appState.lastName ?? ""
        if first.isEmpty && last.isEmpty {
            return "User"
        }
        return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
    }
    
    private var initials: String {
        let first = appState.firstName?.first.map(String.init) ?? ""
        let last = appState.lastName?.first.map(String.init) ?? ""
        if first.isEmpty && last.isEmpty {
            return "U"
        }
        return "\(first)\(last)"
    }
    
    private func roleIcon(for role: String) -> String {
        switch role.lowercased() {
        case "system_admin": return "shield.checkered"
        case "admin": return "crown.fill"
        case "supervisor": return "person.badge.key.fill"
        case "staff", "user": return "person.fill"
        default: return "person.fill"
        }
    }
    
    private func roleDisplayName(for role: String) -> String {
        switch role.lowercased() {
        case "system_admin": return "System Admin"
        case "admin": return "Administrator"
        case "supervisor": return "Supervisor"
        case "staff": return "Staff"
        case "user": return "User"
        default: return role.capitalized
        }
    }
    
    private func roleColor(for role: String) -> Color {
        switch role.lowercased() {
        case "system_admin": return AppColors.error
        case "admin": return AppColors.warning
        case "supervisor": return AppColors.primary
        default: return AppColors.success
        }
    }
    
    private var statsSummary: some View {
        HStack(spacing: AppSpacing.md) {
            ProfileStat(value: "\(meetingViewModel.meetings.count)", label: "Meetings", icon: "video.fill")
            ProfileStat(value: formattedTotalDuration, label: "Recorded", icon: "clock.fill")
            ProfileStat(value: "\(taskViewModel.tasks.count)", label: "Tasks", icon: "checkmark.circle.fill")
        }
        .padding(.horizontal, AppSpacing.md)
    }
    
    private var formattedTotalDuration: String {
        let totalSeconds = meetingViewModel.meetings.compactMap { $0.duration }.reduce(0, +)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        }
        return "0m"
    }
    
    private var settingsSection: some View {
        VStack(spacing: AppSpacing.xs) {
            SectionHeader(title: "Settings")
            
            VStack(spacing: 0) {
                SettingsRow(icon: "person.fill", title: "Account", color: AppColors.primary)
                Divider().padding(.leading, 56)
                SettingsRow(icon: "bell.fill", title: "Notifications", color: AppColors.warning)
                Divider().padding(.leading, 56)
                SettingsRow(icon: "lock.fill", title: "Privacy", color: AppColors.success)
                Divider().padding(.leading, 56)
                SettingsRow(icon: "gear", title: "Preferences", color: AppColors.textSecondary)
                Divider().padding(.leading, 56)
                SettingsRow(icon: "questionmark.circle.fill", title: "Help & Support", color: AppColors.info)
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large))
            .padding(.horizontal, AppSpacing.md)
        }
    }
    
    private var logoutSection: some View {
        Button {
            onLogout()
            appState.logout()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign Out")
            }
            .font(AppTypography.headline)
            .foregroundColor(AppColors.error)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.error.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.md)
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct ProfileStat: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(AppColors.primary)
            
            Text(value)
                .font(AppTypography.title3)
                .foregroundColor(AppColors.textPrimary)
            
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.md)
        .cardStyle()
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        Button {
            // Navigate to setting
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text(title)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - API Key Configuration Sheet
struct APIKeyConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var apiKey: String
    @State private var tempAPIKey: String = ""
    @State private var isValidating = false
    @State private var validationResult: ValidationResult?
    @State private var showAPIKey = false
    @FocusState private var isTextFieldFocused: Bool
    
    enum ValidationResult {
        case success
        case failure(String)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Header Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.accent, AppColors.primary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "key.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                    .padding(.top, AppSpacing.xl)
                    
                    // Title and Description
                    VStack(spacing: AppSpacing.sm) {
                        Text("OpenAI API Key")
                            .font(AppTypography.title2)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Enter your OpenAI API key to enable enterprise-grade transcription using Whisper.")
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.lg)
                    }
                    
                    // API Key Input
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("API Key")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                        
                        HStack(spacing: AppSpacing.sm) {
                            if showAPIKey {
                                TextField("sk-proj-...", text: $tempAPIKey)
                                    .font(.system(.body, design: .monospaced))
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .textContentType(.none)
                            } else {
                                SecureField("sk-proj-...", text: $tempAPIKey)
                                    .font(.system(.body, design: .monospaced))
                                    .textContentType(.none)
                            }
                            
                            Button {
                                showAPIKey.toggle()
                            } label: {
                                Image(systemName: showAPIKey ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                        .focused($isTextFieldFocused)
                        
                        // Validation Result
                        if let result = validationResult {
                            HStack(spacing: AppSpacing.xs) {
                                switch result {
                                case .success:
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppColors.success)
                                    Text("API key is valid")
                                        .foregroundColor(AppColors.success)
                                case .failure(let message):
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(AppColors.error)
                                    Text(message)
                                        .foregroundColor(AppColors.error)
                                }
                            }
                            .font(AppTypography.caption)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    
                    // How to get API Key
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("How to get an API key")
                            .font(AppTypography.headline)
                            .foregroundColor(AppColors.textPrimary)
                        
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            StepRow(number: 1, text: "Go to platform.openai.com")
                            StepRow(number: 2, text: "Sign in or create an account")
                            StepRow(number: 3, text: "Navigate to API Keys section")
                            StepRow(number: 4, text: "Create a new secret key")
                            StepRow(number: 5, text: "Copy and paste it here")
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                    }
                    .padding(.horizontal, AppSpacing.md)
                    
                    // Security Note
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(AppColors.success)
                        
                        Text("Your API key is stored securely on your device and never shared.")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.success.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                    .padding(.horizontal, AppSpacing.md)
                    
                    Spacer(minLength: AppSpacing.xxl)
                    
                    // Save Button
                    Button {
                        saveAPIKey()
                    } label: {
                        Group {
                            if isValidating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Save API Key")
                                    .font(AppTypography.headline)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(
                            LinearGradient(
                                colors: tempAPIKey.isEmpty ? 
                                    [AppColors.textTertiary, AppColors.textTertiary] :
                                    [AppColors.primary, AppColors.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large))
                    }
                    .disabled(tempAPIKey.isEmpty || isValidating)
                    .padding(.horizontal, AppSpacing.md)
                    
                    // Remove Key Button (if already configured)
                    if !apiKey.isEmpty {
                        Button {
                            removeAPIKey()
                        } label: {
                            Text("Remove API Key")
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.error)
                        }
                        .padding(.bottom, AppSpacing.lg)
                    }
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Configure API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                tempAPIKey = apiKey
            }
        }
    }
    
    private func saveAPIKey() {
        isValidating = true
        validationResult = nil
        
        // Basic validation - check format
        let trimmedKey = tempAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmedKey.hasPrefix("sk-") else {
            isValidating = false
            validationResult = .failure("Invalid key format. Should start with 'sk-'")
            return
        }
        
        guard trimmedKey.count >= 20 else {
            isValidating = false
            validationResult = .failure("API key is too short")
            return
        }
        
        // Save the key
        UserDefaults.standard.set(trimmedKey, forKey: "openai_api_key")
        apiKey = trimmedKey
        validationResult = .success
        
        // Dismiss after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isValidating = false
            dismiss()
        }
    }
    
    private func removeAPIKey() {
        UserDefaults.standard.removeObject(forKey: "openai_api_key")
        apiKey = ""
        tempAPIKey = ""
        validationResult = nil
        dismiss()
    }
}

struct StepRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Text("\(number).")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.primary)
                .frame(width: 20, alignment: .leading)
            
            Text(text)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

// MARK: - AI Vision Placeholder View
struct AIVisionPlaceholderView: View {
    let onOpenCamera: () -> Void
    @StateObject private var sessionManager = VisionSessionManager.shared
    @State private var showAllSessions = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Hero Section
                    VStack(spacing: AppSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "8B5CF6").opacity(0.2), Color(hex: "8B5CF6").opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 140, height: 140)
                            
                            Image(systemName: "eye.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "8B5CF6"), Color(hex: "A855F7")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        Text("System Vision Assistant")
                            .font(AppTypography.title2)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Point your camera at equipment, workspaces, or safety concerns and ask questions using your voice")
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.lg)
                    }
                    .padding(.vertical, AppSpacing.xl)
                    
                    // Start Button
                    Button(action: onOpenCamera) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "camera.fill")
                                .font(.title3)
                            Text("Start System Inspection")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "8B5CF6"), Color(hex: "7C3AED")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color(hex: "8B5CF6").opacity(0.4), radius: 12, y: 6)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    
                    // Previous Sessions Section
                    if !sessionManager.savedSessions.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            HStack {
                                Text("Previous Sessions")
                                    .font(AppTypography.headline)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Spacer()
                                
                                Button {
                                    showAllSessions = true
                                } label: {
                                    Text("See All")
                                        .font(AppTypography.caption)
                                        .foregroundColor(Color(hex: "8B5CF6"))
                                }
                            }
                            .padding(.horizontal, AppSpacing.lg)
                            
                            // Show last 3 sessions
                            ForEach(sessionManager.savedSessions.prefix(3)) { session in
                                VisionSessionRowView(session: session)
                                    .padding(.horizontal, AppSpacing.lg)
                            }
                        }
                        .padding(.top, AppSpacing.md)
                    }
                }
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("System Vision")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAllSessions) {
                VisionSessionsView()
            }
        }
    }
}

// MARK: - Vision Session Row View (for placeholder screen)
struct VisionSessionRowView: View {
    let session: VisionSession
    @State private var showDetail = false
    
    var body: some View {
        Button {
            showDetail = true
        } label: {
            HStack(spacing: 12) {
                // Topic icon
                Image(systemName: session.topicIcon)
                    .font(.title3)
                    .foregroundColor(topicColor)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(topicColor.opacity(0.15)))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.topic)
                        .font(AppTypography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("\(session.messageCount) messages • \(session.formattedDate)")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(12)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .sheet(isPresented: $showDetail) {
            VisionSessionDetailView(session: session)
        }
    }
    
    private var topicColor: Color {
        switch session.topic {
        case "Workplace Safety", "Fire Safety", "Electrical Safety":
            return .red
        case "Food Safety & Hygiene", "Sanitation & Cleanliness":
            return .orange
        case "Quality Control", "PPE Compliance":
            return .blue
        case "Environmental Compliance", "Agriculture & Farming":
            return .green
        case "Nursing & Healthcare", "Pharmacy & Medication":
            return .teal
        default:
            return Color(hex: "8B5CF6")
        }
    }
}

#Preview {
    RootView()
}
