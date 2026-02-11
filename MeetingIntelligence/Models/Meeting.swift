//
//  Meeting.swift
//  MeetingIntelligence
//
//  Meeting model for the Meeting Intelligence app
//

import Foundation

// MARK: - Meeting Status
enum MeetingStatus: String, Codable, CaseIterable {
    case draft = "DRAFT"
    case recording = "RECORDING"
    case uploading = "UPLOADING"
    case uploaded = "UPLOADED"
    case processing = "PROCESSING"
    case ready = "READY"
    case needsReview = "NEEDS_REVIEW"
    case published = "PUBLISHED"
    case failed = "FAILED"
    
    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .recording: return "Recording"
        case .uploading: return "Uploading"
        case .uploaded: return "Uploaded"
        case .processing: return "Processing"
        case .ready: return "Ready"
        case .needsReview: return "Needs Review"
        case .published: return "Published"
        case .failed: return "Failed"
        }
    }
    
    var icon: String {
        switch self {
        case .draft: return "doc.badge.clock"
        case .recording: return "mic.fill"
        case .uploading: return "icloud.and.arrow.up"
        case .uploaded: return "checkmark.icloud"
        case .processing: return "gearshape.2"
        case .ready: return "checkmark.circle"
        case .needsReview: return "eye"
        case .published: return "checkmark.seal.fill"
        case .failed: return "exclamationmark.triangle"
        }
    }
    
    var color: String {
        switch self {
        case .draft: return "6B7280"        // Gray
        case .recording: return "EF4444"    // Red
        case .uploading: return "3B82F6"    // Blue
        case .uploaded: return "8B5CF6"     // Purple
        case .processing: return "F59E0B"   // Amber
        case .ready: return "10B981"        // Green
        case .needsReview: return "F97316"  // Orange
        case .published: return "059669"    // Emerald
        case .failed: return "DC2626"       // Red Dark
        }
    }
    
    /// Whether this status indicates the meeting is still being prepared
    var isPreparing: Bool {
        switch self {
        case .draft, .recording, .uploading, .uploaded, .processing:
            return true
        default:
            return false
        }
    }
    
    /// Whether this status allows editing of meeting details
    var isEditable: Bool {
        switch self {
        case .draft, .recording, .ready, .needsReview:
            return true
        default:
            return false
        }
    }
}

// MARK: - Meeting Type
enum MeetingType: String, Codable, CaseIterable {
    case general = "GENERAL"
    case standup = "STANDUP"
    case oneOnOne = "ONE_ON_ONE"
    case teamSync = "TEAM_SYNC"
    case clientCall = "CLIENT_CALL"
    case interview = "INTERVIEW"
    case brainstorm = "BRAINSTORM"
    case review = "REVIEW"
    case other = "OTHER"
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .standup: return "Standup"
        case .oneOnOne: return "1:1"
        case .teamSync: return "Team Sync"
        case .clientCall: return "Client Call"
        case .interview: return "Interview"
        case .brainstorm: return "Brainstorm"
        case .review: return "Review"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "bubble.left.and.bubble.right"
        case .standup: return "figure.stand"
        case .oneOnOne: return "person.2"
        case .teamSync: return "person.3"
        case .clientCall: return "phone"
        case .interview: return "person.badge.plus"
        case .brainstorm: return "lightbulb"
        case .review: return "doc.text.magnifyingglass"
        case .other: return "ellipsis.circle"
        }
    }
    
    var color: String {
        switch self {
        case .general: return "6B7280"      // Gray
        case .standup: return "8B5CF6"      // Purple
        case .oneOnOne: return "EC4899"     // Pink
        case .teamSync: return "3B82F6"     // Blue
        case .clientCall: return "10B981"   // Green
        case .interview: return "F59E0B"    // Amber
        case .brainstorm: return "F97316"   // Orange
        case .review: return "06B6D4"       // Cyan
        case .other: return "6366F1"        // Indigo
        }
    }
}

// MARK: - Meeting User (Lightweight user info)
struct MeetingUser: Codable, Identifiable, Hashable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    var initials: String {
        let first = firstName.prefix(1).uppercased()
        let last = lastName.prefix(1).uppercased()
        return "\(first)\(last)"
    }
}

// MARK: - Meeting Participant
struct MeetingParticipant: Codable, Identifiable, Hashable {
    let id: String
    let meetingId: String
    let userId: String?
    let user: MeetingUser?
    let name: String?
    let email: String?
    let phone: String?
    let speakerLabel: String?
    let createdAt: Date
    
    var displayName: String {
        if let user = user {
            return user.fullName
        }
        return name ?? email ?? "Unknown"
    }
    
    var displayInitials: String {
        if let user = user {
            return user.initials
        }
        if let name = name {
            let parts = name.split(separator: " ")
            if parts.count >= 2 {
                return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
            }
            return String(name.prefix(2)).uppercased()
        }
        return "??"
    }
}

// MARK: - Meeting Bookmark
struct MeetingBookmark: Codable, Identifiable, Hashable {
    let id: String
    let meetingId: String
    let timestamp: Int  // Seconds from start
    let label: String?
    let note: String?
    let createdAt: Date
    
    /// Formatted timestamp string (e.g., "1:23" or "10:45")
    var formattedTimestamp: String {
        let minutes = timestamp / 60
        let seconds = timestamp % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Transcript Block
struct TranscriptBlock: Codable, Identifiable, Hashable {
    let id: String
    let meetingId: String
    let speakerLabel: String
    let speakerId: String?
    let content: String
    let startTime: Int
    let endTime: Int
    let confidence: Double?
    let createdAt: Date
    
    /// Formatted start time string
    var formattedStartTime: String {
        let minutes = startTime / 60
        let seconds = startTime % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Duration of this block in seconds
    var duration: Int {
        endTime - startTime
    }
}

// MARK: - Meeting Summary
struct MeetingSummary: Codable, Identifiable, Hashable {
    let id: String
    let meetingId: String
    let executiveSummary: String?  // Full AI-generated summary text
    let keyPoints: [String]?       // Array of key points from JSON
    let decisions: [String]?       // Array of decisions from JSON
    let risks: [String]?           // Array of risks/concerns
    let questions: [String]?       // Array of open questions
    let nextSteps: [String]?       // Array of next steps
    let version: Int?
    let generatedAt: Date?
    let editedAt: Date?
    
    // Legacy fields for backward compatibility
    let overview: String?           // Alias for executiveSummary
    let topics: [String]?           // Alias for discussion topics
    let sentiment: String?
    let engagementScore: Double?
    let speakerStats: String?
    let createdAt: Date?
    
    /// Display summary - uses executiveSummary or overview
    var displaySummary: String {
        executiveSummary ?? overview ?? "No summary available"
    }
    
    /// All key points as array
    var allKeyPoints: [String] {
        keyPoints ?? []
    }
    
    /// All decisions as array
    var allDecisions: [String] {
        decisions ?? []
    }
    
    /// All next steps as array
    var allNextSteps: [String] {
        nextSteps ?? []
    }
}

// MARK: - Meeting Attachment
struct MeetingAttachment: Codable, Identifiable, Hashable {
    let id: String
    let meetingId: String
    let type: String
    let name: String
    let url: String
    let size: Int?
    let mimeType: String?
    let createdAt: Date
    
    /// File size formatted for display
    var formattedSize: String? {
        guard let size = size else { return nil }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

// MARK: - Meeting Count
struct MeetingCount: Codable, Hashable {
    let actionItems: Int
    let transcript: Int?
}

// MARK: - Meeting Model
struct Meeting: Codable, Identifiable, Hashable {
    let id: String
    let title: String?
    let meetingType: MeetingType
    let status: MeetingStatus
    
    // Location & Context
    let location: String?
    let tags: [String]
    let language: String
    
    // Recording info
    let recordingUrl: String?
    let duration: Int?  // Duration in seconds
    let recordedAt: Date?
    
    // AI Processing
    let processingStartedAt: Date?
    let processingCompletedAt: Date?
    let processingError: String?
    
    // Ownership
    let creatorId: String
    let creator: MeetingUser?
    let organizationId: String
    let facilityId: String?
    
    // Timestamps
    let createdAt: Date
    let updatedAt: Date
    let publishedAt: Date?
    
    // Relations (optional - included in detailed views)
    let participants: [MeetingParticipant]?
    let bookmarks: [MeetingBookmark]?
    let transcript: [TranscriptBlock]?
    let summary: MeetingSummary?
    let actionItems: [TaskItem]?
    let attachments: [MeetingAttachment]?
    
    // Counts (for list views)
    let _count: MeetingCount?
    
    // MARK: - Computed Properties
    
    /// Display title (uses type name if no title set)
    var displayTitle: String {
        if let title = title, !title.isEmpty {
            return title
        }
        return "\(meetingType.displayName) Meeting"
    }
    
    /// Formatted duration string (e.g., "1h 23m" or "45m")
    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    /// Formatted recording date
    var formattedRecordedDate: String? {
        guard let recordedAt = recordedAt else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: recordedAt)
    }
    
    /// Formatted created date
    var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    /// Number of action items
    var actionItemCount: Int {
        actionItems?.count ?? _count?.actionItems ?? 0
    }
    
    /// Number of transcript blocks
    var transcriptBlockCount: Int {
        transcript?.count ?? _count?.transcript ?? 0
    }
    
    /// Number of participants
    var participantCount: Int {
        participants?.count ?? 0
    }
    
    /// Number of bookmarks
    var bookmarkCount: Int {
        bookmarks?.count ?? 0
    }
    
    /// Whether the meeting has transcript content
    var hasTranscript: Bool {
        transcriptBlockCount > 0
    }
    
    /// Whether the meeting has a summary
    var hasSummary: Bool {
        summary != nil
    }
    
    /// Whether the meeting has action items
    var hasActionItems: Bool {
        actionItemCount > 0
    }
    
    /// Creator's full name
    var creatorName: String {
        creator?.fullName ?? "Unknown"
    }
    
    /// Tags formatted as a comma-separated string
    var tagsFormatted: String {
        tags.joined(separator: ", ")
    }
    
    // MARK: - Preview Support
    static var preview: Meeting {
        Meeting(
            id: "preview-meeting-123",
            title: "Team Standup",
            meetingType: .standup,
            status: .draft,
            location: "Conference Room A",
            tags: ["daily", "team"],
            language: "en-US",
            recordingUrl: nil,
            duration: nil,
            recordedAt: nil,
            processingStartedAt: nil,
            processingCompletedAt: nil,
            processingError: nil,
            creatorId: "user-123",
            creator: nil,
            organizationId: "org-123",
            facilityId: nil,
            createdAt: Date(),
            updatedAt: Date(),
            publishedAt: nil,
            participants: nil,
            bookmarks: nil,
            transcript: nil,
            summary: nil,
            actionItems: nil,
            attachments: nil,
            _count: nil
        )
    }
}

// MARK: - API Response Wrappers

/// Response for single meeting
struct MeetingResponse: Codable {
    let success: Bool
    let meeting: Meeting?
    let message: String?
    let error: String?
}

/// Response for list of meetings
struct MeetingsResponse: Codable {
    let success: Bool
    let meetings: [Meeting]
    let count: Int
    let totalCount: Int
    let error: String?
}

/// Response for meeting bookmark creation
struct BookmarkResponse: Codable {
    let success: Bool
    let bookmark: MeetingBookmark?
    let error: String?
}

/// Response for meeting participant creation
struct ParticipantResponse: Codable {
    let success: Bool
    let participant: MeetingParticipant?
    let error: String?
}

// MARK: - Request Models

/// Request body for creating a new meeting
struct CreateMeetingRequest: Codable {
    let title: String?
    let meetingType: String?
    let location: String?
    let locationType: String?
    let tags: [String]?
    let language: String?
    let scheduledAt: Date?
    let departmentId: String?
    let objective: String?
    let agendaItems: [String]?
    let liveTranscriptionEnabled: Bool?
    let aiProcessingMode: String?
    let confidentialityLevel: String?
    let participants: [CreateParticipantRequest]?
    let creatorId: String
    let organizationId: String
    let facilityId: String?
}

/// Request for adding participant during meeting creation
struct CreateParticipantRequest: Codable {
    let userId: String?
    let name: String?
    let email: String?
    let phone: String?
}

/// Request body for updating a meeting
struct UpdateMeetingRequest: Codable {
    let title: String?
    let meetingType: String?
    let location: String?
    let tags: [String]?
    let language: String?
    let status: String?
    let recordingUrl: String?
    let duration: Int?
    let recordedAt: Date?
    let processingError: String?
}

/// Request body for uploading meeting recording
struct UploadMeetingRequest: Codable {
    let recordingUrl: String
    let duration: Int?
    let recordedAt: Date?
    let language: String?
    let speakerCountHint: Int?
}

/// Request body for notifying backend audio is ready for processing
struct AudioReadyRequest: Codable {
    let audioUrl: String
    let duration: Int
    let language: String?
    let speakerCountHint: Int?
}

/// Request body for creating a bookmark
struct CreateBookmarkRequest: Codable {
    let timestamp: Int
    let label: String?
    let note: String?
}

/// Request body for adding a participant
struct AddParticipantRequest: Codable {
    let userId: String?
    let name: String?
    let email: String?
    let phone: String?
    let speakerLabel: String?
}
