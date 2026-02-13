//
//  AuditTrailService.swift
//  MeetingIntelligence
//
//  Phase 8: Audit Trail Logging Service
//  Tracks all actions and changes for compliance and record-keeping
//

import Foundation
import Combine
import UIKit

// MARK: - Audit Event Type
enum AuditEventType: String, Codable {
    // Case Events
    case caseCreated = "CASE_CREATED"
    case caseUpdated = "CASE_UPDATED"
    case caseStatusChanged = "CASE_STATUS_CHANGED"
    case caseClosed = "CASE_CLOSED"
    case caseEscalated = "CASE_ESCALATED"
    
    // Document Events
    case documentScanned = "DOCUMENT_SCANNED"
    case documentUploaded = "DOCUMENT_UPLOADED"
    case documentProcessed = "DOCUMENT_PROCESSED"
    case documentGenerated = "DOCUMENT_GENERATED"
    case documentEdited = "DOCUMENT_EDITED"
    case documentExported = "DOCUMENT_EXPORTED"
    case documentSigned = "DOCUMENT_SIGNED"
    
    // Analysis Events
    case analysisPerformed = "ANALYSIS_PERFORMED"
    case policyMatchCompleted = "POLICY_MATCH_COMPLETED"
    case recommendationGenerated = "RECOMMENDATION_GENERATED"
    
    // Action Events
    case actionSelected = "ACTION_SELECTED"
    case actionConfirmed = "ACTION_CONFIRMED"
    case actionGenerated = "ACTION_GENERATED"
    case actionRegenerated = "ACTION_REGENERATED"
    case actionCustomized = "ACTION_CUSTOMIZED"
    case actionFinalized = "ACTION_FINALIZED"
    
    // Review Events
    case supervisorReviewStarted = "SUPERVISOR_REVIEW_STARTED"
    case supervisorReviewCompleted = "SUPERVISOR_REVIEW_COMPLETED"
    case hrReviewRequested = "HR_REVIEW_REQUESTED"
    case hrReviewCompleted = "HR_REVIEW_COMPLETED"
    
    // Warning Specific
    case warningLevelSelected = "WARNING_LEVEL_SELECTED"
    case warningIssued = "WARNING_ISSUED"
    
    // Escalation Specific
    case escalationPrioritySet = "ESCALATION_PRIORITY_SET"
    case escalationRecipientsSelected = "ESCALATION_RECIPIENTS_SELECTED"
    case escalationSubmitted = "ESCALATION_SUBMITTED"
    
    // Signature Events
    case signatureRequested = "SIGNATURE_REQUESTED"
    case signatureCaptured = "SIGNATURE_CAPTURED"
    case signatureVerified = "SIGNATURE_VERIFIED"
    
    var displayName: String {
        switch self {
        case .caseCreated: return "Case Created"
        case .caseUpdated: return "Case Updated"
        case .caseStatusChanged: return "Status Changed"
        case .caseClosed: return "Case Closed"
        case .caseEscalated: return "Case Escalated"
        case .documentScanned: return "Document Scanned"
        case .documentUploaded: return "Document Uploaded"
        case .documentProcessed: return "Document Processed"
        case .documentGenerated: return "Document Generated"
        case .documentEdited: return "Document Edited"
        case .documentExported: return "Document Exported"
        case .documentSigned: return "Document Signed"
        case .analysisPerformed: return "Analysis Performed"
        case .policyMatchCompleted: return "Policy Match Completed"
        case .recommendationGenerated: return "Recommendation Generated"
        case .actionSelected: return "Action Selected"
        case .actionConfirmed: return "Action Confirmed"
        case .actionGenerated: return "Action Generated"
        case .actionRegenerated: return "Action Regenerated"
        case .actionCustomized: return "Action Customized"
        case .actionFinalized: return "Action Finalized"
        case .supervisorReviewStarted: return "Review Started"
        case .supervisorReviewCompleted: return "Review Completed"
        case .hrReviewRequested: return "HR Review Requested"
        case .hrReviewCompleted: return "HR Review Completed"
        case .warningLevelSelected: return "Warning Level Selected"
        case .warningIssued: return "Warning Issued"
        case .escalationPrioritySet: return "Priority Set"
        case .escalationRecipientsSelected: return "Recipients Selected"
        case .escalationSubmitted: return "Escalation Submitted"
        case .signatureRequested: return "Signature Requested"
        case .signatureCaptured: return "Signature Captured"
        case .signatureVerified: return "Signature Verified"
        }
    }
}

// MARK: - Audit Entry
struct AuditEntry: Codable, Identifiable {
    let id: UUID
    let caseId: UUID
    let caseNumber: String
    let eventType: AuditEventType
    let timestamp: Date
    let userId: String
    let userName: String
    let userRole: String
    let description: String
    let details: [String: String]?
    let previousValue: String?
    let newValue: String?
    let ipAddress: String?
    let deviceInfo: String?
    
    init(
        caseId: UUID,
        caseNumber: String,
        eventType: AuditEventType,
        userId: String,
        userName: String,
        userRole: String,
        description: String,
        details: [String: String]? = nil,
        previousValue: String? = nil,
        newValue: String? = nil
    ) {
        self.id = UUID()
        self.caseId = caseId
        self.caseNumber = caseNumber
        self.eventType = eventType
        self.timestamp = Date()
        self.userId = userId
        self.userName = userName
        self.userRole = userRole
        self.description = description
        self.details = details
        self.previousValue = previousValue
        self.newValue = newValue
        self.ipAddress = AuditTrailService.getIPAddress()
        self.deviceInfo = AuditTrailService.getDeviceInfo()
    }
}

// MARK: - Audit Trail Service
class AuditTrailService {
    static let shared = AuditTrailService()
    
    private let baseURL = "https://dashmet-rca-api.onrender.com/api/audit"
    private var localCache: [AuditEntry] = []
    private let maxCacheSize = 100
    
    // Current user info (should be set on login)
    var currentUserId: String = ""
    var currentUserName: String = ""
    var currentUserRole: String = ""
    
    private init() {
        loadLocalCache()
    }
    
    // MARK: - Log Event
    
    /// Log an audit event for a case
    func logEvent(
        caseId: UUID,
        caseNumber: String,
        eventType: AuditEventType,
        description: String,
        details: [String: String]? = nil,
        previousValue: String? = nil,
        newValue: String? = nil
    ) {
        let entry = AuditEntry(
            caseId: caseId,
            caseNumber: caseNumber,
            eventType: eventType,
            userId: currentUserId,
            userName: currentUserName,
            userRole: currentUserRole,
            description: description,
            details: details,
            previousValue: previousValue,
            newValue: newValue
        )
        
        // Add to local cache
        addToCache(entry)
        
        // Send to server asynchronously
        Task {
            await sendToServer(entry)
        }
        
        // Print for debugging
        print("📋 AUDIT: [\(eventType.displayName)] \(description)")
    }
    
    // MARK: - Convenience Methods
    
    /// Log action selection event
    func logActionSelected(
        caseId: UUID,
        caseNumber: String,
        actionType: ActionType,
        confidence: Double
    ) {
        logEvent(
            caseId: caseId,
            caseNumber: caseNumber,
            eventType: .actionSelected,
            description: "Selected \(actionType.displayName) action",
            details: [
                "actionType": actionType.rawValue,
                "confidence": String(format: "%.2f", confidence)
            ]
        )
    }
    
    /// Log document generated event
    func logDocumentGenerated(
        caseId: UUID,
        caseNumber: String,
        actionType: ActionType,
        documentTitle: String
    ) {
        logEvent(
            caseId: caseId,
            caseNumber: caseNumber,
            eventType: .documentGenerated,
            description: "Generated \(actionType.displayName) document: \(documentTitle)",
            details: [
                "actionType": actionType.rawValue,
                "documentTitle": documentTitle
            ]
        )
    }
    
    /// Log document edited event
    func logDocumentEdited(
        caseId: UUID,
        caseNumber: String,
        sectionEdited: String,
        previousContent: String? = nil,
        newContent: String? = nil
    ) {
        logEvent(
            caseId: caseId,
            caseNumber: caseNumber,
            eventType: .documentEdited,
            description: "Edited section: \(sectionEdited)",
            details: ["section": sectionEdited],
            previousValue: previousContent,
            newValue: newContent
        )
    }
    
    /// Log document exported event
    func logDocumentExported(
        caseId: UUID,
        caseNumber: String,
        format: ExportFormat,
        destination: ExportDestination
    ) {
        logEvent(
            caseId: caseId,
            caseNumber: caseNumber,
            eventType: .documentExported,
            description: "Exported document as \(format.displayName) to \(destination.displayName)",
            details: [
                "format": format.rawValue,
                "destination": destination.rawValue
            ]
        )
    }
    
    /// Log warning level selected event
    func logWarningLevelSelected(
        caseId: UUID,
        caseNumber: String,
        warningLevel: WarningLevel,
        employeeName: String
    ) {
        logEvent(
            caseId: caseId,
            caseNumber: caseNumber,
            eventType: .warningLevelSelected,
            description: "Selected \(warningLevel.displayName) for \(employeeName)",
            details: [
                "warningLevel": warningLevel.rawValue,
                "employeeName": employeeName
            ]
        )
    }
    
    /// Log escalation submitted event
    func logEscalationSubmitted(
        caseId: UUID,
        caseNumber: String,
        priority: EscalationPriority,
        recipients: [HRRecipientType]
    ) {
        logEvent(
            caseId: caseId,
            caseNumber: caseNumber,
            eventType: .escalationSubmitted,
            description: "Submitted escalation with \(priority.displayName) priority",
            details: [
                "priority": priority.rawValue,
                "recipients": recipients.map { $0.displayName }.joined(separator: ", ")
            ]
        )
    }
    
    /// Log signature captured event
    func logSignatureCaptured(
        caseId: UUID,
        caseNumber: String,
        signatureType: String,
        signerName: String
    ) {
        logEvent(
            caseId: caseId,
            caseNumber: caseNumber,
            eventType: .signatureCaptured,
            description: "Captured \(signatureType) signature from \(signerName)",
            details: [
                "signatureType": signatureType,
                "signerName": signerName
            ]
        )
    }
    
    /// Log action customization event
    func logActionCustomized(
        caseId: UUID,
        caseNumber: String,
        customizations: DocumentCustomizationSettings
    ) {
        var details: [String: String] = [
            "toneLevel": String(format: "%.2f", customizations.toneLevel),
            "lengthPreference": customizations.lengthPreference.rawValue
        ]
        
        if customizations.simplifyLanguage {
            details["simplifyLanguage"] = "true"
        }
        if customizations.addMoreContext {
            details["addMoreContext"] = "true"
        }
        if customizations.includeExamples {
            details["includeExamples"] = "true"
        }
        if customizations.removeTechnicalJargon {
            details["removeTechnicalJargon"] = "true"
        }
        if customizations.useOrganizationalTemplate {
            details["useTemplate"] = customizations.selectedTemplateId ?? "default"
        }
        
        logEvent(
            caseId: caseId,
            caseNumber: caseNumber,
            eventType: .actionCustomized,
            description: "Applied document customizations",
            details: details
        )
    }
    
    /// Log case finalized event
    func logCaseFinalized(
        caseId: UUID,
        caseNumber: String,
        finalAction: ActionType,
        documentCount: Int
    ) {
        logEvent(
            caseId: caseId,
            caseNumber: caseNumber,
            eventType: .actionFinalized,
            description: "Finalized case with \(finalAction.displayName)",
            details: [
                "finalAction": finalAction.rawValue,
                "documentCount": String(documentCount)
            ]
        )
    }
    
    // MARK: - Retrieve Audit Trail
    
    /// Get audit trail for a specific case
    func getAuditTrail(for caseId: UUID) -> [AuditEntry] {
        return localCache.filter { $0.caseId == caseId }.sorted { $0.timestamp > $1.timestamp }
    }
    
    /// Get recent audit entries
    func getRecentEntries(limit: Int = 50) -> [AuditEntry] {
        return Array(localCache.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }
    
    // MARK: - Server Communication
    
    private func sendToServer(_ entry: AuditEntry) async {
        guard let url = URL(string: baseURL + "/log") else { return }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(entry)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("✅ Audit entry synced to server")
            }
        } catch {
            print("⚠️ Failed to sync audit entry: \(error.localizedDescription)")
            // Entry is still in local cache, will retry later
        }
    }
    
    // MARK: - Local Cache Management
    
    private func addToCache(_ entry: AuditEntry) {
        localCache.append(entry)
        
        // Trim cache if too large
        if localCache.count > maxCacheSize {
            localCache = Array(localCache.suffix(maxCacheSize))
        }
        
        saveLocalCache()
    }
    
    private func loadLocalCache() {
        let fileURL = getCacheFileURL()
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                localCache = try decoder.decode([AuditEntry].self, from: data)
            } catch {
                print("Failed to load audit cache: \(error)")
                localCache = []
            }
        }
    }
    
    private func saveLocalCache() {
        let fileURL = getCacheFileURL()
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(localCache)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save audit cache: \(error)")
        }
    }
    
    private func getCacheFileURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("audit_cache.json")
    }
    
    // MARK: - Device Info Helpers
    
    static func getIPAddress() -> String? {
        // This would typically get the actual IP address
        // For privacy, we'll return a placeholder
        return nil
    }
    
    static func getDeviceInfo() -> String {
        let device = UIDevice.current
        return "\(device.model) - \(device.systemName) \(device.systemVersion)"
    }
}

// MARK: - Audit Trail View Model
class AuditTrailViewModel: ObservableObject {
    @Published var entries: [AuditEntry] = []
    @Published var isLoading = false
    
    private let service = AuditTrailService.shared
    
    func loadAuditTrail(for caseId: UUID) {
        isLoading = true
        entries = service.getAuditTrail(for: caseId)
        isLoading = false
    }
    
    func loadRecentEntries() {
        isLoading = true
        entries = service.getRecentEntries()
        isLoading = false
    }
}
