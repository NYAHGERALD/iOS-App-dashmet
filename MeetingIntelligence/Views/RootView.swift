//
//  RootView.swift
//  MeetingIntelligence
//
//  Phase 0 - Root View with initialization
//

import SwiftUI

struct RootView: View {
    @StateObject private var appState = AppState()
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        Group {
            if appState.isLoading {
                LoadingView()
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
                MainView(onLogout: {
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

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Error View
struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry") {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Main View (Authenticated Home)
struct MainView: View {
    @EnvironmentObject var appState: AppState
    var onLogout: () -> Void
    
    var body: some View {
        TabView {
            // Tasks Tab
            TaskListView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
            
            // Meetings Tab (Placeholder for Phase 3)
            MeetingsPlaceholderView()
                .tabItem {
                    Label("Meetings", systemImage: "person.3.fill")
                }
            
            // Profile Tab
            ProfileView(onLogout: onLogout)
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
    }
}

// MARK: - Meetings Placeholder (Phase 3)
struct MeetingsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue.opacity(0.6))
                
                VStack(spacing: 8) {
                    Text("Meetings")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Coming in Phase 3")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Meetings")
        }
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    var onLogout: () -> Void
    
    var body: some View {
        NavigationStack {
            List {
                // User Info Section
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("User ID")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(appState.currentUserID ?? "Unknown")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Progress Section
                Section("Development Progress") {
                    ProgressRow(text: "Phase 0: Foundation", isComplete: true)
                    ProgressRow(text: "Phase 1: Authentication", isComplete: true)
                    ProgressRow(text: "Phase 2.1: Task API", isComplete: true)
                    ProgressRow(text: "Phase 2.2: Task List UI", isComplete: true)
                    ProgressRow(text: "Phase 2.3: Assign + Status", isComplete: false)
                    ProgressRow(text: "Phase 2.4: Push Notifications", isComplete: false)
                    ProgressRow(text: "Phase 3: Meetings", isComplete: false)
                }
                
                // Logout Section
                Section {
                    Button(role: .destructive) {
                        onLogout()
                        appState.logout()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Logout")
                        }
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}

struct ProgressRow: View {
    let text: String
    let isComplete: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isComplete ? .green : .gray)
            Text(text)
                .foregroundColor(isComplete ? .primary : .secondary)
        }
    }
}

#Preview {
    RootView()
}
