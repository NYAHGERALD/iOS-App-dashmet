//
//  ActivityLogView.swift
//  MeetingIntelligence
//
//  Activity Log View - Displays the history of changes for an action item
//

import SwiftUI

struct ActivityLogView: View {
    @Environment(\.dismiss) private var dismiss
    
    let taskId: String
    
    @State private var logs: [TaskActivityLog] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private let apiService = APIService.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if logs.isEmpty {
                    emptyView
                } else {
                    logListView
                }
            }
            .navigationTitle("Activity Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await fetchLogs() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
        }
        .task {
            await fetchLogs()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading activity log...")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppColors.error)
            
            Text("Unable to load activity log")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                Task { await fetchLogs() }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppColors.primary)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textTertiary)
            
            Text("No Activity Yet")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            
            Text("Activity will appear here when changes are made to this action item.")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Log List View
    private var logListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                    ActivityLogRow(log: log, isFirst: index == 0, isLast: index == logs.count - 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }
    
    // MARK: - Fetch Logs
    private func fetchLogs() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.getTaskActivityLogs(taskId: taskId)
            if response.success {
                logs = response.logs ?? []
            } else {
                errorMessage = response.error ?? "Failed to fetch activity logs"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - Activity Log Row
struct ActivityLogRow: View {
    let log: TaskActivityLog
    let isFirst: Bool
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline indicator
            VStack(spacing: 0) {
                // Top line (hidden for first item)
                Rectangle()
                    .fill(isFirst ? Color.clear : AppColors.border)
                    .frame(width: 2, height: 16)
                
                // Icon circle
                ZStack {
                    Circle()
                        .fill(Color(hex: log.action.color).opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: log.action.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: log.action.color))
                }
                
                // Bottom line (hidden for last item)
                Rectangle()
                    .fill(isLast ? Color.clear : AppColors.border)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 36)
            
            // Content card
            VStack(alignment: .leading, spacing: 8) {
                // Action title and time
                HStack(alignment: .top) {
                    Text(log.action.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    Text(log.timeAgo)
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                
                // Change description
                Text(log.changeDescription)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Show old/new values for title and description updates
                if log.action == .updateTitle || log.action == .updateDescription {
                    changeValuesView
                }
                
                // User info and full date
                HStack(spacing: 8) {
                    if let user = log.user {
                        userBadge(user)
                    }
                    
                    Spacer()
                    
                    Text(log.formattedDate)
                        .font(.caption2)
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(.top, 4)
            }
            .padding(14)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.vertical, 8)
    }
    
    private func userBadge(_ user: TaskUser) -> some View {
        HStack(spacing: 6) {
            // Profile picture or initials
            if let profileUrl = user.profilePicture, let url = URL(string: profileUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    initialsView(user)
                }
                .frame(width: 20, height: 20)
                .clipShape(Circle())
            } else {
                initialsView(user)
            }
            
            Text(user.fullName)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
        }
    }
    
    // View showing old and new values with strikethrough
    @ViewBuilder
    private var changeValuesView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Previous value (crossed out)
            if let prev = log.previousValue, !prev.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "minus.circle.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.error.opacity(0.7))
                    Text(prev)
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .strikethrough(true, color: AppColors.error.opacity(0.6))
                        .lineLimit(3)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.error.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // New value
            if let newVal = log.newValue, !newVal.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.success.opacity(0.7))
                    Text(newVal)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(3)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.success.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.top, 4)
    }
    
    private func initialsView(_ user: TaskUser) -> some View {
        ZStack {
            Circle()
                .fill(AppColors.primary.opacity(0.15))
                .frame(width: 20, height: 20)
            
            Text(user.initials)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(AppColors.primary)
        }
    }
}

// MARK: - Preview
#Preview {
    ActivityLogView(taskId: "preview-task-id")
}
