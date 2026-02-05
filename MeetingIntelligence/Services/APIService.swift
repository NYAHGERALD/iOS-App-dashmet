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
    let user: UserBasicInfo?
    let error: String?
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
    func getTasks(userId: String, filter: String = "all", status: String? = nil) async throws -> TaskListResponse {
        var urlString = "\(baseURL)/mobile/tasks?userId=\(userId)&filter=\(filter)"
        if let status = status {
            urlString += "&status=\(status)"
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
            return try Task.decoder.decode(TaskListResponse.self, from: data)
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
            return try Task.decoder.decode(TaskResponse.self, from: data)
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
            return try Task.decoder.decode(TaskResponse.self, from: data)
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
            return try Task.decoder.decode(TaskResponse.self, from: data)
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
