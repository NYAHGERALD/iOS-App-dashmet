//
//  UploadManagerView.swift
//  MeetingIntelligence
//
//  Phase 1 - Upload Queue Manager UI
//

import SwiftUI

// MARK: - Upload Manager View
struct UploadManagerView: View {
    @StateObject private var storageService = FirebaseStorageService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                if storageService.uploadQueue.isEmpty && storageService.completedUploads.isEmpty {
                    emptyState
                } else {
                    uploadList
                }
            }
            .navigationTitle("Uploads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                if !storageService.completedUploads.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") {
                            storageService.clearCompleted()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 60))
                .foregroundStyle(AppGradients.primary)
            
            Text("No Uploads")
                .font(AppTypography.title3)
                .foregroundColor(AppColors.textPrimary)
            
            Text("Your upload queue is empty.\nRecordings will appear here when uploading.")
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.xl)
    }
    
    // MARK: - Upload List
    private var uploadList: some View {
        List {
            // Current/Active Uploads
            if !storageService.uploadQueue.isEmpty {
                Section {
                    ForEach(storageService.uploadQueue) { task in
                        UploadTaskRow(task: task, isCurrent: storageService.currentUpload?.id == task.id)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let task = storageService.uploadQueue[index]
                            storageService.removeFromQueue(task.id)
                        }
                    }
                } header: {
                    Text("Queue (\(storageService.uploadQueue.count))")
                }
            }
            
            // Completed Uploads
            if !storageService.completedUploads.isEmpty {
                Section {
                    ForEach(storageService.completedUploads) { task in
                        CompletedUploadRow(task: task)
                    }
                } header: {
                    Text("Completed")
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Upload Task Row
struct UploadTaskRow: View {
    let task: UploadTaskInfo
    let isCurrent: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                // Status icon
                statusIcon
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Meeting Recording")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(task.id.prefix(8) + "...")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                // Action button
                actionButton
            }
            
            // Progress bar for uploading
            if case .uploading(let progress) = task.state {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress)
                        .tint(AppColors.primary)
                    
                    Text("\(Int(progress * 100))% complete")
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            // Error message for failed
            if case .failed(let error) = task.state {
                Text(error)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.error)
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch task.state {
        case .idle:
            Image(systemName: "clock")
                .foregroundColor(AppColors.textTertiary)
        case .preparing:
            ProgressView()
                .scaleEffect(0.8)
        case .uploading:
            Image(systemName: "icloud.and.arrow.up.fill")
                .foregroundColor(AppColors.primary)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppColors.success)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(AppColors.error)
        case .cancelled:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(AppColors.warning)
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        switch task.state {
        case .uploading:
            Button {
                FirebaseStorageService.shared.cancelCurrentUpload()
            } label: {
                Image(systemName: "xmark.circle")
                    .foregroundColor(AppColors.error)
            }
        case .failed, .cancelled:
            if task.isRetryable {
                Button {
                    FirebaseStorageService.shared.retryUpload(task.id)
                } label: {
                    Text("Retry")
                        .font(AppTypography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.primary)
                }
            }
        default:
            EmptyView()
        }
    }
}

// MARK: - Completed Upload Row
struct CompletedUploadRow: View {
    let task: UploadTaskInfo
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppColors.success)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Meeting Recording")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                
                if let completedAt = task.completedAt {
                    Text("Completed \(completedAt.formatted(.relative(presentation: .named)))")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "checkmark")
                .foregroundColor(AppColors.success)
        }
    }
}

// MARK: - Upload Status Badge (for use in other views)
struct UploadStatusBadge: View {
    @ObservedObject var storageService = FirebaseStorageService.shared
    let meetingId: String
    
    var body: some View {
        if storageService.isUploadingMeeting(meetingId) {
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.6)
                
                if let progress = storageService.getUploadProgress(for: meetingId) {
                    Text("\(Int(progress * 100))%")
                        .font(AppTypography.caption2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppColors.primary.opacity(0.15))
            .foregroundColor(AppColors.primary)
            .clipShape(Capsule())
        } else if storageService.hasPendingUpload(meetingId) {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text("Queued")
                    .font(AppTypography.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppColors.warning.opacity(0.15))
            .foregroundColor(AppColors.warning)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Upload Queue Indicator (Mini badge for tab bar)
struct UploadQueueIndicator: View {
    @ObservedObject var storageService = FirebaseStorageService.shared
    
    var body: some View {
        if !storageService.uploadQueue.isEmpty || storageService.isUploading {
            HStack(spacing: 4) {
                if storageService.isUploading {
                    ProgressView()
                        .scaleEffect(0.5)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.caption2)
                }
                
                Text("\(storageService.uploadQueue.count)")
                    .font(.caption2)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(AppColors.primary)
            .foregroundColor(.white)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Preview
#Preview {
    UploadManagerView()
}
