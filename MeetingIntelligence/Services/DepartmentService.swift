//
//  DepartmentService.swift
//  MeetingIntelligence
//
//  Service for fetching departments from backend
//

import Foundation
import Combine
import FirebaseAuth

// MARK: - Department Models
struct DepartmentResponse: Codable {
    let success: Bool
    let data: DepartmentData
}

struct DepartmentData: Codable {
    let departments: [Department]
}

struct Department: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let facilityId: String
    let createdAt: String
    let updatedAt: String
    let Facility: FacilityBasicInfo?
    
    // Conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Department, rhs: Department) -> Bool {
        lhs.id == rhs.id
    }
}

struct FacilityBasicInfo: Codable {
    let id: String
    let name: String
}

// MARK: - Department Service
@MainActor
class DepartmentService: ObservableObject {
    static let shared = DepartmentService()
    
    private let baseURL = "https://dashmet-rca-api.onrender.com/api"
    
    @Published var departments: [Department] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private init() {}
    
    /// Fetch all departments from backend
    func fetchDepartments(facilityId: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        var urlString = "\(baseURL)/facilities/departments"
        if let facilityId = facilityId {
            urlString += "?facilityId=\(facilityId)"
        }
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Firebase auth token
        if let token = try? await FirebaseAuthService.shared.getIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let result = try decoder.decode(DepartmentResponse.self, from: data)
                departments = result.data.departments
            } else {
                // Try to parse error response
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorJson["error"] as? String {
                    errorMessage = message
                } else {
                    errorMessage = "Failed to fetch departments (Status: \(httpResponse.statusCode))"
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            print("DepartmentService error: \(error)")
        }
        
        isLoading = false
    }
    
    /// Get department names as array of strings (for simple dropdowns)
    var departmentNames: [String] {
        departments.map { $0.name }
    }
}
