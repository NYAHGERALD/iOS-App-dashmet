//
//  ComplianceService.swift
//  MeetingIntelligence
//
//  Data Compliance Service
//  Handles secure deletion of audio recordings after transcription
//  Ensures GDPR/privacy compliance by removing unnecessary audio data
//  NOTE: We only keep AI Summary audio (TTS-generated), NOT the original recording
//

import Foundation
import Combine

// MARK: - Deletion State
enum AudioDeletionState: Equatable {
    case idle
    case preparing
    case deletingLocal
    case deletingFirebase
    case deletingDatabase
    case completed
    case failed(String)
    
    var description: String {
        switch self {
        case .idle:
            return "Preparing..."
        case .preparing:
            return "Preparing for deletion..."
        case .deletingLocal:
            return "Removing local audio file..."
        case .deletingFirebase:
            return "Removing from cloud storage..."
        case .deletingDatabase:
            return "Clearing database references..."
        case .completed:
            return "Audio successfully deleted"
        case .failed(let error):
            return "Deletion failed: \(error)"
        }
    }
}

// MARK: - Compliance Service
@MainActor
class ComplianceService: ObservableObject {
    static let shared = ComplianceService()
    
    @Published var deletionState: AudioDeletionState = .idle
    @Published var isDeleting: Bool = false
    
    private let pendingDeletionsKey = "pending_audio_deletions"
    
    private init() {}
    
    // MARK: - App Launch Cleanup
    
    /// Call this on app launch to clean up any pending deletions
    /// This handles cases where user quit the app during deletion
    func performPendingDeletionsOnLaunch() {
        Task {
            await cleanupPendingDeletions()
        }
    }
    
    private func cleanupPendingDeletions() async {
        guard let pendingDeletions = UserDefaults.standard.array(forKey: pendingDeletionsKey) as? [[String: String]] else {
            return
        }
        
        print("🧹 [Compliance] Found \(pendingDeletions.count) pending audio deletions on app launch")
        
        for deletion in pendingDeletions {
            guard let meetingId = deletion["meetingId"],
                  let userId = deletion["userId"] else {
                continue
            }
            
            print("🧹 [Compliance] Cleaning up audio for meeting: \(meetingId)")
            
            // Delete local files
            deleteAllLocalRecordings(meetingId: meetingId)
            
            // Delete from Firebase
            do {
                try await FirebaseStorageService.shared.deleteAllMeetingAudio(
                    meetingId: meetingId,
                    userId: userId
                )
            } catch {
                print("⚠️ [Compliance] Firebase cleanup error: \(error.localizedDescription)")
            }
            
            // Mark as completed
            markAudioAsDeleted(meetingId: meetingId)
        }
        
        // Clear pending list
        UserDefaults.standard.removeObject(forKey: pendingDeletionsKey)
        print("✅ [Compliance] App launch cleanup completed")
    }
    
    // MARK: - Queue for Deletion (Called IMMEDIATELY when transcript is saved)
    
    /// Queue audio for deletion - this is called IMMEDIATELY when transcript is saved
    /// The deletion starts right away, even if user turns off phone
    func queueAudioForDeletion(meetingId: String, userId: String, localRecordingURL: URL?) {
        // Step 1: Add to pending deletions list (persisted in case app quits)
        addToPendingDeletions(meetingId: meetingId, userId: userId)
        
        // Step 2: Start deletion immediately in background
        Task {
            await performDeletionImmediately(
                meetingId: meetingId,
                userId: userId,
                localRecordingURL: localRecordingURL
            )
        }
        
        print("🚨 [Compliance] Audio queued for IMMEDIATE deletion: \(meetingId)")
    }
    
    private func addToPendingDeletions(meetingId: String, userId: String) {
        var pending = UserDefaults.standard.array(forKey: pendingDeletionsKey) as? [[String: String]] ?? []
        
        // Check if already pending
        if !pending.contains(where: { $0["meetingId"] == meetingId }) {
            pending.append([
                "meetingId": meetingId,
                "userId": userId,
                "queuedAt": ISO8601DateFormatter().string(from: Date())
            ])
            UserDefaults.standard.set(pending, forKey: pendingDeletionsKey)
            UserDefaults.standard.synchronize() // Force immediate save
        }
    }
    
    private func removeFromPendingDeletions(meetingId: String) {
        var pending = UserDefaults.standard.array(forKey: pendingDeletionsKey) as? [[String: String]] ?? []
        pending.removeAll { $0["meetingId"] == meetingId }
        UserDefaults.standard.set(pending, forKey: pendingDeletionsKey)
    }
    
    // MARK: - Perform Deletion Immediately
    
    private func performDeletionImmediately(
        meetingId: String,
        userId: String,
        localRecordingURL: URL?
    ) async {
        isDeleting = true
        deletionState = .preparing
        
        // Step 1: Delete local audio file IMMEDIATELY
        deletionState = .deletingLocal
        if let localURL = localRecordingURL {
            do {
                try deleteLocalAudioFile(at: localURL)
                print("✅ [Compliance] Local audio deleted immediately: \(localURL.lastPathComponent)")
            } catch {
                print("⚠️ [Compliance] Local deletion error: \(error.localizedDescription)")
            }
        }
        
        // Also delete any other local recordings for this meeting
        deleteAllLocalRecordings(meetingId: meetingId)
        
        // Step 2: Delete from Firebase Storage IMMEDIATELY
        deletionState = .deletingFirebase
        do {
            try await FirebaseStorageService.shared.deleteAllMeetingAudio(
                meetingId: meetingId,
                userId: userId
            )
            print("✅ [Compliance] Firebase audio deleted immediately")
        } catch {
            print("⚠️ [Compliance] Firebase deletion error: \(error.localizedDescription)")
        }
        
        // Step 3: Clear local references
        deletionState = .deletingDatabase
        clearLocalAudioReferences(meetingId: meetingId)
        
        // Step 4: Mark as completed and remove from pending
        markAudioAsDeleted(meetingId: meetingId)
        removeFromPendingDeletions(meetingId: meetingId)
        
        deletionState = .completed
        isDeleting = false
        
        print("✅ [Compliance] Audio deletion completed for meeting: \(meetingId)")
    }
    
    /// Legacy method - still works but now deletion happens immediately
    func deleteAudioRecordingForCompliance(
        meetingId: String,
        userId: String,
        localRecordingURL: URL?
    ) async throws {
        await performDeletionImmediately(
            meetingId: meetingId,
            userId: userId,
            localRecordingURL: localRecordingURL
        )
    }
    
    // MARK: - Private Helpers
    
    private func deleteLocalAudioFile(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    
    private func deleteAllLocalRecordings(meetingId: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("Recordings")
        
        do {
            if FileManager.default.fileExists(atPath: recordingsPath.path) {
                let files = try FileManager.default.contentsOfDirectory(at: recordingsPath, includingPropertiesForKeys: nil)
                
                for file in files {
                    let filename = file.lastPathComponent
                    // Match patterns: {meetingId}.m4a, meeting_{meetingId}_{timestamp}.m4a
                    if filename == "\(meetingId).m4a" || filename.contains(meetingId) {
                        try FileManager.default.removeItem(at: file)
                        print("✅ [Compliance] Deleted local recording: \(filename)")
                    }
                }
            }
        } catch {
            print("⚠️ [Compliance] Error scanning recordings folder: \(error.localizedDescription)")
        }
    }
    
    private func clearLocalAudioReferences(meetingId: String) {
        // Clear any cached audio URLs or references
        UserDefaults.standard.removeObject(forKey: "recording_url_\(meetingId)")
        UserDefaults.standard.removeObject(forKey: "audio_uploaded_\(meetingId)")
    }
    
    private func markAudioAsDeleted(meetingId: String) {
        // Mark audio as deleted for compliance
        UserDefaults.standard.set(true, forKey: "audio_deleted_compliance_\(meetingId)")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "audio_deleted_at_\(meetingId)")
        UserDefaults.standard.synchronize() // Force immediate save
    }
    
    /// Check if audio has been deleted for compliance
    func isAudioDeletedForCompliance(meetingId: String) -> Bool {
        return UserDefaults.standard.bool(forKey: "audio_deleted_compliance_\(meetingId)")
    }
    
    /// Check if audio deletion is pending (queued but might not be complete)
    func isAudioDeletionPending(meetingId: String) -> Bool {
        let pending = UserDefaults.standard.array(forKey: pendingDeletionsKey) as? [[String: String]] ?? []
        return pending.contains { $0["meetingId"] == meetingId }
    }
    
    /// Reset state for UI updates
    func reset() {
        deletionState = .idle
        isDeleting = false
    }
}
