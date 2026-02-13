//
//  FirebaseStorageService.swift
//  MeetingIntelligence
//
//  Phase 1 - Firebase Storage Upload Service
//

import Foundation
import FirebaseStorage
import Combine
import UIKit

// MARK: - Upload State
enum UploadState: Equatable {
    case idle
    case preparing
    case uploading(progress: Double)
    case completed(url: String)
    case failed(String)
    case cancelled
    
    var isActive: Bool {
        switch self {
        case .preparing, .uploading:
            return true
        default:
            return false
        }
    }
    
    var progress: Double {
        switch self {
        case .uploading(let progress):
            return progress
        case .completed:
            return 1.0
        default:
            return 0.0
        }
    }
}

// MARK: - Upload Error
enum UploadError: LocalizedError {
    case fileNotFound
    case invalidFile
    case uploadFailed(String)
    case cancelled
    case networkError(String)
    case authenticationRequired
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Recording file not found"
        case .invalidFile:
            return "Invalid audio file"
        case .uploadFailed(let reason):
            return "Upload failed: \(reason)"
        case .cancelled:
            return "Upload was cancelled"
        case .networkError(let reason):
            return "Network error: \(reason)"
        case .authenticationRequired:
            return "Please sign in to upload"
        }
    }
}

// MARK: - Upload Task Info
struct UploadTaskInfo: Identifiable {
    let id: String  // Meeting ID
    let localURL: URL
    let storagePath: String
    var state: UploadState = .idle
    var retryCount: Int = 0
    let createdAt: Date = Date()
    var completedAt: Date?
    var downloadURL: String?
    
    var isRetryable: Bool {
        switch state {
        case .failed, .cancelled:
            return retryCount < 3
        default:
            return false
        }
    }
}

// MARK: - Firebase Storage Service
@MainActor
class FirebaseStorageService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = FirebaseStorageService()
    
    // MARK: - Published Properties
    @Published private(set) var currentUpload: UploadTaskInfo?
    @Published private(set) var uploadQueue: [UploadTaskInfo] = []
    @Published private(set) var completedUploads: [UploadTaskInfo] = []
    @Published private(set) var isUploading: Bool = false
    
    // MARK: - Private Properties
    private let storage = Storage.storage()
    private var currentTask: StorageUploadTask?
    private var progressObserver: NSKeyValueObservation?
    
    // Storage paths
    private let audioStoragePath = "meetings/audio"
    private let aiSummaryAudioPath = "meetings/ai-summary-audio"
    
    // MARK: - Initialization
    private init() {
        // Load any pending uploads from disk
        loadPendingUploads()
    }
    
    // MARK: - Public Methods
    
    /// Queue an upload for a meeting recording
    func queueUpload(meetingId: String, localURL: URL, userId: String) {
        let storagePath = "\(audioStoragePath)/\(userId)/\(meetingId)/recording.m4a"
        
        var task = UploadTaskInfo(
            id: meetingId,
            localURL: localURL,
            storagePath: storagePath
        )
        task.state = .idle
        
        // Add to queue
        uploadQueue.append(task)
        savePendingUploads()
        
        print("📤 Upload queued for meeting: \(meetingId)")
        
        // Start processing queue if not already
        processQueue()
    }
    
    /// Upload a file immediately (bypasses queue)
    func uploadNow(meetingId: String, localURL: URL, userId: String) async throws -> String {
        let storagePath = "\(audioStoragePath)/\(userId)/\(meetingId)/recording.m4a"
        
        var task = UploadTaskInfo(
            id: meetingId,
            localURL: localURL,
            storagePath: storagePath
        )
        
        currentUpload = task
        isUploading = true
        
        defer {
            isUploading = false
        }
        
        return try await performUpload(&task)
    }
    
    /// Cancel the current upload
    func cancelCurrentUpload() {
        currentTask?.cancel()
        currentTask = nil
        
        if var upload = currentUpload {
            upload.state = .cancelled
            currentUpload = upload
        }
        
        isUploading = false
        processQueue()
    }
    
    /// Retry a failed upload
    func retryUpload(_ taskId: String) {
        guard let index = uploadQueue.firstIndex(where: { $0.id == taskId }) else { return }
        
        var task = uploadQueue[index]
        guard task.isRetryable else { return }
        
        task.state = .idle
        task.retryCount += 1
        uploadQueue[index] = task
        
        processQueue()
    }
    
    /// Remove a task from the queue
    func removeFromQueue(_ taskId: String) {
        uploadQueue.removeAll { $0.id == taskId }
        savePendingUploads()
    }
    
    /// Clear completed uploads
    func clearCompleted() {
        completedUploads.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func processQueue() {
        guard !isUploading else { return }
        guard let nextTask = uploadQueue.first(where: { 
            $0.state == .idle || ($0.state != .completed(url: "") && $0.isRetryable)
        }) else { return }
        
        Task {
            await processUploadTask(nextTask.id)
        }
    }
    
    private func processUploadTask(_ taskId: String) async {
        guard let index = uploadQueue.firstIndex(where: { $0.id == taskId }) else { return }
        
        var task = uploadQueue[index]
        currentUpload = task
        isUploading = true
        
        do {
            let downloadURL = try await performUpload(&task)
            
            // Update task as completed
            task.state = .completed(url: downloadURL)
            task.completedAt = Date()
            task.downloadURL = downloadURL
            currentUpload = task
            
            // Move to completed
            uploadQueue.removeAll { $0.id == taskId }
            completedUploads.append(task)
            savePendingUploads()
            
            print("✅ Upload completed for meeting: \(taskId)")
            
        } catch {
            // Update task as failed
            task.state = .failed(error.localizedDescription)
            currentUpload = task
            
            if let uploadIndex = uploadQueue.firstIndex(where: { $0.id == taskId }) {
                uploadQueue[uploadIndex] = task
            }
            savePendingUploads()
            
            print("❌ Upload failed for meeting: \(taskId) - \(error.localizedDescription)")
        }
        
        isUploading = false
        
        // Process next in queue
        processQueue()
    }
    
    private func performUpload(_ task: inout UploadTaskInfo) async throws -> String {
        // Verify file exists
        guard FileManager.default.fileExists(atPath: task.localURL.path) else {
            throw UploadError.fileNotFound
        }
        
        // Update state
        task.state = .preparing
        currentUpload = task
        
        // Get file data
        let fileData: Data
        do {
            fileData = try Data(contentsOf: task.localURL)
        } catch {
            throw UploadError.invalidFile
        }
        
        // Create storage reference
        let storageRef = storage.reference().child(task.storagePath)
        
        // Metadata
        let metadata = StorageMetadata()
        metadata.contentType = "audio/m4a"
        metadata.customMetadata = [
            "meetingId": task.id,
            "uploadedAt": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Upload with progress tracking
        return try await withCheckedThrowingContinuation { continuation in
            let uploadTask = storageRef.putData(fileData, metadata: metadata)
            self.currentTask = uploadTask
            
            // Observe progress
            uploadTask.observe(.progress) { [weak self] snapshot in
                guard let progress = snapshot.progress else { return }
                let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                
                Task { @MainActor in
                    if var currentUpload = self?.currentUpload {
                        currentUpload.state = .uploading(progress: percentComplete)
                        self?.currentUpload = currentUpload
                    }
                }
            }
            
            // Handle completion
            uploadTask.observe(.success) { _ in
                // Get download URL
                storageRef.downloadURL { url, error in
                    if let error = error {
                        continuation.resume(throwing: UploadError.uploadFailed(error.localizedDescription))
                    } else if let url = url {
                        continuation.resume(returning: url.absoluteString)
                    } else {
                        continuation.resume(throwing: UploadError.uploadFailed("Could not get download URL"))
                    }
                }
            }
            
            // Handle failure
            uploadTask.observe(.failure) { snapshot in
                if let error = snapshot.error as NSError? {
                    if error.code == StorageErrorCode.cancelled.rawValue {
                        continuation.resume(throwing: UploadError.cancelled)
                    } else {
                        continuation.resume(throwing: UploadError.uploadFailed(error.localizedDescription))
                    }
                } else {
                    continuation.resume(throwing: UploadError.uploadFailed("Unknown error"))
                }
            }
        }
    }
    
    // MARK: - Persistence
    
    private func savePendingUploads() {
        // Save pending upload IDs and paths to UserDefaults for recovery
        let pendingData = uploadQueue.map { task -> [String: String] in
            return [
                "id": task.id,
                "localPath": task.localURL.path,
                "storagePath": task.storagePath,
                "retryCount": String(task.retryCount)
            ]
        }
        
        UserDefaults.standard.set(pendingData, forKey: "pendingUploads")
    }
    
    private func loadPendingUploads() {
        guard let pendingData = UserDefaults.standard.array(forKey: "pendingUploads") as? [[String: String]] else {
            return
        }
        
        uploadQueue = pendingData.compactMap { data -> UploadTaskInfo? in
            guard let id = data["id"],
                  let localPath = data["localPath"],
                  let storagePath = data["storagePath"],
                  let retryCountStr = data["retryCount"],
                  let retryCount = Int(retryCountStr),
                  FileManager.default.fileExists(atPath: localPath) else {
                return nil
            }
            
            var task = UploadTaskInfo(
                id: id,
                localURL: URL(fileURLWithPath: localPath),
                storagePath: storagePath
            )
            task.retryCount = retryCount
            return task
        }
        
        // Auto-resume uploads
        if !uploadQueue.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.processQueue()
            }
        }
    }
    
    // MARK: - Utilities
    
    /// Get upload progress for a specific meeting
    func getUploadProgress(for meetingId: String) -> Double? {
        if currentUpload?.id == meetingId {
            return currentUpload?.state.progress
        }
        return nil
    }
    
    /// Check if a meeting is currently uploading
    func isUploadingMeeting(_ meetingId: String) -> Bool {
        currentUpload?.id == meetingId && isUploading
    }
    
    /// Check if a meeting has a pending upload
    func hasPendingUpload(_ meetingId: String) -> Bool {
        uploadQueue.contains { $0.id == meetingId }
    }
    
    // MARK: - AI Summary Audio Upload
    
    /// Upload AI summary audio (TTS-generated) to Firebase Storage
    /// Returns the download URL for the uploaded audio
    func uploadAISummaryAudio(meetingId: String, audioData: Data, userId: String, voice: String) async throws -> String {
        let fileName = "ai-summary-\(voice).mp3"
        let storagePath = "\(aiSummaryAudioPath)/\(userId)/\(meetingId)/\(fileName)"
        
        print("📤 Uploading AI summary audio for meeting: \(meetingId)")
        print("   Path: \(storagePath)")
        print("   Size: \(audioData.count) bytes")
        
        // Create storage reference
        let storageRef = storage.reference().child(storagePath)
        
        // Metadata
        let metadata = StorageMetadata()
        metadata.contentType = "audio/mpeg"
        metadata.customMetadata = [
            "meetingId": meetingId,
            "voice": voice,
            "type": "ai-summary",
            "uploadedAt": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Upload and get download URL
        return try await withCheckedThrowingContinuation { continuation in
            storageRef.putData(audioData, metadata: metadata) { metadata, error in
                if let error = error {
                    print("❌ AI audio upload failed: \(error.localizedDescription)")
                    continuation.resume(throwing: UploadError.uploadFailed(error.localizedDescription))
                    return
                }
                
                // Get download URL
                storageRef.downloadURL { url, error in
                    if let error = error {
                        print("❌ Failed to get download URL: \(error.localizedDescription)")
                        continuation.resume(throwing: UploadError.uploadFailed(error.localizedDescription))
                    } else if let url = url {
                        print("✅ AI audio uploaded successfully: \(url.absoluteString)")
                        continuation.resume(returning: url.absoluteString)
                    } else {
                        continuation.resume(throwing: UploadError.uploadFailed("Could not get download URL"))
                    }
                }
            }
        }
    }
    
    // MARK: - Audio Deletion (Compliance)
    
    /// Delete meeting recording audio from Firebase Storage
    /// Used for compliance after transcript is saved
    func deleteMeetingRecording(meetingId: String, userId: String) async throws {
        let storagePath = "\(audioStoragePath)/\(userId)/\(meetingId)/recording.m4a"
        
        print("🗑️ Deleting meeting recording from Firebase Storage...")
        print("   Path: \(storagePath)")
        
        let storageRef = storage.reference().child(storagePath)
        
        do {
            try await storageRef.delete()
            print("✅ Meeting recording deleted from Firebase Storage")
        } catch {
            // File might not exist in Firebase, which is fine
            print("⚠️ Could not delete from Firebase (may not exist): \(error.localizedDescription)")
        }
    }
    
    /// Delete AI summary audio from Firebase Storage
    func deleteAISummaryAudio(meetingId: String, userId: String) async throws {
        let basePath = "\(aiSummaryAudioPath)/\(userId)/\(meetingId)"
        
        print("🗑️ Deleting AI summary audio from Firebase Storage...")
        print("   Path: \(basePath)")
        
        let storageRef = storage.reference().child(basePath)
        
        // List all files in the folder and delete them
        do {
            let result = try await storageRef.listAll()
            for item in result.items {
                try await item.delete()
                print("✅ Deleted: \(item.name)")
            }
        } catch {
            print("⚠️ Could not delete AI audio (may not exist): \(error.localizedDescription)")
        }
    }
    
    /// Delete all audio files for a meeting (recording + AI summary)
    func deleteAllMeetingAudio(meetingId: String, userId: String) async throws {
        print("🗑️ [Compliance] Deleting all audio for meeting: \(meetingId)")
        
        // Delete meeting recording
        try await deleteMeetingRecording(meetingId: meetingId, userId: userId)
        
        // Note: We don't delete AI summary audio here because that's different
        // AI summary audio is the TTS-generated narration, not the original recording
        
        print("✅ [Compliance] All meeting audio deleted from Firebase Storage")
    }
    
    // MARK: - Document Image Uploads
    
    /// Upload a document image to Firebase Storage for conflict resolution
    /// Returns the download URL for the uploaded image
    func uploadDocumentImage(_ image: UIImage, caseNumber: String, documentId: String, pageIndex: Int, userId: String, isProcessed: Bool = false) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw UploadError.invalidFile
        }
        
        let folder = isProcessed ? "processed" : "original"
        let storagePath = "conflict-cases/\(userId)/\(caseNumber)/documents/\(documentId)/\(folder)/page_\(pageIndex).jpg"
        
        print("📤 Uploading document image to Firebase...")
        print("   Path: \(storagePath)")
        
        let storageRef = storage.reference().child(storagePath)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        print("✅ Document image uploaded: \(downloadURL.absoluteString)")
        return downloadURL.absoluteString
    }
    
    /// Upload multiple document images and return their URLs
    func uploadDocumentImages(_ images: [UIImage], caseNumber: String, documentId: String, userId: String, isProcessed: Bool = false) async throws -> [String] {
        var urls: [String] = []
        
        for (index, image) in images.enumerated() {
            let url = try await uploadDocumentImage(
                image,
                caseNumber: caseNumber,
                documentId: documentId,
                pageIndex: index,
                userId: userId,
                isProcessed: isProcessed
            )
            urls.append(url)
        }
        
        print("✅ Uploaded \(urls.count) document images")
        return urls
    }
    
    /// Upload signature image to Firebase Storage
    func uploadSignatureImage(_ signatureData: Data, caseNumber: String, documentId: String, userId: String) async throws -> String {
        let storagePath = "conflict-cases/\(userId)/\(caseNumber)/documents/\(documentId)/signature.png"
        
        print("📤 Uploading signature to Firebase...")
        
        let storageRef = storage.reference().child(storagePath)
        let metadata = StorageMetadata()
        metadata.contentType = "image/png"
        
        _ = try await storageRef.putDataAsync(signatureData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        print("✅ Signature uploaded: \(downloadURL.absoluteString)")
        return downloadURL.absoluteString
    }
    
    /// Delete all images for a document
    func deleteDocumentImages(caseNumber: String, documentId: String, userId: String) async throws {
        let basePath = "conflict-cases/\(userId)/\(caseNumber)/documents/\(documentId)"
        
        print("🗑️ Deleting document images from Firebase...")
        
        let storageRef = storage.reference().child(basePath)
        
        do {
            let result = try await storageRef.listAll()
            for item in result.items {
                try await item.delete()
            }
            // Also check subdirectories
            for prefix in result.prefixes {
                let subResult = try await prefix.listAll()
                for item in subResult.items {
                    try await item.delete()
                }
            }
            print("✅ Document images deleted")
        } catch {
            print("⚠️ Could not delete document images: \(error.localizedDescription)")
        }
    }
}
