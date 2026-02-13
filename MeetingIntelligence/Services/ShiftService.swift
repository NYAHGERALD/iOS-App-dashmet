//
//  ShiftService.swift
//  MeetingIntelligence
//
//  Service for fetching shifts from backend
//

import Foundation
import Combine
import FirebaseAuth

// MARK: - Shift Models
struct ShiftResponse: Codable {
    let success: Bool
    let data: ShiftData
}

struct ShiftData: Codable {
    let shifts: [ShiftItem]
}

struct ShiftItem: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let startTime: String
    let endTime: String
    let facilityId: String?
    let createdAt: String
    let updatedAt: String
    let Facility: ShiftFacilityInfo?
    
    // Conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ShiftItem, rhs: ShiftItem) -> Bool {
        lhs.id == rhs.id
    }
    
    /// Display name with time range
    var displayName: String {
        "\(name) (\(startTime) - \(endTime))"
    }
}

struct ShiftFacilityInfo: Codable {
    let id: String
    let name: String
}

// MARK: - Shift Service
@MainActor
class ShiftService: ObservableObject {
    static let shared = ShiftService()
    
    private let baseURL = "https://dashmet-rca-api.onrender.com/api"
    
    @Published var shifts: [ShiftItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private init() {}
    
    /// Fetch all shifts from backend
    func fetchShifts(facilityId: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        var urlString = "\(baseURL)/facilities/shifts"
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
                let result = try decoder.decode(ShiftResponse.self, from: data)
                shifts = result.data.shifts
            } else {
                // Try to parse error response
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorJson["error"] as? String {
                    errorMessage = message
                } else {
                    errorMessage = "Failed to fetch shifts (Status: \(httpResponse.statusCode))"
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            print("ShiftService error: \(error)")
        }
        
        isLoading = false
    }
    
    /// Get shift names as array of strings (for simple dropdowns)
    var shiftNames: [String] {
        shifts.map { $0.name }
    }
}
