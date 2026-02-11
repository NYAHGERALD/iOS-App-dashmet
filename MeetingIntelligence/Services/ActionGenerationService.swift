//
//  ActionGenerationService.swift
//  MeetingIntelligence
//
//  AI-Powered Action Document Generation Service
//  Phase 8: Action Generation - Creates documents based on selected recommendation
//

import Foundation

// MARK: - Action Generation Service
class ActionGenerationService {
    static let shared = ActionGenerationService()
    
    private let baseURL = "https://dashmet-rca-api.onrender.com/api/action-generation"
    
    private init() {}
    
    // MARK: - Generate Action Document
    
    /// Generates a document based on the selected action type
    /// - Parameters:
    ///   - actionType: Type of action (coaching, counseling, warning, escalate)
    ///   - conflictCase: The conflict case
    ///   - complaintA: First complaint document
    ///   - complaintAEmployee: Employee who filed complaint A
    ///   - complaintB: Second complaint document
    ///   - complaintBEmployee: Employee who filed complaint B
    ///   - analysisResult: Optional AI analysis result
    ///   - policyMatches: Optional policy matching results
    ///   - recommendationRationale: Optional rationale from recommendation
    ///   - supervisorName: Optional supervisor name
    /// - Returns: Generated document result
    func generateDocument(
        actionType: ActionType,
        conflictCase: ConflictCase,
        complaintA: CaseDocument,
        complaintAEmployee: InvolvedEmployee,
        complaintB: CaseDocument,
        complaintBEmployee: InvolvedEmployee,
        analysisResult: AIComparisonResult? = nil,
        policyMatches: [PolicyMatchResult]? = nil,
        recommendationRationale: String? = nil,
        supervisorName: String? = nil
    ) async throws -> GeneratedDocumentResult {
        
        guard let url = URL(string: baseURL + "/generate") else {
            throw ActionGenerationError.invalidURL
        }
        
        // Build case details
        let caseDetails: [String: Any] = [
            "caseNumber": conflictCase.caseNumber,
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
                "neutralSummary": analysis.neutralSummary
            ]
        }
        
        // Build policy matches if available
        var policyMatchData: [[String: Any]]? = nil
        if let matches = policyMatches, !matches.isEmpty {
            policyMatchData = matches.map { match in
                [
                    "sectionNumber": match.sectionNumber,
                    "sectionTitle": match.sectionTitle,
                    "relevanceExplanation": match.relevanceExplanation
                ]
            }
        }
        
        // Build full request body
        var requestBody: [String: Any] = [
            "actionType": actionType.rawValue,
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
        
        if let rationale = recommendationRationale {
            requestBody["recommendationRationale"] = rationale
        }
        
        if let supervisor = supervisorName {
            requestBody["supervisorName"] = supervisor
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 120 // 2 minutes for document generation
        
        print("ActionGenerationService: Generating \(actionType.rawValue) document...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ActionGenerationError.invalidResponse
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ActionGenerationError.invalidResponse
        }
        
        // Check for error
        if httpResponse.statusCode != 200 {
            if let errorMessage = json["message"] as? String {
                throw ActionGenerationError.apiError(errorMessage)
            }
            if let errorMessage = json["error"] as? String {
                throw ActionGenerationError.apiError(errorMessage)
            }
            throw ActionGenerationError.apiError("Server error: HTTP \(httpResponse.statusCode)")
        }
        
        // Check success
        guard let success = json["success"] as? Bool, success,
              let resultData = json["data"] as? [String: Any] else {
            throw ActionGenerationError.parsingError
        }
        
        // Parse result based on action type
        return try parseGeneratedDocument(resultData, actionType: actionType)
    }
    
    // MARK: - Parse Result
    
    private func parseGeneratedDocument(_ data: [String: Any], actionType: ActionType) throws -> GeneratedDocumentResult {
        guard let documentData = data["document"] as? [String: Any] else {
            throw ActionGenerationError.parsingError
        }
        
        let generatedAt = data["generatedAt"] as? String ?? ISO8601DateFormatter().string(from: Date())
        let isEditable = data["isEditable"] as? Bool ?? true
        
        var document: GeneratedDocument
        
        switch actionType {
        case .coaching:
            document = try parseCoachingDocument(documentData)
        case .counseling:
            document = try parseCounselingDocument(documentData)
        case .warning:
            document = try parseWarningDocument(documentData)
        case .escalate:
            document = try parseEscalationDocument(documentData)
        }
        
        return GeneratedDocumentResult(
            actionType: actionType,
            document: document,
            generatedAt: ISO8601DateFormatter().date(from: generatedAt) ?? Date(),
            isEditable: isEditable
        )
    }
    
    private func parseCoachingDocument(_ data: [String: Any]) throws -> GeneratedDocument {
        let title = data["title"] as? String ?? "Coaching Session Guide"
        let overview = data["overview"] as? String ?? ""
        
        let discussionOutline = data["discussionOutline"] as? [String: Any]
        let opening = discussionOutline?["opening"] as? String ?? ""
        let keyPoints = discussionOutline?["keyPoints"] as? [String] ?? []
        let transitionStatements = discussionOutline?["transitionStatements"] as? [String] ?? []
        
        let talkingPoints = data["talkingPoints"] as? [String] ?? []
        let questionsToAsk = data["questionsToAsk"] as? [String] ?? []
        
        let behavioralAreas = (data["behavioralFocusAreas"] as? [[String: Any]] ?? []).map { area in
            BehavioralFocusArea(
                area: area["area"] as? String ?? "",
                description: area["description"] as? String ?? "",
                expectedChange: area["expectedChange"] as? String ?? ""
            )
        }
        
        let followUpPlan = data["followUpPlan"] as? [String: Any]
        let timeline = followUpPlan?["timeline"] as? String ?? ""
        let checkInDates = followUpPlan?["checkInDates"] as? [String] ?? []
        let successIndicators = followUpPlan?["successIndicators"] as? [String] ?? []
        
        return .coaching(CoachingDocument(
            title: title,
            overview: overview,
            discussionOutline: DiscussionOutline(
                opening: opening,
                keyPoints: keyPoints,
                transitionStatements: transitionStatements
            ),
            talkingPoints: talkingPoints,
            questionsToAsk: questionsToAsk,
            behavioralFocusAreas: behavioralAreas,
            followUpPlan: FollowUpPlan(
                timeline: timeline,
                checkInDates: checkInDates,
                successIndicators: successIndicators
            )
        ))
    }
    
    private func parseCounselingDocument(_ data: [String: Any]) throws -> GeneratedDocument {
        let title = data["title"] as? String ?? "Employee Counseling Documentation"
        let documentDate = data["documentDate"] as? String ?? ""
        let employeeNames = data["employeeNames"] as? [String] ?? []
        let incidentSummary = data["incidentSummary"] as? String ?? ""
        let discussionPoints = data["discussionPoints"] as? [String] ?? []
        let expectations = data["expectations"] as? [String] ?? []
        let policyReferences = data["policyReferences"] as? [String] ?? []
        
        let improvementPlanData = data["improvementPlan"] as? [String: Any]
        let goals = improvementPlanData?["goals"] as? [String] ?? []
        let planTimeline = improvementPlanData?["timeline"] as? String ?? ""
        let supportProvided = improvementPlanData?["supportProvided"] as? [String] ?? []
        
        let consequences = data["consequences"] as? String ?? ""
        let acknowledgmentSection = data["acknowledgmentSection"] as? String ?? ""
        
        return .counseling(CounselingDocument(
            title: title,
            documentDate: documentDate,
            employeeNames: employeeNames,
            incidentSummary: incidentSummary,
            discussionPoints: discussionPoints,
            expectations: expectations,
            policyReferences: policyReferences,
            improvementPlan: ImprovementPlan(
                goals: goals,
                timeline: planTimeline,
                supportProvided: supportProvided
            ),
            consequences: consequences,
            acknowledgmentSection: acknowledgmentSection
        ))
    }
    
    private func parseWarningDocument(_ data: [String: Any]) throws -> GeneratedDocument {
        let title = data["title"] as? String ?? "Written Warning Notice"
        let documentDate = data["documentDate"] as? String ?? ""
        let employeeNames = data["employeeNames"] as? [String] ?? []
        let warningLevel = data["warningLevel"] as? String ?? ""
        let companyRulesViolated = data["companyRulesViolated"] as? [String] ?? []
        let describeInDetail = data["describeInDetail"] as? String ?? ""
        let conductDeficiency = data["conductDeficiency"] as? String ?? ""
        let requiredCorrectiveAction = data["requiredCorrectiveAction"] as? [String] ?? []
        let consequencesOfNotPerforming = data["consequencesOfNotPerforming"] as? String ?? ""
        let reviewDate = data["reviewDate"] as? String ?? ""
        let priorActions = data["priorActions"] as? String ?? ""
        
        let signatureSectionData = data["signatureSection"] as? [String: Any]
        let employeeAck = signatureSectionData?["employeeAcknowledgment"] as? String ?? ""
        let supervisorStmt = signatureSectionData?["supervisorStatement"] as? String ?? ""
        let hrReviewStmt = signatureSectionData?["hrReviewStatement"] as? String ?? ""
        
        return .warning(WarningDocument(
            title: title,
            documentDate: documentDate,
            employeeNames: employeeNames,
            warningLevel: warningLevel,
            companyRulesViolated: companyRulesViolated,
            describeInDetail: describeInDetail,
            conductDeficiency: conductDeficiency,
            requiredCorrectiveAction: requiredCorrectiveAction,
            consequencesOfNotPerforming: consequencesOfNotPerforming,
            reviewDate: reviewDate,
            priorActions: priorActions,
            signatureSection: SignatureSection(
                employeeAcknowledgment: employeeAck,
                supervisorStatement: supervisorStmt,
                hrReviewStatement: hrReviewStmt
            )
        ))
    }
    
    private func parseEscalationDocument(_ data: [String: Any]) throws -> GeneratedDocument {
        let title = data["title"] as? String ?? "HR Escalation Request"
        let documentDate = data["documentDate"] as? String ?? ""
        let preparedBy = data["preparedBy"] as? String ?? ""
        
        let caseSummaryData = data["caseSummary"] as? [String: Any]
        let caseSummary = CaseSummary(
            caseNumber: caseSummaryData?["caseNumber"] as? String ?? "",
            caseType: caseSummaryData?["caseType"] as? String ?? "",
            incidentDate: caseSummaryData?["incidentDate"] as? String ?? "",
            location: caseSummaryData?["location"] as? String ?? "",
            department: caseSummaryData?["department"] as? String ?? ""
        )
        
        let involvedParties = (data["involvedParties"] as? [[String: Any]] ?? []).map { party in
            InvolvedParty(
                name: party["name"] as? String ?? "",
                role: party["role"] as? String ?? "",
                summary: party["summary"] as? String ?? ""
            )
        }
        
        let timeline = (data["incidentTimeline"] as? [[String: Any]] ?? []).map { event in
            TimelineEvent(
                date: event["date"] as? String ?? "",
                event: event["event"] as? String ?? ""
            )
        }
        
        let evidenceSummary = data["evidenceSummary"] as? [String] ?? []
        
        let policyRefs = (data["policyReferences"] as? [[String: Any]] ?? []).map { ref in
            PolicyReference(
                section: ref["section"] as? String ?? "",
                relevance: ref["relevance"] as? String ?? ""
            )
        }
        
        let analysisFindings = data["analysisFindings"] as? [String] ?? []
        let supervisorNotes = data["supervisorNotes"] as? String ?? ""
        let recommendedActions = data["recommendedActions"] as? [String] ?? []
        let urgencyLevel = data["urgencyLevel"] as? String ?? ""
        let requestedHRActions = data["requestedHRActions"] as? [String] ?? []
        
        return .escalation(EscalationDocument(
            title: title,
            documentDate: documentDate,
            preparedBy: preparedBy,
            caseSummary: caseSummary,
            involvedParties: involvedParties,
            incidentTimeline: timeline,
            evidenceSummary: evidenceSummary,
            policyReferences: policyRefs,
            analysisFindings: analysisFindings,
            supervisorNotes: supervisorNotes,
            recommendedActions: recommendedActions,
            urgencyLevel: urgencyLevel,
            requestedHRActions: requestedHRActions
        ))
    }
}

// MARK: - Action Generation Errors

enum ActionGenerationError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case parsingError
    case apiError(String)
    case invalidActionType
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .parsingError:
            return "Failed to parse generated document"
        case .apiError(let message):
            return message
        case .invalidActionType:
            return "Invalid action type specified"
        }
    }
}

// MARK: - Action Types

enum ActionType: String, CaseIterable {
    case coaching = "coaching"
    case counseling = "counseling"
    case warning = "warning"
    case escalate = "escalate"
    
    var displayName: String {
        switch self {
        case .coaching: return "Coaching Session"
        case .counseling: return "Documented Counseling"
        case .warning: return "Written Warning"
        case .escalate: return "HR Escalation"
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
}

// MARK: - Generated Document Result

struct GeneratedDocumentResult {
    let actionType: ActionType
    let document: GeneratedDocument
    let generatedAt: Date
    let isEditable: Bool
}

// MARK: - Generated Document Enum

enum GeneratedDocument {
    case coaching(CoachingDocument)
    case counseling(CounselingDocument)
    case warning(WarningDocument)
    case escalation(EscalationDocument)
    
    var title: String {
        switch self {
        case .coaching(let doc): return doc.title
        case .counseling(let doc): return doc.title
        case .warning(let doc): return doc.title
        case .escalation(let doc): return doc.title
        }
    }
}

// MARK: - Coaching Document

struct CoachingDocument {
    let title: String
    let overview: String
    let discussionOutline: DiscussionOutline
    let talkingPoints: [String]
    let questionsToAsk: [String]
    let behavioralFocusAreas: [BehavioralFocusArea]
    let followUpPlan: FollowUpPlan
}

struct DiscussionOutline {
    let opening: String
    let keyPoints: [String]
    let transitionStatements: [String]
}

struct BehavioralFocusArea {
    let area: String
    let description: String
    let expectedChange: String
}

struct FollowUpPlan {
    let timeline: String
    let checkInDates: [String]
    let successIndicators: [String]
}

// MARK: - Counseling Document

struct CounselingDocument {
    let title: String
    let documentDate: String
    let employeeNames: [String]
    let incidentSummary: String
    let discussionPoints: [String]
    let expectations: [String]
    let policyReferences: [String]
    let improvementPlan: ImprovementPlan
    let consequences: String
    let acknowledgmentSection: String
}

struct ImprovementPlan {
    let goals: [String]
    let timeline: String
    let supportProvided: [String]
}

// MARK: - Warning Document

struct WarningDocument {
    let title: String
    let documentDate: String
    let employeeNames: [String]
    let warningLevel: String
    let companyRulesViolated: [String]
    let describeInDetail: String
    let conductDeficiency: String
    let requiredCorrectiveAction: [String]
    let consequencesOfNotPerforming: String
    let reviewDate: String
    let priorActions: String
    let signatureSection: SignatureSection
}

struct SignatureSection {
    let employeeAcknowledgment: String
    let supervisorStatement: String
    let hrReviewStatement: String
}

// MARK: - Escalation Document

struct EscalationDocument {
    let title: String
    let documentDate: String
    let preparedBy: String
    let caseSummary: CaseSummary
    let involvedParties: [InvolvedParty]
    let incidentTimeline: [TimelineEvent]
    let evidenceSummary: [String]
    let policyReferences: [PolicyReference]
    let analysisFindings: [String]
    let supervisorNotes: String
    let recommendedActions: [String]
    let urgencyLevel: String
    let requestedHRActions: [String]
}

struct CaseSummary {
    let caseNumber: String
    let caseType: String
    let incidentDate: String
    let location: String
    let department: String
}

struct InvolvedParty {
    let name: String
    let role: String
    let summary: String
}

struct TimelineEvent {
    let date: String
    let event: String
}

struct PolicyReference {
    let section: String
    let relevance: String
}
