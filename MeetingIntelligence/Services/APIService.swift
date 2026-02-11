//
//  APIService.swift
//  MeetingIntelligence
//
//  Backend API Service for user registration and authentication
//

import Foundation

// MARK: - API Response Models
struct PhoneCheckResponse: Codable {
    let exists: Bool
    let user: UserBasicInfo?
}

struct UserBasicInfo: Codable {
    let id: String
    let firstName: String
    let lastName: String
}

struct EmailCheckResponse: Codable {
    let success: Bool
    let exists: Bool
    let email: String?
    let firstName: String?
    let lastName: String?
    let userId: String?
}

struct AccessCodeValidationResponse: Codable {
    let valid: Bool
    let accessCodeId: String?
    let role: String?
    let organizationId: String?
    let organizationName: String?
    let facilities: [FacilityInfo]?
    let error: String?
}

struct FacilityInfo: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let address: String?
    let timezone: String
}

struct RegistrationRequest: Codable {
    let firstName: String
    let lastName: String
    let email: String
    let phone: String
    let accessCodeId: String
    let facilityId: String
    let firebaseUid: String?
}

struct RegistrationResponse: Codable {
    let success: Bool
    let isExistingUser: Bool?
    let message: String?
    let user: RegisteredUser?
    let error: String?
}

struct RegisteredUser: Codable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let phone: String?
    let role: String
    let organizationId: String
    let facilityId: String?
}

struct LinkFirebaseResponse: Codable {
    let success: Bool
    let user: LinkedUserInfo?
    let error: String?
}

struct LinkedUserInfo: Codable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String?
    let role: String?
    let organizationId: String?
    let facilityId: String?
}

struct APIError: Codable {
    let error: String
}

// MARK: - API Service
class APIService {
    static let shared = APIService()
    
    // DashMet RCA Backend on Render
    private let baseURL = "https://dashmet-rca-api.onrender.com/api"
    
    private init() {}
    
    // MARK: - Check Phone Number
    func checkPhone(_ phone: String) async throws -> PhoneCheckResponse {
        let url = URL(string: "\(baseURL)/mobile/check-phone")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["phone": phone])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(PhoneCheckResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Unknown error")
        }
    }
    
    // MARK: - Check Email
    func checkEmail(_ email: String) async throws -> EmailCheckResponse {
        let url = URL(string: "\(baseURL)/mobile/check-email")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["email": email])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(EmailCheckResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Unknown error")
        }
    }
    
    // MARK: - Validate Access Code
    func validateAccessCode(_ code: String) async throws -> AccessCodeValidationResponse {
        let url = URL(string: "\(baseURL)/mobile/validate-access-code")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["code": code])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(AccessCodeValidationResponse.self, from: data)
        } else if httpResponse.statusCode == 404 || httpResponse.statusCode == 400 {
            let errorResponse = try JSONDecoder().decode(AccessCodeValidationResponse.self, from: data)
            return errorResponse
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Unknown error")
        }
    }
    
    // MARK: - Register User
    func registerUser(_ registration: RegistrationRequest) async throws -> RegistrationResponse {
        let url = URL(string: "\(baseURL)/mobile/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(registration)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        // Accept both 200 (existing user updated) and 201 (new user created)
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            return try JSONDecoder().decode(RegistrationResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            return RegistrationResponse(success: false, isExistingUser: nil, message: nil, user: nil, error: error?.error ?? "Registration failed")
        }
    }
    
    // MARK: - Link Firebase UID
    func linkFirebaseUID(phone: String, firebaseUid: String) async throws -> LinkFirebaseResponse {
        let url = URL(string: "\(baseURL)/mobile/link-firebase")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["phone": phone, "firebaseUid": firebaseUid])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(LinkFirebaseResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Unknown error")
        }
    }
    
    // MARK: - Task API Methods
    
    /// Fetch tasks for a user
    func getTasks(userId: String, filter: String = "all", status: String? = nil, meetingId: String? = nil) async throws -> TaskListResponse {
        var urlString = "\(baseURL)/mobile/tasks?userId=\(userId)&filter=\(filter)"
        if let status = status {
            urlString += "&status=\(status)"
        }
        if let meetingId = meetingId {
            urlString += "&meetingId=\(meetingId)"
        }
        
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try TaskItem.decoder.decode(TaskListResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to fetch tasks")
        }
    }
    
    /// Get a single task by ID
    func getTask(id: String) async throws -> TaskResponse {
        let url = URL(string: "\(baseURL)/mobile/tasks/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try TaskItem.decoder.decode(TaskResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to fetch task")
        }
    }
    
    /// Create a new task
    func createTask(_ task: CreateTaskRequest) async throws -> TaskResponse {
        let url = URL(string: "\(baseURL)/mobile/tasks")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(task)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 {
            return try TaskItem.decoder.decode(TaskResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to create task")
        }
    }
    
    /// Update a task
    func updateTask(id: String, update: UpdateTaskRequest) async throws -> TaskResponse {
        let url = URL(string: "\(baseURL)/mobile/tasks/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(update)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try TaskItem.decoder.decode(TaskResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to update task")
        }
    }
    
    /// Delete a task
    func deleteTask(id: String) async throws -> TaskDeleteResponse {
        let url = URL(string: "\(baseURL)/mobile/tasks/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(TaskDeleteResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to delete task")
        }
    }
    
    /// Extract action items from transcript using AI
    func extractActionItems(_ request: ExtractActionItemsRequest) async throws -> TaskListResponse {
        let url = URL(string: "\(baseURL)/mobile/tasks/extract-from-transcript")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 {
            return try TaskItem.decoder.decode(TaskListResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to extract action items")
        }
    }
    
    // MARK: - Task Comment API Methods
    
    /// Add a comment to a task
    func addTaskComment(taskId: String, request: CreateCommentRequest) async throws -> TaskCommentResponse {
        let url = URL(string: "\(baseURL)/mobile/tasks/\(taskId)/comments")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 {
            return try TaskItem.decoder.decode(TaskCommentResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to add comment")
        }
    }
    
    /// Get comments for a task
    func getTaskComments(taskId: String) async throws -> TaskCommentsListResponse {
        let url = URL(string: "\(baseURL)/mobile/tasks/\(taskId)/comments")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try TaskItem.decoder.decode(TaskCommentsListResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to fetch comments")
        }
    }
    
    /// Delete a comment
    func deleteTaskComment(commentId: String) async throws -> TaskDeleteResponse {
        let url = URL(string: "\(baseURL)/mobile/tasks/comments/\(commentId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(TaskDeleteResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to delete comment")
        }
    }
    
    // MARK: - Task Evidence API Methods
    
    /// Add evidence to a task
    func addTaskEvidence(taskId: String, request: CreateEvidenceRequest) async throws -> TaskEvidenceResponse {
        let url = URL(string: "\(baseURL)/mobile/tasks/\(taskId)/evidence")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 {
            return try TaskItem.decoder.decode(TaskEvidenceResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to add evidence")
        }
    }
    
    /// Get evidence for a task
    func getTaskEvidence(taskId: String) async throws -> TaskEvidenceListResponse {
        let url = URL(string: "\(baseURL)/mobile/tasks/\(taskId)/evidence")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try TaskItem.decoder.decode(TaskEvidenceListResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to fetch evidence")
        }
    }
    
    /// Delete evidence
    func deleteTaskEvidence(evidenceId: String) async throws -> TaskDeleteResponse {
        let url = URL(string: "\(baseURL)/mobile/tasks/evidence/\(evidenceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(TaskDeleteResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to delete evidence")
        }
    }
    
    // MARK: - Organization Users API Methods
    
    /// Get all users in an organization (for assigning tasks)
    func getOrganizationUsers(organizationId: String) async throws -> OrganizationUsersResponse {
        let url = URL(string: "\(baseURL)/mobile/tasks/users/organization/\(organizationId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(OrganizationUsersResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to fetch users")
        }
    }
    
    // MARK: - Task Assignees API Methods
    
    /// Add assignees to a task
    func addTaskAssignees(taskId: String, userIds: [String], assignedBy: String?) async throws -> TaskResponse {
        let url = URL(string: "\(baseURL)/mobile/tasks/\(taskId)/assignees")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "userIds": userIds,
            "assignedBy": assignedBy as Any
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 {
            return try TaskItem.decoder.decode(TaskResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to add assignees")
        }
    }
    
    /// Remove an assignee from a task
    func removeTaskAssignee(taskId: String, userId: String) async throws -> TaskResponse {
        let url = URL(string: "\(baseURL)/mobile/tasks/\(taskId)/assignees/\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try TaskItem.decoder.decode(TaskResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to remove assignee")
        }
    }
    
    /// Replace all assignees for a task
    func updateTaskAssignees(taskId: String, userIds: [String], assignedBy: String?) async throws -> TaskResponse {
        let url = URL(string: "\(baseURL)/mobile/tasks/\(taskId)/assignees")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "userIds": userIds,
            "assignedBy": assignedBy as Any
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try TaskItem.decoder.decode(TaskResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to update assignees")
        }
    }
    
    // MARK: - Meeting API Methods
    
    /// JSON decoder configured for ISO8601 dates
    private var meetingDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try ISO8601 with fractional seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Try ISO8601 without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        return decoder
    }
    
    /// Fetch meetings for a user
    func getMeetings(userId: String, status: String? = nil, limit: Int = 50, offset: Int = 0) async throws -> MeetingsResponse {
        var urlString = "\(baseURL)/mobile/meetings?userId=\(userId)&limit=\(limit)&offset=\(offset)"
        if let status = status {
            urlString += "&status=\(status)"
        }
        
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token
        if let token = try? await FirebaseAuthService.shared.getIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try meetingDecoder.decode(MeetingsResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to fetch meetings")
        }
    }
    
    /// Get a single meeting by ID with full details
    func getMeeting(meetingId: String) async throws -> MeetingResponse {
        let url = URL(string: "\(baseURL)/mobile/meetings/\(meetingId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token
        if let token = try? await FirebaseAuthService.shared.getIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try meetingDecoder.decode(MeetingResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to fetch meeting")
        }
    }
    
    /// Create a new meeting (draft)
    func createMeeting(_ meeting: CreateMeetingRequest) async throws -> MeetingResponse {
        let url = URL(string: "\(baseURL)/mobile/meetings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token
        if let token = try? await FirebaseAuthService.shared.getIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Use encoder with ISO8601 date format
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(meeting)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 {
            return try meetingDecoder.decode(MeetingResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to create meeting")
        }
    }
    
    /// Update a meeting
    func updateMeeting(meetingId: String, update: UpdateMeetingRequest) async throws -> MeetingResponse {
        let url = URL(string: "\(baseURL)/mobile/meetings/\(meetingId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token
        if let token = try? await FirebaseAuthService.shared.getIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Custom encoder for date handling
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(update)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try meetingDecoder.decode(MeetingResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to update meeting")
        }
    }
    
    /// Update meeting status (convenience method)
    func updateMeeting(meetingId: String, status: MeetingStatus) async throws {
        let update = UpdateMeetingRequest(
            title: nil,
            meetingType: nil,
            location: nil,
            tags: nil,
            language: nil,
            status: status.rawValue,
            recordingUrl: nil,
            duration: nil,
            recordedAt: nil,
            processingError: nil
        )
        let _ = try await updateMeeting(meetingId: meetingId, update: update)
    }
    
    /// Delete a meeting
    func deleteMeeting(meetingId: String) async throws -> MeetingResponse {
        let url = URL(string: "\(baseURL)/mobile/meetings/\(meetingId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token
        if let token = try? await FirebaseAuthService.shared.getIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try meetingDecoder.decode(MeetingResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to delete meeting")
        }
    }
    
    /// Add a bookmark to a meeting
    func addBookmark(meetingId: String, request bookmarkRequest: CreateBookmarkRequest) async throws -> BookmarkResponse {
        let url = URL(string: "\(baseURL)/mobile/meetings/\(meetingId)/bookmarks")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token
        if let token = try? await FirebaseAuthService.shared.getIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try JSONEncoder().encode(bookmarkRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 {
            return try meetingDecoder.decode(BookmarkResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to add bookmark")
        }
    }
    
    /// Add a participant to a meeting
    func addParticipant(meetingId: String, request participantRequest: AddParticipantRequest) async throws -> ParticipantResponse {
        let url = URL(string: "\(baseURL)/mobile/meetings/\(meetingId)/participants")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(participantRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 {
            return try meetingDecoder.decode(ParticipantResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to add participant")
        }
    }
    
    /// Mark meeting as uploaded with recording info
    func uploadMeeting(meetingId: String, request uploadRequest: UploadMeetingRequest) async throws -> MeetingResponse {
        let url = URL(string: "\(baseURL)/mobile/meetings/\(meetingId)/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(uploadRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try meetingDecoder.decode(MeetingResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to upload meeting")
        }
    }
    
    /// Notify backend that audio is ready for AI processing
    func notifyAudioReady(meetingId: String, audioUrl: String, duration: Int, language: String?, speakerCountHint: Int?) async throws {
        let url = URL(string: "\(baseURL)/mobile/meetings/\(meetingId)/audio-ready")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let audioRequest = AudioReadyRequest(
            audioUrl: audioUrl,
            duration: duration,
            language: language,
            speakerCountHint: speakerCountHint
        )
        request.httpBody = try JSONEncoder().encode(audioRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        // Accept 200, 201, or 202 (accepted for processing)
        guard (200...202).contains(httpResponse.statusCode) else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to notify audio ready")
        }
        
        print("✅ Backend notified: Audio ready for meeting \(meetingId)")
    }
    
    // MARK: - Transcript Methods
    
    /// Save transcript to database
    func saveTranscript(meetingId: String, rawText: String, processedText: String?, type: String = "raw") async throws {
        let url = URL(string: "\(baseURL)/mobile/meetings/\(meetingId)/transcript")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token
        if let token = try? await FirebaseAuthService.shared.getIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body: [String: Any] = [
            "rawText": rawText,
            "type": type
        ]
        
        if let processed = processedText {
            body["processedText"] = processed
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        guard (200...201).contains(httpResponse.statusCode) else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to save transcript")
        }
        
        print("✅ Transcript saved to database for meeting \(meetingId)")
    }
    
    /// Save summary to database
    func saveSummary(meetingId: String, executiveSummary: String?, keyPoints: [String]? = nil) async throws {
        let url = URL(string: "\(baseURL)/mobile/meetings/\(meetingId)/summary")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token
        if let token = try? await FirebaseAuthService.shared.getIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body: [String: Any] = [:]
        
        if let summary = executiveSummary {
            body["executiveSummary"] = summary
        }
        
        if let points = keyPoints {
            body["keyPoints"] = points
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        guard (200...201).contains(httpResponse.statusCode) else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to save summary")
        }
        
        print("✅ Summary saved to database for meeting \(meetingId)")
    }
    
    // MARK: - Fetch Departments
    func fetchDepartments(facilityId: String? = nil) async throws -> [DepartmentInfo] {
        var urlString = "\(baseURL)/facilities/departments"
        if let facilityId = facilityId {
            urlString += "?facilityId=\(facilityId)"
        }
        
        guard let url = URL(string: urlString) else {
            throw APIServiceError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token
        if let token = try? await FirebaseAuthService.shared.getIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to fetch departments")
        }
        
        let result = try JSONDecoder().decode(DepartmentsResponse.self, from: data)
        return result.data.departments
    }
    
    // MARK: - User Profile Methods
    
    /// Get current user profile
    func getCurrentUserProfile(token: String) async throws -> UserProfileResponse {
        let url = URL(string: "\(baseURL)/users/me")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(UserProfileResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to fetch user profile")
        }
    }
    
    /// Upload profile picture
    func uploadProfilePicture(imageData: Data, token: String) async throws -> ProfilePictureResponse {
        let url = URL(string: "\(baseURL)/users/profile-picture")!
        
        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var body = Data()
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"profilePicture\"; filename=\"profile.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(ProfilePictureResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to upload profile picture")
        }
    }
    
    /// Delete profile picture
    func deleteProfilePicture(token: String) async throws -> SimpleResponse {
        let url = URL(string: "\(baseURL)/users/profile-picture")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(SimpleResponse.self, from: data)
        } else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw APIServiceError.serverError(error?.error ?? "Failed to delete profile picture")
        }
    }
}

// MARK: - User Profile Response Models
struct UserProfileResponse: Codable {
    let success: Bool
    let data: UserProfileData?
    let error: String?
}

struct UserProfileData: Codable {
    let user: UserProfile
}

struct UserProfile: Codable {
    let id: String
    let email: String?
    let firstName: String
    let lastName: String
    let role: String?
    let isActive: Bool?
    let profilePicture: String?
    let organizationId: String?
    let createdAt: String?
    let lastLoginAt: String?
}

struct ProfilePictureResponse: Codable {
    let success: Bool
    let data: ProfilePictureData?
    let message: String?
    let error: String?
}

struct ProfilePictureData: Codable {
    let profilePicture: String
    let user: UserProfile?
}

struct SimpleResponse: Codable {
    let success: Bool
    let message: String?
    let error: String?
}

// MARK: - Department Models
struct DepartmentsResponse: Codable {
    let success: Bool
    let data: DepartmentsData
}

struct DepartmentsData: Codable {
    let departments: [DepartmentInfo]
}

struct DepartmentInfo: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let facilityId: String
    let createdAt: String?
    let updatedAt: String?
    let Facility: DepartmentFacility?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, facilityId, createdAt, updatedAt, Facility
    }
}

struct DepartmentFacility: Codable, Hashable {
    let id: String
    let name: String
}

// MARK: - API Errors
enum APIServiceError: LocalizedError {
    case invalidResponse
    case serverError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return message
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}
