//
//  RecommendationService.swift
//  MeetingIntelligence
//
//  AI-Powered Decision Support Service
//  Phase 7: Decision Support - Generates action recommendations for supervisors
//

import Foundation
import SwiftUI

// MARK: - Recommendation Service
class RecommendationService {
    static let shared = RecommendationService()
    
    private let baseURL = "https://dashmet-rca-api.onrender.com/api/decision-support"
    
    private init() {}
    
    // MARK: - Get Recommendations
    
    /// Generates AI recommendations for case resolution
    /// - Parameters:
    ///   - conflictCase: The conflict case
    ///   - complaintA: First complaint document
    ///   - complaintAEmployee: Employee who filed complaint A
    ///   - complaintB: Second complaint document
    ///   - complaintBEmployee: Employee who filed complaint B
    ///   - analysisResult: Optional existing AI analysis result
    ///   - policyMatches: Optional policy matching results
    ///   - witnessStatements: Optional witness statements
    ///   - priorHistory: Optional prior history info
    /// - Returns: Recommendation result with options
    func getRecommendations(
        conflictCase: ConflictCase,
        complaintA: CaseDocument,
        complaintAEmployee: InvolvedEmployee,
        complaintB: CaseDocument,
        complaintBEmployee: InvolvedEmployee,
        analysisResult: AIComparisonResult? = nil,
        policyMatches: [PolicyMatchResult]? = nil,
        witnessStatements: [WitnessStatementInput] = [],
        priorHistory: PriorHistoryInfo? = nil
    ) async throws -> RecommendationResult {
        
        guard let url = URL(string: baseURL + "/recommendations") else {
            throw RecommendationError.invalidURL
        }
        
        // Build case details
        let caseDetails: [String: Any] = [
            "caseType": conflictCase.type.rawValue,
            "incidentDate": ISO8601DateFormatter().string(from: conflictCase.incidentDate),
            "location": conflictCase.location,
            "department": conflictCase.department
        ]
        
        // Build complaint A
        let complaintAData: [String: Any] = [
            "employeeName": complaintAEmployee.name,
            "text": complaintA.cleanedText
        ]
        
        // Build complaint B
        let complaintBData: [String: Any] = [
            "employeeName": complaintBEmployee.name,
            "text": complaintB.cleanedText
        ]
        
        // Build analysis result if available
        var analysisData: [String: Any]? = nil
        if let analysis = analysisResult {
            analysisData = [
                "contradictions": analysis.contradictions,
                "agreementPoints": analysis.agreementPoints,
                "neutralSummary": analysis.neutralSummary,
                "emotionalLanguage": analysis.emotionalLanguage
            ]
        }
        
        // Build policy matches if available
        var policyMatchData: [[String: Any]]? = nil
        if let matches = policyMatches, !matches.isEmpty {
            policyMatchData = matches.map { match in
                [
                    "sectionTitle": match.sectionTitle,
                    "relevanceExplanation": match.relevanceExplanation,
                    "matchConfidence": match.matchConfidence
                ]
            }
        }
        
        // Build witness statements
        let witnessData: [[String: String]] = witnessStatements.map { witness in
            [
                "witnessName": witness.witnessName,
                "text": witness.text
            ]
        }
        
        // Build prior history if available
        var historyData: [String: Any]? = nil
        if let history = priorHistory {
            historyData = [
                "hasPriorComplaints": history.hasPriorComplaints,
                "hasPriorCounseling": history.hasPriorCounseling,
                "hasPriorWarnings": history.hasPriorWarnings,
                "notes": history.notes ?? ""
            ]
        }
        
        // Build full request body
        var requestBody: [String: Any] = [
            "caseDetails": caseDetails,
            "complaintA": complaintAData,
            "complaintB": complaintBData
        ]
        
        if let analysis = analysisData {
            requestBody["analysisResult"] = analysis
        }
        
        if let policyMatches = policyMatchData {
            requestBody["policyMatches"] = policyMatches
        }
        
        if !witnessData.isEmpty {
            requestBody["witnessStatements"] = witnessData
        }
        
        if let history = historyData {
            requestBody["priorHistory"] = history
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 120 // 2 minutes for recommendation generation
        
        let startTime = Date()
        print("RecommendationService: Starting recommendation generation at \(startTime)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        let elapsed = Date().timeIntervalSince(startTime)
        print("RecommendationService: Response received in \(String(format: "%.1f", elapsed))s")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RecommendationError.invalidResponse
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RecommendationError.invalidResponse
        }
        
        // Check for error
        if httpResponse.statusCode != 200 {
            if let errorMessage = json["message"] as? String {
                throw RecommendationError.apiError(errorMessage)
            }
            if let errorMessage = json["error"] as? String {
                throw RecommendationError.apiError(errorMessage)
            }
            throw RecommendationError.apiError("Server error: HTTP \(httpResponse.statusCode)")
        }
        
        // Check success
        guard let success = json["success"] as? Bool, success,
              let resultData = json["data"] as? [String: Any] else {
            throw RecommendationError.parsingError
        }
        
        // Parse result with employee info for ID matching
        let employees = [complaintAEmployee, complaintBEmployee]
        return try parseRecommendationResult(resultData, employees: employees)
    }
    
    // MARK: - Parse Result
    
    private func parseRecommendationResult(_ data: [String: Any], employees: [InvolvedEmployee]) throws -> RecommendationResult {
        let recommendationsData = data["recommendations"] as? [[String: Any]] ?? []
        let primaryRecommendation = data["primaryRecommendation"] as? String ?? ""
        let supervisorGuidance = data["supervisorGuidance"] as? String ?? ""
        let generatedAt = data["generatedAt"] as? String ?? ISO8601DateFormatter().string(from: Date())
        
        // Parse per-employee recommendation groups
        let employeeRecommendationGroups: [EmployeeRecommendationGroup]
        if let empRecsData = data["employeeRecommendations"] as? [[String: Any]], !empRecsData.isEmpty {
            employeeRecommendationGroups = empRecsData.compactMap { groupData in
                guard let employeeName = groupData["employeeName"] as? String,
                      let recsData = groupData["recommendations"] as? [[String: Any]] else {
                    return nil
                }
                let assessment = groupData["assessment"] as? String ?? ""
                let groupPrimary = groupData["primaryRecommendation"] as? String ?? ""
                
                let recs: [RecommendationOption] = recsData.compactMap { recData in
                    self.parseRecommendationOption(recData, employees: employees)
                }
                
                guard !recs.isEmpty else { return nil }
                
                return EmployeeRecommendationGroup(
                    employeeName: employeeName,
                    assessment: assessment,
                    recommendations: recs,
                    primaryRecommendation: groupPrimary
                )
            }
        } else {
            employeeRecommendationGroups = []
        }
        
        // Parse flat recommendations (backward compat)
        let recommendations: [RecommendationOption] = recommendationsData.compactMap { recData in
            self.parseRecommendationOption(recData, employees: employees)
        }
        
        return RecommendationResult(
            recommendations: recommendations,
            employeeRecommendations: employeeRecommendationGroups,
            primaryRecommendationId: primaryRecommendation,
            supervisorGuidance: supervisorGuidance,
            generatedAt: ISO8601DateFormatter().date(from: generatedAt) ?? Date()
        )
    }
    
    /// Parse a single recommendation option from JSON
    private func parseRecommendationOption(_ recData: [String: Any], employees: [InvolvedEmployee]) -> RecommendationOption? {
        guard let id = recData["id"] as? String,
              let typeString = recData["type"] as? String,
              let title = recData["title"] as? String,
              let description = recData["description"] as? String,
              let rationale = recData["rationale"] as? String,
              let riskLevelString = recData["riskLevel"] as? String,
              let riskExplanation = recData["riskExplanation"] as? String,
              let nextSteps = recData["nextSteps"] as? [String],
              let timeframe = recData["timeframe"] as? String,
              let confidence = recData["confidence"] as? Double else {
            return nil
        }
        
        guard let type = RecommendationType(fromAPI: typeString) else {
            print("[RecommendationService] Warning: Skipping recommendation with unrecognized type: \(typeString)")
            return nil
        }
        
        guard let riskLevel = RiskLevel(fromAPI: riskLevelString) else {
            print("[RecommendationService] Warning: Skipping recommendation with unrecognized risk level: \(riskLevelString)")
            return nil
        }
        
        let targetEmployeeNames = recData["targetEmployeeNames"] as? [String] ?? []
        let targetEmployeeIds: [UUID] = matchEmployeeNamesToIds(names: targetEmployeeNames, employees: employees)
        
        return RecommendationOption(
            id: id,
            type: type,
            title: title,
            description: description,
            rationale: rationale,
            riskLevel: riskLevel,
            riskExplanation: riskExplanation,
            nextSteps: nextSteps,
            timeframe: timeframe,
            confidence: confidence,
            targetEmployeeIds: targetEmployeeIds
        )
    }
    
    // MARK: - Match Employee Names to IDs
    
    /// Matches employee names from AI response to actual employee IDs
    /// Uses fuzzy matching to handle slight variations in names
    private func matchEmployeeNamesToIds(names: [String], employees: [InvolvedEmployee]) -> [UUID] {
        var matchedIds: [UUID] = []
        
        for name in names {
            let normalizedName = name.lowercased().trimmingCharacters(in: .whitespaces)
            
            // Try exact match first
            if let employee = employees.first(where: { $0.name.lowercased() == normalizedName }) {
                if !matchedIds.contains(employee.id) {
                    matchedIds.append(employee.id)
                }
                continue
            }
            
            // Try partial match (name contains or is contained)
            if let employee = employees.first(where: { 
                $0.name.lowercased().contains(normalizedName) || 
                normalizedName.contains($0.name.lowercased())
            }) {
                if !matchedIds.contains(employee.id) {
                    matchedIds.append(employee.id)
                }
                continue
            }
            
            // Try matching individual name parts (first name or last name)
            let nameParts = normalizedName.split(separator: " ").map { String($0) }
            for part in nameParts where part.count >= 3 {
                if let employee = employees.first(where: { 
                    $0.name.lowercased().contains(part) 
                }) {
                    if !matchedIds.contains(employee.id) {
                        matchedIds.append(employee.id)
                    }
                    break
                }
            }
        }
        
        // If no matches found, return all employees (fallback)
        if matchedIds.isEmpty {
            matchedIds = employees.map { $0.id }
        }
        
        return matchedIds
    }
}

// MARK: - Recommendation Errors

enum RecommendationError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case parsingError
    case apiError(String)
    case insufficientData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .parsingError:
            return "Failed to parse recommendations"
        case .apiError(let message):
            return message
        case .insufficientData:
            return "Insufficient case data to generate recommendations"
        }
    }
}

// MARK: - Recommendation Models

/// Prior history information for the case
struct PriorHistoryInfo {
    let hasPriorComplaints: Bool
    let hasPriorCounseling: Bool
    let hasPriorWarnings: Bool
    let notes: String?
    
    init(hasPriorComplaints: Bool = false, hasPriorCounseling: Bool = false, hasPriorWarnings: Bool = false, notes: String? = nil) {
        self.hasPriorComplaints = hasPriorComplaints
        self.hasPriorCounseling = hasPriorCounseling
        self.hasPriorWarnings = hasPriorWarnings
        self.notes = notes
    }
}

/// Per-employee recommendation group
struct EmployeeRecommendationGroup: Codable, Identifiable {
    var id: String { employeeName }
    let employeeName: String
    let assessment: String
    let recommendations: [RecommendationOption]
    let primaryRecommendation: String
}

/// Result containing all recommendations
struct RecommendationResult: Codable {
    let recommendations: [RecommendationOption]
    let employeeRecommendations: [EmployeeRecommendationGroup]
    let primaryRecommendationId: String
    let supervisorGuidance: String
    let generatedAt: Date
    
    var hasRecommendations: Bool {
        !recommendations.isEmpty || !employeeRecommendations.isEmpty
    }
    
    var primaryRecommendation: RecommendationOption? {
        recommendations.first { $0.id == primaryRecommendationId }
    }
    
    // Custom decoder to handle backward compat (old data without employeeRecommendations)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recommendations = try container.decode([RecommendationOption].self, forKey: .recommendations)
        employeeRecommendations = try container.decodeIfPresent([EmployeeRecommendationGroup].self, forKey: .employeeRecommendations) ?? []
        primaryRecommendationId = try container.decode(String.self, forKey: .primaryRecommendationId)
        supervisorGuidance = try container.decode(String.self, forKey: .supervisorGuidance)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
    }
    
    init(recommendations: [RecommendationOption], employeeRecommendations: [EmployeeRecommendationGroup] = [], primaryRecommendationId: String, supervisorGuidance: String, generatedAt: Date) {
        self.recommendations = recommendations
        self.employeeRecommendations = employeeRecommendations
        self.primaryRecommendationId = primaryRecommendationId
        self.supervisorGuidance = supervisorGuidance
        self.generatedAt = generatedAt
    }
}

/// Types of recommended actions
enum RecommendationType: String, CaseIterable, Codable {
    case coaching = "coaching"
    case counseling = "counseling"
    case warning = "warning"
    case escalate = "escalate"
    
    /// Initialize from API response string, handling various formats
    init?(fromAPI string: String) {
        let normalized = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Direct match
        if let type = RecommendationType(rawValue: normalized) {
            self = type
            return
        }
        
        // Handle common variations
        switch normalized {
        case "written warning", "writtenwarning", "written_warning":
            self = .warning
        case "documented counseling", "documentedcounseling", "documented_counseling":
            self = .counseling
        case "escalate to hr", "escalatetohr", "escalate_to_hr", "hr escalation", "hrescalation":
            self = .escalate
        case "coaching session", "coachingsession", "coaching_session":
            self = .coaching
        default:
            // Check if any keyword is contained
            if normalized.contains("warning") {
                self = .warning
            } else if normalized.contains("counsel") {
                self = .counseling
            } else if normalized.contains("escalat") || normalized.contains("hr") {
                self = .escalate
            } else if normalized.contains("coach") {
                self = .coaching
            } else {
                return nil
            }
        }
    }
    
    var displayName: String {
        switch self {
        case .coaching: return "Coaching"
        case .counseling: return "Documented Counseling"
        case .warning: return "Written Warning"
        case .escalate: return "Escalate to HR"
        }
    }
    
    var icon: String {
        switch self {
        case .coaching: return "message.badge.fill"
        case .counseling: return "doc.text.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .escalate: return "arrow.up.forward.square.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .coaching: return .green
        case .counseling: return .blue
        case .warning: return .orange
        case .escalate: return .red
        }
    }
}

/// Risk levels for recommendations
enum RiskLevel: String, CaseIterable, Codable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case critical = "critical"
    
    /// Initialize from API response string, handling various formats
    init?(fromAPI string: String) {
        let normalized = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Direct match
        if let level = RiskLevel(rawValue: normalized) {
            self = level
            return
        }
        
        // Handle common variations
        switch normalized {
        case "low risk", "lowrisk", "low_risk", "minimal", "minor":
            self = .low
        case "moderate risk", "moderaterisk", "moderate_risk", "medium", "medium risk":
            self = .moderate
        case "high risk", "highrisk", "high_risk", "elevated", "significant":
            self = .high
        case "critical risk", "criticalrisk", "critical_risk", "severe", "extreme":
            self = .critical
        default:
            // Check if any keyword is contained
            if normalized.contains("critical") || normalized.contains("severe") || normalized.contains("extreme") {
                self = .critical
            } else if normalized.contains("high") || normalized.contains("elevated") || normalized.contains("significant") {
                self = .high
            } else if normalized.contains("moderate") || normalized.contains("medium") {
                self = .moderate
            } else if normalized.contains("low") || normalized.contains("minimal") || normalized.contains("minor") {
                self = .low
            } else {
                return nil
            }
        }
    }
    
    var displayName: String {
        switch self {
        case .low: return "Low Risk"
        case .moderate: return "Moderate Risk"
        case .high: return "High Risk"
        case .critical: return "Critical Risk"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

/// Individual recommendation option
struct RecommendationOption: Identifiable, Codable {
    let id: String
    let type: RecommendationType
    let title: String
    let description: String
    let rationale: String
    let riskLevel: RiskLevel
    let riskExplanation: String
    let nextSteps: [String]
    let timeframe: String
    let confidence: Double
    let targetEmployeeIds: [UUID]  // Which employees this recommendation applies to
    
    /// User-friendly confidence label
    var confidenceLabel: String {
        if confidence >= 0.8 {
            return "High Confidence"
        } else if confidence >= 0.6 {
            return "Moderate Confidence"
        } else {
            return "Lower Confidence"
        }
    }
    
    /// Option letter (A, B, C, D)
    var optionLetter: String {
        switch id {
        case "option_a": return "A"
        case "option_b": return "B"
        case "option_c": return "C"
        case "option_d": return "D"
        default: return "?"
        }
    }
}
