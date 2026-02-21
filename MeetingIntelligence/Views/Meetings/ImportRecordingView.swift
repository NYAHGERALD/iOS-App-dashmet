//
//  ImportRecordingView.swift
//  MeetingIntelligence
//
//  Import existing audio recordings as meetings
//

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

// MARK: - Import Recording View
struct ImportRecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @ObservedObject var meetingViewModel: MeetingViewModel
    
    // MARK: - State
    @State private var selectedFileURL: URL?
    @State private var selectedFileName: String = ""
    @State private var selectedFileSize: String = ""
    @State private var audioDuration: TimeInterval = 0
    @State private var meetingTitle: String = ""
    @State private var selectedType: MeetingType = .general
    @State private var showFilePicker = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var uploadProgress: Double = 0
    @State private var currentStep: ImportStep = .selectFile
    
    // MARK: - Import Step
    enum ImportStep {
        case selectFile
        case configure
        case uploading
        case completed
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                    .padding(.top, AppSpacing.md)
                
                // Content based on step
                switch currentStep {
                case .selectFile:
                    selectFileView
                case .configure:
                    configureView
                case .uploading:
                    uploadingView
                case .completed:
                    completedView
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Import Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(currentStep == .uploading)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: supportedAudioTypes,
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Supported Audio Types
    private var supportedAudioTypes: [UTType] {
        [
            .audio,
            .mp3,
            .wav,
            .aiff,
            UTType(filenameExtension: "m4a") ?? .audio,
            UTType(filenameExtension: "aac") ?? .audio,
            UTType(filenameExtension: "caf") ?? .audio,
            UTType(filenameExtension: "opus") ?? .audio
        ]
    }
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(stepColor(for: index))
                    .frame(width: 10, height: 10)
                
                if index < 3 {
                    Rectangle()
                        .fill(lineColor(for: index))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, AppSpacing.xl)
    }
    
    private func stepColor(for index: Int) -> Color {
        let currentIndex = stepIndex
        if index < currentIndex {
            return AppColors.success
        } else if index == currentIndex {
            return AppColors.primary
        } else {
            return AppColors.textTertiary.opacity(0.3)
        }
    }
    
    private func lineColor(for index: Int) -> Color {
        let currentIndex = stepIndex
        if index < currentIndex {
            return AppColors.success
        } else {
            return AppColors.textTertiary.opacity(0.3)
        }
    }
    
    private var stepIndex: Int {
        switch currentStep {
        case .selectFile: return 0
        case .configure: return 1
        case .uploading: return 2
        case .completed: return 3
        }
    }
    
    // MARK: - Select File View
    private var selectFileView: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.1))
                    .frame(width: 140, height: 140)
                
                Circle()
                    .fill(AppColors.primary.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 44))
                    .foregroundStyle(AppGradients.primary)
            }
            
            VStack(spacing: AppSpacing.sm) {
                Text("Select Audio File")
                    .font(AppTypography.title)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Import an existing audio recording\nto create a new meeting")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Supported formats
            VStack(spacing: AppSpacing.xs) {
                Text("Supported formats")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                
                Text("MP3, M4A, WAV, AAC, AIFF, CAF, Opus")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.top, AppSpacing.md)
            
            Spacer()
            
            // Select button
            Button {
                showFilePicker = true
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "folder.badge.plus")
                    Text("Browse Files")
                }
                .primaryButtonStyle()
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
    }
    
    // MARK: - Configure View
    private var configureView: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Selected file card
                selectedFileCard
                    .padding(.top, AppSpacing.lg)
                
                // Meeting title
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Meeting Title (Optional)")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                    
                    TextField("Enter title or leave blank for auto-generated", text: $meetingTitle)
                        .font(AppTypography.body)
                        .padding(AppSpacing.md)
                        .background(AppColors.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                }
                .padding(.horizontal, AppSpacing.lg)
                
                // Meeting type selection
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Meeting Type")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, AppSpacing.lg)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.sm) {
                            ForEach(MeetingType.allCases, id: \.self) { type in
                                MeetingTypeChip(
                                    type: type,
                                    isSelected: selectedType == type
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedType = type
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                    }
                }
                
                Spacer()
                    .frame(height: AppSpacing.xl)
                
                // Import button
                Button {
                    Task {
                        await importRecording()
                    }
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "arrow.up.doc.fill")
                        Text("Import Recording")
                    }
                    .primaryButtonStyle()
                }
                .padding(.horizontal, AppSpacing.lg)
                
                // Change file button
                Button {
                    withAnimation {
                        currentStep = .selectFile
                        selectedFileURL = nil
                    }
                } label: {
                    Text("Choose Different File")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.primary)
                }
                .padding(.bottom, AppSpacing.xl)
            }
        }
    }
    
    // MARK: - Selected File Card
    private var selectedFileCard: some View {
        HStack(spacing: AppSpacing.md) {
            // Audio icon
            ZStack {
                RoundedRectangle(cornerRadius: AppCornerRadius.small)
                    .fill(Color(hex: selectedType.color).opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "waveform")
                    .font(.title2)
                    .foregroundColor(Color(hex: selectedType.color))
            }
            
            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedFileName)
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: AppSpacing.sm) {
                    Label(selectedFileSize, systemImage: "doc")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                    
                    if audioDuration > 0 {
                        Label(formatDuration(audioDuration), systemImage: "clock")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            
            Spacer()
            
            // Checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(AppColors.success)
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
        .padding(.horizontal, AppSpacing.lg)
    }
    
    // MARK: - Uploading View
    private var uploadingView: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            
            // Progress circle
            ZStack {
                Circle()
                    .stroke(AppColors.surfaceSecondary, lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: uploadProgress)
                    .stroke(
                        AppGradients.primary,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: uploadProgress)
                
                VStack(spacing: 2) {
                    Text("\(Int(uploadProgress * 100))%")
                        .font(AppTypography.title)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Uploading")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            VStack(spacing: AppSpacing.sm) {
                Text("Importing Recording")
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(selectedFileName)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Note
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "info.circle")
                Text("Please don't close the app while uploading")
            }
            .font(AppTypography.caption)
            .foregroundColor(AppColors.textTertiary)
            .padding(.bottom, AppSpacing.xl)
        }
    }
    
    // MARK: - Completed View
    private var completedView: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            
            // Success icon
            ZStack {
                Circle()
                    .fill(AppColors.success.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppColors.success)
            }
            
            VStack(spacing: AppSpacing.sm) {
                Text("Import Complete!")
                    .font(AppTypography.title)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Your recording has been imported\nand is now being processed")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Done button
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .primaryButtonStyle()
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
    }
    
    // MARK: - File Selection Handler
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Access security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Unable to access the selected file"
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            // Copy file to temp directory for upload
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(url.pathExtension)
            
            do {
                try FileManager.default.copyItem(at: url, to: tempURL)
                selectedFileURL = tempURL
                selectedFileName = url.lastPathComponent
                
                // Get file size
                let attributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
                if let fileSize = attributes[.size] as? Int64 {
                    selectedFileSize = formatFileSize(fileSize)
                }
                
                // Get audio duration
                getAudioDuration(from: tempURL)
                
                // Move to configure step
                withAnimation {
                    currentStep = .configure
                }
            } catch {
                errorMessage = "Failed to load file: \(error.localizedDescription)"
            }
            
        case .failure(let error):
            errorMessage = "File selection failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Audio Duration
    private func getAudioDuration(from url: URL) {
        let asset = AVAsset(url: url)
        Task {
            do {
                let duration = try await asset.load(.duration)
                await MainActor.run {
                    audioDuration = duration.seconds
                }
            } catch {
                print("Could not get audio duration: \(error)")
            }
        }
    }
    
    // MARK: - Import Recording
    private func importRecording() async {
        guard let fileURL = selectedFileURL else {
            errorMessage = "No file selected"
            return
        }
        
        guard let userId = meetingViewModel.userId,
              let organizationId = meetingViewModel.organizationId else {
            errorMessage = "User not configured"
            return
        }
        
        isProcessing = true
        
        withAnimation {
            currentStep = .uploading
        }
        
        // Step 1: Create the meeting
        let title = meetingTitle.isEmpty ? nil : meetingTitle
        guard let meeting = await meetingViewModel.createMeeting(
            title: title,
            meetingType: selectedType,
            location: nil,
            tags: []
        ) else {
            errorMessage = meetingViewModel.errorMessage ?? "Failed to create meeting"
            withAnimation {
                currentStep = .configure
            }
            isProcessing = false
            return
        }
        
        // Step 2: Upload the audio file
        do {
            // Simulate progress updates
            for i in 1...5 {
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                uploadProgress = Double(i) * 0.15
            }
            
            let downloadURL = try await FirebaseStorageService.shared.uploadNow(
                meetingId: meeting.id,
                localURL: fileURL,
                userId: userId
            )
            
            uploadProgress = 0.9
            
            // Step 3: Update meeting with recording URL
            let success = await meetingViewModel.uploadMeeting(
                meetingId: meeting.id,
                recordingUrl: downloadURL,
                duration: Int(audioDuration),
                recordedAt: Date(),
                language: "en",
                speakerCountHint: nil
            )
            
            if success {
                uploadProgress = 1.0
                
                // Clean up temp file
                try? FileManager.default.removeItem(at: fileURL)
                
                withAnimation {
                    currentStep = .completed
                }
            } else {
                errorMessage = "Failed to update meeting with recording"
                withAnimation {
                    currentStep = .configure
                }
            }
        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
            
            // Delete the meeting since upload failed
            _ = await meetingViewModel.deleteMeeting(meetingId: meeting.id)
            
            withAnimation {
                currentStep = .configure
            }
        }
        
        isProcessing = false
    }
    
    // MARK: - Helpers
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        }
        
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Meeting Type Chip
struct MeetingTypeChip: View {
    let type: MeetingType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: type.icon)
                    .font(.caption)
                Text(type.displayName)
                    .font(AppTypography.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : Color(hex: type.color))
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? Color(hex: type.color) : Color(hex: type.color).opacity(0.15))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    ImportRecordingView(meetingViewModel: MeetingViewModel())
        .environmentObject(AppState())
}
