//
//  RecordingViewModel.swift
//  MeetingIntelligence
//
//  Phase 3.1 - Recording View Model
//

import Foundation
import SwiftUI
import Combine

// MARK: - Recording Bookmark Model (moved outside class for accessibility)
struct RecordingBookmark: Identifiable {
    let id = UUID()
    let timestamp: Int  // Seconds from start
    var label: String?
    var note: String?
    let createdAt: Date
    
    init(timestamp: Int, note: String? = nil, label: String? = nil) {
        self.timestamp = timestamp
        self.note = note
        self.label = label
        self.createdAt = Date()
    }
    
    var formattedTimestamp: String {
        let minutes = timestamp / 60
        let seconds = timestamp % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

@MainActor
class RecordingViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private let recordingService = AudioRecordingService.shared
    private let meetingViewModel: MeetingViewModel
    
    // MARK: - Published Properties
    @Published var meeting: Meeting
    @Published var recordingState: RecordingState = .idle
    @Published var currentTime: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var peakLevel: Float = 0
    @Published var bookmarks: [RecordingBookmark] = []
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var showPermissionAlert: Bool = false
    @Published var isUploading: Bool = false
    @Published var uploadProgress: Double = 0
    
    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var formattedTime: String {
        recordingService.formattedTime(currentTime)
    }
    
    var canStartRecording: Bool {
        recordingState.canRecord
    }
    
    var isRecording: Bool {
        recordingState == .recording
    }
    
    var isPaused: Bool {
        recordingState == .paused
    }
    
    var isActive: Bool {
        recordingState.isActive
    }
    
    var recordingDuration: Int {
        Int(currentTime)
    }
    
    // MARK: - Initialization
    init(meeting: Meeting, meetingViewModel: MeetingViewModel) {
        self.meeting = meeting
        self.meetingViewModel = meetingViewModel
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind recording service state to view model
        recordingService.$state
            .receive(on: DispatchQueue.main)
            .assign(to: &$recordingState)
        
        recordingService.$currentTime
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentTime)
        
        recordingService.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)
        
        recordingService.$peakLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$peakLevel)
    }
    
    // MARK: - Recording Controls
    
    /// Start recording
    func startRecording() async {
        // Check permission first
        let hasPermission = await recordingService.checkMicrophonePermission()
        
        if !hasPermission {
            showPermissionAlert = true
            return
        }
        
        do {
            // Update meeting status to RECORDING
            let _ = await meetingViewModel.updateMeeting(
                meetingId: meeting.id,
                status: .recording
            )
            
            // Start recording
            let _ = try await recordingService.startRecording(meetingId: meeting.id)
            
            print("✅ Recording started for meeting: \(meeting.displayTitle)")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    /// Pause recording
    func pauseRecording() {
        recordingService.pauseRecording()
    }
    
    /// Resume recording
    func resumeRecording() {
        recordingService.resumeRecording()
    }
    
    /// Stop recording
    func stopRecording() -> URL? {
        let url = recordingService.stopRecording()
        return url
    }
    
    /// Cancel recording
    func cancelRecording() {
        recordingService.cancelRecording()
        bookmarks.removeAll()
        
        // Revert meeting status to DRAFT
        Task {
            let _ = await meetingViewModel.updateMeeting(
                meetingId: meeting.id,
                status: .draft
            )
        }
    }
    
    // MARK: - Bookmark Management
    
    /// Add a bookmark at the current timestamp
    func addBookmark(label: String? = nil, note: String? = nil) {
        let bookmark = RecordingBookmark(
            timestamp: Int(currentTime),
            note: note,
            label: label
        )
        bookmarks.append(bookmark)
        
        // Also save to backend
        Task {
            let _ = await meetingViewModel.addBookmark(
                meetingId: meeting.id,
                timestamp: bookmark.timestamp,
                label: label,
                note: note
            )
        }
        
        print("🔖 Bookmark added at \(bookmark.formattedTimestamp)")
    }
    
    /// Remove a bookmark
    func removeBookmark(_ bookmark: RecordingBookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
    }
    
    /// Update a bookmark's label
    func updateBookmarkLabel(_ bookmark: RecordingBookmark, label: String) {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            bookmarks[index].label = label
        }
    }
    
    // MARK: - Recording Completion
    
    /// Complete recording and prepare for upload
    func completeRecording() async -> URL? {
        guard let recordingURL = stopRecording() else {
            errorMessage = "No recording found"
            showError = true
            return nil
        }
        
        // Update meeting status to UPLOADING
        let _ = await meetingViewModel.updateMeeting(
            meetingId: meeting.id,
            status: .uploading
        )
        
        return recordingURL
    }
    
    /// Get file info for the recording
    func getRecordingInfo() -> (size: String?, duration: Int) {
        let size = recordingService.getFormattedFileSize()
        let duration = recordingDuration
        return (size, duration)
    }
    
    // MARK: - Permission Handling
    
    func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        cancellables.removeAll()
    }
}
