//
//  OperationsService.swift
//  MeetingIntelligence
//
//  Service for Operations Issue reporting - connects to backend API
//

import Foundation
import Combine
import FirebaseAuth

// MARK: - Operations Models

struct OperationsIssue: Codable, Identifiable {
    let id: String
    let issueNumber: String
    let type: String
    let title: String
    let description: String
    let priority: String
    let status: String
    let departmentId: String
    let areaId: String?
    let lineId: String?
    let shiftId: String?
    let equipmentId: String?
    let componentId: String?
    let photos: [IssuePhoto]?
    let createdAt: String?
    let Department: IssueDepartment?
    let Area: IssueArea?
    let Line: IssueLine?
    let Shift: IssueShift?
    let Equipment: IssueEquipment?
    let Component: IssueComponent?
    let ReportedBy: IssueReporter?
}

struct IssuePhoto: Codable, Identifiable {
    let url: String
    let name: String?
    let storagePath: String?
    
    var id: String { url }
}

struct IssueDepartment: Codable {
    let id: String
    let name: String
}

struct IssueArea: Codable {
    let id: String
    let name: String
}

struct IssueLine: Codable {
    let id: String
    let name: String
    let lineNumber: String?
}

struct IssueShift: Codable {
    let id: String
    let name: String
}

struct IssueEquipment: Codable {
    let id: String
    let name: String
    let assetTag: String?
}

struct IssueComponent: Codable {
    let id: String
    let name: String
    let partNumber: String?
}

struct IssueReporter: Codable {
    let id: String
    let firstName: String
    let lastName: String
}

struct CreateIssueRequest: Codable {
    let type: String
    let title: String
    let description: String
    let priority: String
    let departmentId: String
    let areaId: String?
    let lineId: String?
    let shiftId: String?
    let equipmentId: String?
    let componentId: String?
}

struct CreateIssueResponse: Codable {
    let success: Bool
    let data: OperationsIssue?
    let message: String?
    let error: String?
}

struct IssuesListResponse: Codable {
    let success: Bool
    let data: [OperationsIssue]?
    let error: String?
}

// Cascading dropdown models
struct AreaItem: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let departmentId: String?
    
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AreaItem, rhs: AreaItem) -> Bool { lhs.id == rhs.id }
}

struct LineItem: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let lineNumber: String?
    let areaId: String?
    
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: LineItem, rhs: LineItem) -> Bool { lhs.id == rhs.id }
}

struct EquipmentItem: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let assetTag: String?
    let lineId: String?
    
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: EquipmentItem, rhs: EquipmentItem) -> Bool { lhs.id == rhs.id }
}

struct ComponentItem: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let partNumber: String?
    
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ComponentItem, rhs: ComponentItem) -> Bool { lhs.id == rhs.id }
}

struct AreasResponse: Codable {
    let success: Bool?
    let data: AreasData?
}

struct AreasData: Codable {
    let areas: [AreaItem]?
}

struct LinesResponse: Codable {
    let success: Bool?
    let data: LinesData?
}

struct LinesData: Codable {
    let lines: [LineItem]?
}

struct EquipmentResponse: Codable {
    let success: Bool?
    let data: EquipmentData?
}

struct EquipmentData: Codable {
    let equipment: [EquipmentItem]?
}

struct ComponentsResponse: Codable {
    let success: Bool?
    let data: ComponentsData?
}

struct ComponentsData: Codable {
    let components: [ComponentItem]?
}

// MARK: - Operations Service

@MainActor
class OperationsService: ObservableObject {
    static let shared = OperationsService()
    
    private let baseURL = "https://dashmet-rca-api.onrender.com/api"
    
    @Published var issues: [OperationsIssue] = []
    @Published var areas: [AreaItem] = []
    @Published var lines: [LineItem] = []
    @Published var equipment: [EquipmentItem] = []
    @Published var components: [ComponentItem] = []
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private init() {}
    
    // MARK: - Auth Helper
    private func authorizedRequest(url: URL, method: String = "GET") async throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = try? await FirebaseAuthService.shared.getIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
    
    // MARK: - Create Issue
    func createIssue(_ issueRequest: CreateIssueRequest) async -> Bool {
        isSubmitting = true
        errorMessage = nil
        successMessage = nil
        
        guard let url = URL(string: "\(baseURL)/operations/issues") else {
            errorMessage = "Invalid URL"
            isSubmitting = false
            return false
        }
        
        do {
            var request = try await authorizedRequest(url: url, method: "POST")
            request.httpBody = try JSONEncoder().encode(issueRequest)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                let result = try JSONDecoder().decode(CreateIssueResponse.self, from: data)
                if result.success, let newIssue = result.data {
                    issues.insert(newIssue, at: 0)
                    successMessage = result.message ?? "Issue reported successfully"
                    isSubmitting = false
                    return true
                }
            }
            
            // Try to parse error
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorJson["error"] as? String {
                errorMessage = message
            } else {
                errorMessage = "Failed to create issue (Status: \(httpResponse.statusCode))"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSubmitting = false
        return false
    }
    
    // MARK: - Fetch Issues
    func fetchIssues() async {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/operations/issues") else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        do {
            let request = try await authorizedRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            let result = try JSONDecoder().decode(IssuesListResponse.self, from: data)
            issues = result.data ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Fetch Areas (by departmentId)
    func fetchAreas(departmentId: String) async {
        guard let url = URL(string: "\(baseURL)/facilities/areas?departmentId=\(departmentId)") else { return }
        
        do {
            let request = try await authorizedRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
            
            let decoded = try JSONDecoder().decode(AreasResponse.self, from: data)
            areas = decoded.data?.areas ?? []
        } catch {
            print("OperationsService: Failed to fetch areas: \(error)")
        }
    }
    
    // MARK: - Fetch Lines (by areaId)
    func fetchLines(areaId: String) async {
        guard let url = URL(string: "\(baseURL)/facilities/lines?areaId=\(areaId)") else { return }
        
        do {
            let request = try await authorizedRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
            
            let decoded = try JSONDecoder().decode(LinesResponse.self, from: data)
            lines = decoded.data?.lines ?? []
        } catch {
            print("OperationsService: Failed to fetch lines: \(error)")
        }
    }
    
    // MARK: - Fetch Equipment (by lineId)
    func fetchEquipment(lineId: String) async {
        guard let url = URL(string: "\(baseURL)/equipment?lineId=\(lineId)") else { return }
        
        do {
            let request = try await authorizedRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
            
            let decoded = try JSONDecoder().decode(EquipmentResponse.self, from: data)
            equipment = decoded.data?.equipment ?? []
        } catch {
            print("OperationsService: Failed to fetch equipment: \(error)")
        }
    }
    
    // MARK: - Fetch Components (by equipmentId)
    func fetchComponents(equipmentId: String) async {
        guard let url = URL(string: "\(baseURL)/equipment/\(equipmentId)/components") else { return }
        
        do {
            let request = try await authorizedRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
            
            let decoded = try JSONDecoder().decode(ComponentsResponse.self, from: data)
            components = decoded.data?.components ?? []
        } catch {
            print("OperationsService: Failed to fetch components: \(error)")
        }
    }
    
    // MARK: - Reset cascading selections
    func resetCascade(from level: CascadeLevel) {
        switch level {
        case .department:
            areas = []; lines = []; equipment = []; components = []
        case .area:
            lines = []; equipment = []; components = []
        case .line:
            equipment = []; components = []
        case .equipment:
            components = []
        case .component:
            break
        }
    }
    
    enum CascadeLevel {
        case department, area, line, equipment, component
    }
}
