//
//  MeetingViewModel.swift
//  MeetingIntelligence
//
//  Phase 3 - Meeting List ViewModel
//

import Foundation
import SwiftUI
import Combine

// MARK: - Meeting Filter
enum MeetingFilter: String, CaseIterable {
    case all = "All"
    case draft = "Drafts"
    case processing = "Processing"
    case ready = "Ready"
    case published = "Published"
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .draft: return "doc.badge.clock"
        case .processing: return "gearshape.2"
        case .ready: return "checkmark.circle"
        case .published: return "checkmark.seal.fill"
        }
    }
}

@MainActor
class MeetingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var meetings: [Meeting] = []
    @Published var isLoading: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var errorMessage: String?
    @Published var selectedFilter: MeetingFilter = .all
    @Published var selectedMeeting: Meeting?
    
    // MARK: - User Context (exposed for upload service)
    private(set) var userId: String?
    private(set) var organizationId: String?
    
    // MARK: - Computed Properties
    var filteredMeetings: [Meeting] {
        switch selectedFilter {
        case .all:
            return meetings
        case .draft:
            return meetings.filter { $0.status == .draft || $0.status == .recording }
        case .processing:
            return meetings.filter { 
                $0.status == .uploading || 
                $0.status == .uploaded || 
                $0.status == .processing 
            }
        case .ready:
            return meetings.filter { $0.status == .ready || $0.status == .needsReview }
        case .published:
            return meetings.filter { $0.status == .published }
        }
    }
    
    var hasNoMeetings: Bool {
        meetings.isEmpty && !isLoading
    }
    
    var meetingCountByStatus: [MeetingStatus: Int] {
        var counts: [MeetingStatus: Int] = [:]
        for status in MeetingStatus.allCases {
            counts[status] = meetings.filter { $0.status == status }.count
        }
        return counts
    }
    
    // Stats for dashboard
    var draftCount: Int {
        meetings.filter { $0.status == .draft || $0.status == .recording }.count
    }
    
    var processingCount: Int {
        meetings.filter { 
            $0.status == .uploading || 
            $0.status == .uploaded || 
            $0.status == .processing 
        }.count
    }
    
    var readyCount: Int {
        meetings.filter { $0.status == .ready || $0.status == .needsReview }.count
    }
    
    var publishedCount: Int {
        meetings.filter { $0.status == .published }.count
    }
    
    // MARK: - Initialization
    func configure(userId: String, organizationId: String?) {
        self.userId = userId
        self.organizationId = organizationId
    }
    
    // MARK: - Error Handling Helper
    
    /// Handles errors and sets errorMessage only for non-cancelled requests
    /// Cancelled requests (code -999) are ignored as they're typically from view transitions or duplicate refreshes
    private func handleError(_ error: Error, context: String) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            print("ℹ️ \(context): Request cancelled - ignoring")
        } else {
            errorMessage = error.localizedDescription
            print("❌ \(context): \(error)")
        }
    }
    
    // MARK: - API Methods
    
    /// Fetch meetings from the API
    func fetchMeetings() async {
        guard let userId = userId else {
            errorMessage = "User not configured"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await APIService.shared.getMeetings(userId: userId)
            
            if response.success {
                meetings = response.meetings
                print("✅ Fetched \(meetings.count) meetings")
            } else {
                errorMessage = response.error ?? "Failed to fetch meetings"
            }
        } catch {
            // Don't show error for cancelled requests (code -999)
            // This commonly happens during pull-to-refresh or view transitions
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                print("ℹ️ Request cancelled - ignoring")
            } else {
                errorMessage = error.localizedDescription
                print("❌ Error fetching meetings: \(error)")
            }
        }
        
        isLoading = false
    }
    
    /// Refresh meetings (for pull-to-refresh)
    func refreshMeetings() async {
        isRefreshing = true
        await fetchMeetings()
        isRefreshing = false
    }
    
    /// Create a new meeting (draft)
    func createMeeting(
        title: String? = nil,
        meetingType: MeetingType = .general,
        location: String? = nil,
        locationType: String? = nil,
        tags: [String] = [],
        language: String = "en",
        scheduledAt: Date? = nil,
        departmentId: String? = nil,
        objective: String? = nil,
        agendaItems: [String] = [],
        liveTranscriptionEnabled: Bool = true,
        aiProcessingMode: String? = nil,
        confidentialityLevel: String? = nil,
        participants: [CreateParticipantRequest] = []
    ) async -> Meeting? {
        guard let userId = userId, let organizationId = organizationId else {
            errorMessage = "User not configured"
            return nil
        }
        
        isLoading = true
        errorMessage = nil
        
        let request = CreateMeetingRequest(
            title: title,
            meetingType: meetingType.rawValue,
            location: location,
            locationType: locationType,
            tags: tags,
            language: language,
            scheduledAt: scheduledAt,
            departmentId: departmentId,
            objective: objective,
            agendaItems: agendaItems.isEmpty ? nil : agendaItems,
            liveTranscriptionEnabled: liveTranscriptionEnabled,
            aiProcessingMode: aiProcessingMode,
            confidentialityLevel: confidentialityLevel,
            participants: participants.isEmpty ? nil : participants,
            creatorId: userId,
            organizationId: organizationId,
            facilityId: nil
        )
        
        do {
            let response = try await APIService.shared.createMeeting(request)
            
            if response.success, let newMeeting = response.meeting {
                meetings.insert(newMeeting, at: 0)
                print("✅ Created meeting: \(newMeeting.displayTitle)")
                isLoading = false
                return newMeeting
            } else {
                errorMessage = response.error ?? "Failed to create meeting"
            }
        } catch {
            handleError(error, context: "Error creating meeting")
        }
        
        isLoading = false
        return nil
    }
    
    /// Update meeting details
    func updateMeeting(
        meetingId: String,
        title: String? = nil,
        meetingType: MeetingType? = nil,
        location: String? = nil,
        tags: [String]? = nil,
        status: MeetingStatus? = nil
    ) async -> Bool {
        errorMessage = nil
        
        let update = UpdateMeetingRequest(
            title: title,
            meetingType: meetingType?.rawValue,
            location: location,
            tags: tags,
            language: nil,
            status: status?.rawValue,
            recordingUrl: nil,
            duration: nil,
            recordedAt: nil,
            processingError: nil
        )
        
        do {
            let response = try await APIService.shared.updateMeeting(meetingId: meetingId, update: update)
            
            if response.success, let updatedMeeting = response.meeting {
                // Update local state
                if let index = meetings.firstIndex(where: { $0.id == meetingId }) {
                    meetings[index] = updatedMeeting
                }
                print("✅ Updated meeting: \(updatedMeeting.displayTitle)")
                return true
            } else {
                errorMessage = response.error ?? "Failed to update meeting"
            }
        } catch {
            handleError(error, context: "Error updating meeting")
        }
        
        return false
    }
    
    /// Delete a meeting
    func deleteMeeting(meetingId: String) async -> Bool {
        errorMessage = nil
        
        do {
            let response = try await APIService.shared.deleteMeeting(meetingId: meetingId)
            
            if response.success {
                // Remove from local state
                meetings.removeAll { $0.id == meetingId }
                print("✅ Deleted meeting")
                return true
            } else {
                errorMessage = response.error ?? "Failed to delete meeting"
            }
        } catch {
            handleError(error, context: "Error deleting meeting")
        }
        
        return false
    }
    
    /// Get full meeting details
    func getMeetingDetails(meetingId: String) async -> Meeting? {
        do {
            let response = try await APIService.shared.getMeeting(meetingId: meetingId)
            
            if response.success, let meeting = response.meeting {
                selectedMeeting = meeting
                return meeting
            } else {
                errorMessage = response.error ?? "Failed to fetch meeting details"
            }
        } catch {
            handleError(error, context: "Error fetching meeting details")
        }
        
        return nil
    }
    
    /// Add a bookmark to a meeting
    func addBookmark(
        meetingId: String,
        timestamp: Int,
        label: String? = nil,
        note: String? = nil
    ) async -> MeetingBookmark? {
        let request = CreateBookmarkRequest(
            timestamp: timestamp,
            label: label,
            note: note
        )
        
        do {
            let response = try await APIService.shared.addBookmark(meetingId: meetingId, request: request)
            
            if response.success, let bookmark = response.bookmark {
                print("✅ Added bookmark at \(bookmark.formattedTimestamp)")
                return bookmark
            } else {
                errorMessage = response.error ?? "Failed to add bookmark"
            }
        } catch {
            handleError(error, context: "Error adding bookmark")
        }
        
        return nil
    }
    
    /// Mark a meeting as uploaded with recording info
    func uploadMeeting(
        meetingId: String,
        recordingUrl: String,
        duration: Int?,
        recordedAt: Date?,
        language: String? = nil,
        speakerCountHint: Int? = nil
    ) async -> Bool {
        let request = UploadMeetingRequest(
            recordingUrl: recordingUrl,
            duration: duration,
            recordedAt: recordedAt,
            language: language,
            speakerCountHint: speakerCountHint
        )
        
        do {
            let response = try await APIService.shared.uploadMeeting(meetingId: meetingId, request: request)
            
            if response.success, let updatedMeeting = response.meeting {
                // Update local state
                if let index = meetings.firstIndex(where: { $0.id == meetingId }) {
                    meetings[index] = updatedMeeting
                }
                print("✅ Uploaded meeting recording")
                return true
            } else {
                errorMessage = response.error ?? "Failed to upload meeting"
            }
        } catch {
            handleError(error, context: "Error uploading meeting")
        }
        
        return false
    }
    
    /// Update meeting status and optionally upload audio (for recording flow)
    func updateMeetingWithAudio(
        meetingId: String,
        status: MeetingStatus? = nil,
        audioUrl: String? = nil,
        duration: Int? = nil,
        language: String? = nil,
        speakerCountHint: Int? = nil
    ) async -> Bool {
        // If we have audio URL, use the upload endpoint
        if let audioUrl = audioUrl {
            return await uploadMeeting(
                meetingId: meetingId,
                recordingUrl: audioUrl,
                duration: duration,
                recordedAt: Date(),
                language: language,
                speakerCountHint: speakerCountHint
            )
        }
        
        // Otherwise use regular update
        return await updateMeeting(
            meetingId: meetingId,
            status: status
        )
    }
    
    // MARK: - Helper Methods
    
    func clearError() {
        errorMessage = nil
    }
}
