//
//  ConflictCase.swift
//  MeetingIntelligence
//
//  Models for the Policy-Aware Conflict Resolution Assistant
//

import Foundation
import SwiftUI

// MARK: - Case Type
enum CaseType: String, Codable, CaseIterable, Identifiable {
    case conflict = "CONFLICT"
    case conduct = "CONDUCT"
    case safety = "SAFETY"
    case other = "OTHER"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .conflict: return "Conflict"
        case .conduct: return "Conduct"
        case .safety: return "Safety"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .conflict: return "person.2.fill"
        case .conduct: return "exclamationmark.triangle.fill"
        case .safety: return "shield.fill"
        case .other: return "folder.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .conflict: return Color(hex: "F59E0B")  // Amber
        case .conduct: return Color(hex: "EF4444")   // Red
        case .safety: return Color(hex: "3B82F6")    // Blue
        case .other: return Color(hex: "6B7280")     // Gray
        }
    }
}

// MARK: - Case Status
enum CaseStatus: String, Codable, CaseIterable {
    case draft = "DRAFT"
    case inProgress = "IN_PROGRESS"
    case pendingReview = "PENDING_REVIEW"
    case awaitingAction = "AWAITING_ACTION"
    case closed = "CLOSED"
    case escalated = "ESCALATED"
    
    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .inProgress: return "In Progress"
        case .pendingReview: return "Pending Review"
        case .awaitingAction: return "Awaiting Action"
        case .closed: return "Closed"
        case .escalated: return "Escalated to HR"
        }
    }
    
    var icon: String {
        switch self {
        case .draft: return "doc.badge.clock"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .pendingReview: return "eye"
        case .awaitingAction: return "clock.badge.exclamationmark"
        case .closed: return "checkmark.seal.fill"
        case .escalated: return "arrow.up.forward.square"
        }
    }
    
    var color: Color {
        switch self {
        case .draft: return Color(hex: "6B7280")
        case .inProgress: return Color(hex: "3B82F6")
        case .pendingReview: return Color(hex: "F59E0B")
        case .awaitingAction: return Color(hex: "8B5CF6")
        case .closed: return Color(hex: "10B981")
        case .escalated: return Color(hex: "EF4444")
        }
    }
}

// MARK: - Document Type
enum CaseDocumentType: String, Codable, CaseIterable {
    case complaintA = "COMPLAINT_A"
    case complaintB = "COMPLAINT_B"
    case witnessStatement = "WITNESS_STATEMENT"
    case priorRecord = "PRIOR_RECORD"
    case counselingRecord = "COUNSELING_RECORD"
    case warningDocument = "WARNING_DOCUMENT"
    case evidence = "EVIDENCE"
    case other = "OTHER"
    
    var displayName: String {
        switch self {
        case .complaintA: return "Complaint A"
        case .complaintB: return "Complaint B"
        case .witnessStatement: return "Witness Statement"
        case .priorRecord: return "Prior Record"
        case .counselingRecord: return "Counseling Record"
        case .warningDocument: return "Warning Document"
        case .evidence: return "Evidence"
        case .other: return "Other Document"
        }
    }
    
    var icon: String {
        switch self {
        case .complaintA, .complaintB: return "doc.text.fill"
        case .witnessStatement: return "person.text.rectangle.fill"
        case .priorRecord: return "clock.arrow.circlepath"
        case .counselingRecord: return "text.bubble.fill"
        case .warningDocument: return "exclamationmark.triangle.fill"
        case .evidence: return "photo.fill"
        case .other: return "doc.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .complaintA: return Color(hex: "3B82F6")     // Blue
        case .complaintB: return Color(hex: "8B5CF6")     // Purple
        case .witnessStatement: return Color(hex: "10B981") // Green
        case .priorRecord: return Color(hex: "F59E0B")    // Amber
        case .counselingRecord: return Color(hex: "EC4899") // Pink
        case .warningDocument: return Color(hex: "EF4444") // Red
        case .evidence: return Color(hex: "6366F1")       // Indigo
        case .other: return Color(hex: "6B7280")          // Gray
        }
    }
}

// MARK: - Recommended Action
enum RecommendedAction: String, Codable, CaseIterable, Identifiable {
    case coaching = "COACHING"
    case counseling = "COUNSELING"
    case writtenWarning = "WRITTEN_WARNING"
    case escalateToHR = "ESCALATE_TO_HR"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .coaching: return "Coaching Recommended"
        case .counseling: return "Documented Counseling"
        case .writtenWarning: return "Written Warning"
        case .escalateToHR: return "Escalate to HR"
        }
    }
    
    var description: String {
        switch self {
        case .coaching:
            return "Informal discussion to address behavior and set expectations"
        case .counseling:
            return "Formal documented conversation with clear expectations and follow-up"
        case .writtenWarning:
            return "Official written warning with policy references and consequences"
        case .escalateToHR:
            return "Escalate case to Human Resources for further investigation"
        }
    }
    
    var icon: String {
        switch self {
        case .coaching: return "person.fill.questionmark"
        case .counseling: return "doc.text.fill"
        case .writtenWarning: return "exclamationmark.triangle.fill"
        case .escalateToHR: return "arrow.up.forward.square.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .coaching: return Color(hex: "10B981")      // Green
        case .counseling: return Color(hex: "F59E0B")    // Amber
        case .writtenWarning: return Color(hex: "EF4444") // Red
        case .escalateToHR: return Color(hex: "8B5CF6")   // Purple
        }
    }
    
    var riskLevel: String {
        switch self {
        case .coaching: return "Low"
        case .counseling: return "Medium"
        case .writtenWarning: return "High"
        case .escalateToHR: return "Critical"
        }
    }
}

// MARK: - Involved Employee
struct InvolvedEmployee: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var role: String
    var department: String
    var employeeId: String?
    var isComplainant: Bool
    
    init(id: UUID = UUID(), name: String, role: String = "", department: String = "", employeeId: String? = nil, isComplainant: Bool = false) {
        self.id = id
        self.name = name
        self.role = role
        self.department = department
        self.employeeId = employeeId
        self.isComplainant = isComplainant
    }
}

// MARK: - Case Document
struct CaseDocument: Identifiable, Codable {
    let id: UUID
    var type: CaseDocumentType
    var originalImageURLs: [String]   // Original scanned images URLs
    var processedImageURLs: [String]  // Processed/enhanced images URLs
    var originalImageBase64: String?  // Original image as base64 (for local storage)
    var processedImageBase64: String? // Processed image as base64 (for local storage)
    var originalText: String          // Raw OCR text
    var translatedText: String?       // Translated text (if needed)
    var cleanedText: String           // Cleaned & structured text
    var detectedLanguage: String?
    var isHandwritten: Bool?
    var employeeId: UUID?             // Associated employee (if witness statement)
    var submittedBy: String?          // Name of person who submitted
    var createdAt: Date
    var pageCount: Int
    
    // MARK: - Audit Log Fields (Employee Review & Signature Workflow)
    var signatureImageBase64: String?           // Employee digital signature as PNG
    var employeeReviewTimestamp: Date?          // When employee confirmed review
    var employeeSignatureTimestamp: Date?       // When employee signed
    var supervisorCertificationTimestamp: Date? // When supervisor certified
    var supervisorId: String?                   // Supervisor's employee ID
    var supervisorName: String?                 // Supervisor's name
    var submittedById: String?                  // Employee's ID who submitted
    var deviceId: String?                       // Device identifier
    var appVersion: String?                     // App version
    var versionHash: String?                    // Hash for document integrity verification
    
    init(
        id: UUID = UUID(),
        type: CaseDocumentType,
        originalImageURLs: [String] = [],
        processedImageURLs: [String] = [],
        originalText: String = "",
        translatedText: String? = nil,
        cleanedText: String = "",
        originalImageBase64: String? = nil,
        processedImageBase64: String? = nil,
        detectedLanguage: String? = nil,
        isHandwritten: Bool? = nil,
        employeeId: UUID? = nil,
        submittedBy: String? = nil,
        createdAt: Date = Date(),
        pageCount: Int = 1,
        // Audit log fields
        signatureImageBase64: String? = nil,
        employeeReviewTimestamp: Date? = nil,
        employeeSignatureTimestamp: Date? = nil,
        supervisorCertificationTimestamp: Date? = nil,
        supervisorId: String? = nil,
        supervisorName: String? = nil,
        submittedById: String? = nil,
        deviceId: String? = nil,
        appVersion: String? = nil,
        versionHash: String? = nil
    ) {
        self.id = id
        self.type = type
        self.originalImageURLs = originalImageURLs
        self.processedImageURLs = processedImageURLs
        self.originalText = originalText
        self.translatedText = translatedText
        self.cleanedText = cleanedText
        self.originalImageBase64 = originalImageBase64
        self.processedImageBase64 = processedImageBase64
        self.detectedLanguage = detectedLanguage
        self.isHandwritten = isHandwritten
        self.employeeId = employeeId
        self.submittedBy = submittedBy
        self.createdAt = createdAt
        self.pageCount = pageCount
        // Audit log fields
        self.signatureImageBase64 = signatureImageBase64
        self.employeeReviewTimestamp = employeeReviewTimestamp
        self.employeeSignatureTimestamp = employeeSignatureTimestamp
        self.supervisorCertificationTimestamp = supervisorCertificationTimestamp
        self.supervisorId = supervisorId
        self.supervisorName = supervisorName
        self.submittedById = submittedById
        self.deviceId = deviceId
        self.appVersion = appVersion
        self.versionHash = versionHash
    }
}

// MARK: - Side-by-Side Comparison Item
struct SideBySideComparisonItem: Identifiable, Codable {
    let id: UUID
    var topic: String
    var partyAVersion: String
    var partyBVersion: String
    var status: ComparisonStatus
    
    init(id: UUID = UUID(), topic: String, partyAVersion: String, partyBVersion: String, status: ComparisonStatus) {
        self.id = id
        self.topic = topic
        self.partyAVersion = partyAVersion
        self.partyBVersion = partyBVersion
        self.status = status
    }
}

enum ComparisonStatus: String, Codable {
    case agreement = "agreement"
    case contradiction = "contradiction"
    case partial = "partial"
    case unclear = "unclear"
    
    var displayName: String {
        switch self {
        case .agreement: return "Agreement"
        case .contradiction: return "Contradiction"
        case .partial: return "Partial Agreement"
        case .unclear: return "Unclear"
        }
    }
    
    var color: Color {
        switch self {
        case .agreement: return Color(hex: "10B981")     // Green
        case .contradiction: return Color(hex: "EF4444") // Red
        case .partial: return Color(hex: "F59E0B")       // Amber
        case .unclear: return Color(hex: "6B7280")       // Gray
        }
    }
    
    var icon: String {
        switch self {
        case .agreement: return "checkmark.circle.fill"
        case .contradiction: return "xmark.circle.fill"
        case .partial: return "exclamationmark.circle.fill"
        case .unclear: return "questionmark.circle.fill"
        }
    }
}

// MARK: - AI Comparison Result
struct AIComparisonResult: Codable {
    var timelineDifferences: [String]
    var agreementPoints: [String]
    var contradictions: [String]
    var emotionalLanguage: [String]
    var missingDetails: [String]
    var neutralSummary: String
    var sideBySideComparison: [SideBySideComparisonItem]
    var partyAName: String
    var partyBName: String
    var generatedAt: Date
    
    init(
        timelineDifferences: [String] = [],
        agreementPoints: [String] = [],
        contradictions: [String] = [],
        emotionalLanguage: [String] = [],
        missingDetails: [String] = [],
        neutralSummary: String = "",
        sideBySideComparison: [SideBySideComparisonItem] = [],
        partyAName: String = "",
        partyBName: String = "",
        generatedAt: Date = Date()
    ) {
        self.timelineDifferences = timelineDifferences
        self.agreementPoints = agreementPoints
        self.contradictions = contradictions
        self.emotionalLanguage = emotionalLanguage
        self.missingDetails = missingDetails
        self.neutralSummary = neutralSummary
        self.sideBySideComparison = sideBySideComparison
        self.partyAName = partyAName
        self.partyBName = partyBName
        self.generatedAt = generatedAt
    }
}

// MARK: - Policy Match
struct PolicyMatch: Identifiable, Codable {
    let id: UUID
    var policySectionId: UUID
    var sectionTitle: String
    var sectionNumber: String
    var relevanceExplanation: String
    var matchConfidence: Double  // 0.0 to 1.0
    
    init(
        id: UUID = UUID(),
        policySectionId: UUID,
        sectionTitle: String,
        sectionNumber: String,
        relevanceExplanation: String,
        matchConfidence: Double
    ) {
        self.id = id
        self.policySectionId = policySectionId
        self.sectionTitle = sectionTitle
        self.sectionNumber = sectionNumber
        self.relevanceExplanation = relevanceExplanation
        self.matchConfidence = matchConfidence
    }
}

// MARK: - AI Recommendation
struct AIRecommendation: Identifiable, Codable {
    let id: UUID
    var action: RecommendedAction
    var reasoning: String
    var riskAssessment: String
    var suggestedNextSteps: [String]
    var confidence: Double  // 0.0 to 1.0
    
    init(
        id: UUID = UUID(),
        action: RecommendedAction,
        reasoning: String,
        riskAssessment: String,
        suggestedNextSteps: [String],
        confidence: Double
    ) {
        self.id = id
        self.action = action
        self.reasoning = reasoning
        self.riskAssessment = riskAssessment
        self.suggestedNextSteps = suggestedNextSteps
        self.confidence = confidence
    }
}

// MARK: - Generated Action Document
struct GeneratedActionDocument: Identifiable, Codable {
    let id: UUID
    var actionType: RecommendedAction
    var title: String
    var content: String
    var talkingPoints: [String]?
    var questionsToAsk: [String]?
    var behavioralFocusAreas: [String]?
    var followUpTimeline: String?
    var policyReferences: [String]?
    var supervisorEdits: String?
    var isApproved: Bool
    var createdAt: Date
    var approvedAt: Date?
    
    init(
        id: UUID = UUID(),
        actionType: RecommendedAction,
        title: String,
        content: String,
        talkingPoints: [String]? = nil,
        questionsToAsk: [String]? = nil,
        behavioralFocusAreas: [String]? = nil,
        followUpTimeline: String? = nil,
        policyReferences: [String]? = nil,
        supervisorEdits: String? = nil,
        isApproved: Bool = false,
        createdAt: Date = Date(),
        approvedAt: Date? = nil
    ) {
        self.id = id
        self.actionType = actionType
        self.title = title
        self.content = content
        self.talkingPoints = talkingPoints
        self.questionsToAsk = questionsToAsk
        self.behavioralFocusAreas = behavioralFocusAreas
        self.followUpTimeline = followUpTimeline
        self.policyReferences = policyReferences
        self.supervisorEdits = supervisorEdits
        self.isApproved = isApproved
        self.createdAt = createdAt
        self.approvedAt = approvedAt
    }
}

// MARK: - Audit Log Entry
struct CaseAuditEntry: Identifiable, Codable {
    let id: UUID
    var action: String
    var details: String
    var userId: String
    var userName: String
    var timestamp: Date
    
    init(id: UUID = UUID(), action: String, details: String, userId: String, userName: String, timestamp: Date = Date()) {
        self.id = id
        self.action = action
        self.details = details
        self.userId = userId
        self.userName = userName
        self.timestamp = timestamp
    }
}

// MARK: - Conflict Case (Main Model)
struct ConflictCase: Identifiable, Codable {
    let id: UUID
    var caseNumber: String
    var type: CaseType
    var status: CaseStatus
    var incidentDate: Date
    var location: String
    var department: String
    var shift: String?
    
    // Involved Parties
    var involvedEmployees: [InvolvedEmployee]
    
    // Documents
    var documents: [CaseDocument]
    
    // AI Analysis
    var comparisonResult: AIComparisonResult?
    var policyMatches: [PolicyMatch]
    var recommendations: [AIRecommendation]
    
    // Selected Action
    var selectedAction: RecommendedAction?
    var generatedDocument: GeneratedActionDocument?
    
    // Supervisor Notes
    var supervisorNotes: String?
    
    // Audit Trail
    var auditLog: [CaseAuditEntry]
    
    // Metadata
    var createdBy: String
    var createdAt: Date
    var updatedAt: Date
    var closedAt: Date?
    var activePolicyId: UUID?
    
    init(
        id: UUID = UUID(),
        caseNumber: String = "",
        type: CaseType = .conflict,
        status: CaseStatus = .draft,
        incidentDate: Date = Date(),
        location: String = "",
        department: String = "",
        shift: String? = nil,
        involvedEmployees: [InvolvedEmployee] = [],
        documents: [CaseDocument] = [],
        comparisonResult: AIComparisonResult? = nil,
        policyMatches: [PolicyMatch] = [],
        recommendations: [AIRecommendation] = [],
        selectedAction: RecommendedAction? = nil,
        generatedDocument: GeneratedActionDocument? = nil,
        supervisorNotes: String? = nil,
        auditLog: [CaseAuditEntry] = [],
        createdBy: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        closedAt: Date? = nil,
        activePolicyId: UUID? = nil
    ) {
        self.id = id
        self.caseNumber = caseNumber
        self.type = type
        self.status = status
        self.incidentDate = incidentDate
        self.location = location
        self.department = department
        self.shift = shift
        self.involvedEmployees = involvedEmployees
        self.documents = documents
        self.comparisonResult = comparisonResult
        self.policyMatches = policyMatches
        self.recommendations = recommendations
        self.selectedAction = selectedAction
        self.generatedDocument = generatedDocument
        self.supervisorNotes = supervisorNotes
        self.auditLog = auditLog
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.closedAt = closedAt
        self.activePolicyId = activePolicyId
    }
    
    // MARK: - Computed Properties
    
    var complainantA: InvolvedEmployee? {
        involvedEmployees.first { $0.isComplainant }
    }
    
    var complainantB: InvolvedEmployee? {
        involvedEmployees.filter { $0.isComplainant }.dropFirst().first
    }
    
    var witnesses: [InvolvedEmployee] {
        involvedEmployees.filter { !$0.isComplainant }
    }
    
    var complaintDocumentA: CaseDocument? {
        documents.first { $0.type == .complaintA }
    }
    
    var complaintDocumentB: CaseDocument? {
        documents.first { $0.type == .complaintB }
    }
    
    var witnessStatements: [CaseDocument] {
        documents.filter { $0.type == .witnessStatement }
    }
    
    var hasAllRequiredDocuments: Bool {
        complaintDocumentA != nil && complaintDocumentB != nil
    }
    
    var canRunComparison: Bool {
        hasAllRequiredDocuments && comparisonResult == nil
    }
    
    var displayTitle: String {
        if !caseNumber.isEmpty {
            return "Case #\(caseNumber)"
        }
        return "New Case"
    }
    
    var formattedIncidentDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: incidentDate)
    }
    
    // Generate case number
    static func generateCaseNumber() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: Date())
        let randomSuffix = String(format: "%04d", Int.random(in: 1000...9999))
        return "CR-\(dateString)-\(randomSuffix)"
    }
}
