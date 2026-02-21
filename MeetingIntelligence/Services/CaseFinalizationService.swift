//
//  CaseFinalizationService.swift
//  MeetingIntelligence
//
//  Enterprise-Grade Case Finalization Service
//  Handles case closure, HR escalation, and comprehensive document export
//

import Foundation
import Combine
import UIKit
import PDFKit
import MessageUI

// MARK: - Finalization Result

struct FinalizationResult {
    let success: Bool
    let action: FinalizationAction
    let timestamp: Date
    let caseId: String
    let caseNumber: String
    let details: FinalizationDetails?
    let errorMessage: String?
    
    static func success(action: FinalizationAction, caseId: String, caseNumber: String, details: FinalizationDetails) -> FinalizationResult {
        return FinalizationResult(
            success: true,
            action: action,
            timestamp: Date(),
            caseId: caseId,
            caseNumber: caseNumber,
            details: details,
            errorMessage: nil
        )
    }
    
    static func failure(action: FinalizationAction, caseId: String, caseNumber: String, error: String) -> FinalizationResult {
        return FinalizationResult(
            success: false,
            action: action,
            timestamp: Date(),
            caseId: caseId,
            caseNumber: caseNumber,
            details: nil,
            errorMessage: error
        )
    }
}

enum FinalizationAction: String {
    case closeCase = "CASE_CLOSED"
    case sendToHR = "SENT_TO_HR"
    case exportPackage = "PACKAGE_EXPORTED"
    
    var displayName: String {
        switch self {
        case .closeCase: return "Case Closed"
        case .sendToHR: return "Sent to HR"
        case .exportPackage: return "Package Exported"
        }
    }
    
    var auditEventType: AuditEventType {
        switch self {
        case .closeCase: return .caseClosed
        case .sendToHR: return .caseEscalated
        case .exportPackage: return .documentExported
        }
    }
}

struct FinalizationDetails {
    let closureReason: String?
    let hrRecipients: [String]?
    let urgencyLevel: String?
    let exportedDocumentIds: [UUID]?
    let pdfPageCount: Int?
    let pdfFileSize: Int64?
    let supervisorNotes: String?
    let includeAuditTrail: Bool
    let includeAllDocuments: Bool
}

// MARK: - HR Submission Request

struct HRSubmissionRequest: Codable {
    let caseId: String
    let caseNumber: String
    let recipients: [String]
    let urgencyLevel: String
    let supervisorNotes: String?
    let includeAuditTrail: Bool
    let includeAllDocuments: Bool
    let generatedDocumentType: String?
    let submittedBy: String
    let submittedAt: String
}

struct HRSubmissionResponse: Codable {
    let success: Bool
    let submissionId: String?
    let trackingNumber: String?
    let estimatedReviewDate: String?
    let error: String?
}

// MARK: - Case Finalization Service

final class CaseFinalizationService: ObservableObject {
    
    static let shared = CaseFinalizationService()
    
    @Published var isProcessing = false
    @Published var currentStep = ""
    @Published var progress: Double = 0.0
    @Published var lastError: String?
    
    private let baseURL = "https://dashmet-rca-api.onrender.com/api/conflict-cases"
    
    private init() {}
    
    // MARK: - Close Case
    
    /// Closes and locks a case via the backend API
    /// This permanently locks the case and creates proper audit entries
    func closeCase(
        conflictCase: ConflictCase,
        closureReason: String,
        closureSummary: String?,
        supervisorNotes: String?,
        closedBy: String,
        includeAuditTrail: Bool,
        includeAllDocuments: Bool
    ) async -> FinalizationResult {
        
        guard let backendId = conflictCase.backendId, !backendId.isEmpty else {
            return .failure(
                action: .closeCase,
                caseId: conflictCase.id.uuidString,
                caseNumber: conflictCase.caseNumber,
                error: "Case has not been synced to server. Please save the case first."
            )
        }
        
        // Check if case is already locked
        if conflictCase.isLocked {
            return .failure(
                action: .closeCase,
                caseId: backendId,
                caseNumber: conflictCase.caseNumber,
                error: "Case is already locked and cannot be modified."
            )
        }
        
        await MainActor.run {
            self.isProcessing = true
            self.currentStep = "Validating case data..."
            self.progress = 0.1
        }
        
        do {
            // Step 1: Call the backend close API
            await MainActor.run {
                self.currentStep = "Closing case..."
                self.progress = 0.3
            }
            
            let closeResponse = try await callCloseAPI(
                caseId: backendId,
                closureReason: closureReason,
                closureSummary: closureSummary,
                supervisorNotes: supervisorNotes,
                closedBy: closedBy,
                includeAuditTrail: includeAuditTrail,
                includeAllDocuments: includeAllDocuments
            )
            
            // Step 2: Record local audit entry
            await MainActor.run {
                self.currentStep = "Recording audit trail..."
                self.progress = 0.7
            }
            
            AuditTrailService.shared.logCaseFinalized(
                caseId: conflictCase.id,
                caseNumber: conflictCase.caseNumber,
                finalAction: "CLOSED",
                notes: supervisorNotes ?? ""
            )
            
            // Step 3: Build result details
            await MainActor.run {
                self.currentStep = "Complete"
                self.progress = 1.0
            }
            
            let closureDetails = FinalizationDetails(
                closureReason: closureReason,
                hrRecipients: nil,
                urgencyLevel: nil,
                exportedDocumentIds: nil,
                pdfPageCount: nil,
                pdfFileSize: nil,
                supervisorNotes: supervisorNotes,
                includeAuditTrail: includeAuditTrail,
                includeAllDocuments: includeAllDocuments
            )
            
            await MainActor.run {
                self.isProcessing = false
            }
            
            return .success(
                action: .closeCase,
                caseId: backendId,
                caseNumber: conflictCase.caseNumber,
                details: closureDetails
            )
            
        } catch {
            await MainActor.run {
                self.isProcessing = false
                self.lastError = error.localizedDescription
            }
            
            return .failure(
                action: .closeCase,
                caseId: backendId,
                caseNumber: conflictCase.caseNumber,
                error: error.localizedDescription
            )
        }
    }
    
    /// Calls the backend /close API endpoint
    private func callCloseAPI(
        caseId: String,
        closureReason: String,
        closureSummary: String?,
        supervisorNotes: String?,
        closedBy: String,
        includeAuditTrail: Bool,
        includeAllDocuments: Bool
    ) async throws -> CaseCloseResponse {
        
        guard let url = URL(string: "\(baseURL)/\(caseId)/close") else {
            throw FinalizationError.invalidURL
        }
        
        var requestBody: [String: Any] = [
            "closureReason": closureReason,
            "closedBy": closedBy,
            "includeAuditTrail": includeAuditTrail,
            "includeAllDocuments": includeAllDocuments
        ]
        
        if let summary = closureSummary, !summary.isEmpty {
            requestBody["closureSummary"] = summary
        }
        
        if let notes = supervisorNotes, !notes.isEmpty {
            requestBody["supervisorNotes"] = notes
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("📤 Calling close API: \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FinalizationError.invalidResponse
        }
        
        // Debug: print response
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Close API response (\(httpResponse.statusCode)): \(responseString)")
        }
        
        guard httpResponse.statusCode == 200 else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                throw FinalizationError.apiError(errorMessage)
            }
            throw FinalizationError.apiError("Failed to close case: HTTP \(httpResponse.statusCode)")
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(CaseCloseResponse.self, from: data)
    }
    
    // MARK: - Send to HR
    
    /// Prepares and submits case package to HR for review
    func sendToHR(
        conflictCase: ConflictCase,
        generatedDocument: GeneratedDocumentResult?,
        recipients: [String],
        urgencyLevel: HRUrgencyLevel,
        supervisorNotes: String,
        includeAuditTrail: Bool,
        includeAllDocuments: Bool
    ) async -> FinalizationResult {
        
        guard let backendId = conflictCase.backendId, !backendId.isEmpty else {
            return .failure(
                action: .sendToHR,
                caseId: conflictCase.id.uuidString,
                caseNumber: conflictCase.caseNumber,
                error: "Case has not been synced to server. Cannot submit to HR."
            )
        }
        
        guard !recipients.isEmpty else {
            return .failure(
                action: .sendToHR,
                caseId: backendId,
                caseNumber: conflictCase.caseNumber,
                error: "No HR recipient specified."
            )
        }
        
        await MainActor.run {
            self.isProcessing = true
            self.currentStep = "Preparing HR submission..."
            self.progress = 0.1
        }
        
        do {
            // Step 1: Update case status to ESCALATED
            await MainActor.run {
                self.currentStep = "Updating case status..."
                self.progress = 0.2
            }
            
            try await updateCaseStatus(
                caseId: backendId,
                status: "ESCALATED",
                supervisorNotes: supervisorNotes.isEmpty ? nil : supervisorNotes
            )
            
            // Step 2: Generate comprehensive PDF package
            await MainActor.run {
                self.currentStep = "Generating case package..."
                self.progress = 0.4
            }
            
            var pdfConfig = ReportConfiguration.full
            pdfConfig.includeAuditTrail = includeAuditTrail
            pdfConfig.includeScannedDocuments = includeAllDocuments
            pdfConfig.preparedFor = "HR Department"
            pdfConfig.confidentialityLevel = .hrOnly
            
            let reportResult = await CaseReportService.shared.generateReport(
                for: conflictCase,
                configuration: pdfConfig
            )
            
            // Step 3: Record HR submission
            await MainActor.run {
                self.currentStep = "Recording HR submission..."
                self.progress = 0.6
            }
            
            let submissionRequest = HRSubmissionRequest(
                caseId: backendId,
                caseNumber: conflictCase.caseNumber,
                recipients: recipients,
                urgencyLevel: urgencyLevel.rawValue,
                supervisorNotes: supervisorNotes.isEmpty ? nil : supervisorNotes,
                includeAuditTrail: includeAuditTrail,
                includeAllDocuments: includeAllDocuments,
                generatedDocumentType: generatedDocument?.actionType.rawValue,
                submittedBy: AuditTrailService.shared.currentUserName,
                submittedAt: ISO8601DateFormatter().string(from: Date())
            )
            
            try await recordHRSubmission(submission: submissionRequest)
            
            // Step 4: Create audit entry
            await MainActor.run {
                self.currentStep = "Recording audit trail..."
                self.progress = 0.8
            }
            
            AuditTrailService.shared.logEvent(
                caseId: conflictCase.id,
                caseNumber: conflictCase.caseNumber,
                eventType: .caseEscalated,
                description: "Case submitted to HR for review",
                details: [
                    "recipients": recipients.joined(separator: ", "),
                    "urgencyLevel": urgencyLevel.rawValue,
                    "includeAuditTrail": String(includeAuditTrail),
                    "includeAllDocuments": String(includeAllDocuments)
                ]
            )
            
            // Step 5: Complete
            await MainActor.run {
                self.currentStep = "Submission complete"
                self.progress = 1.0
                self.isProcessing = false
            }
            
            let details = FinalizationDetails(
                closureReason: nil,
                hrRecipients: recipients,
                urgencyLevel: urgencyLevel.rawValue,
                exportedDocumentIds: nil,
                pdfPageCount: reportResult.pageCount,
                pdfFileSize: Int64(reportResult.pdfData?.count ?? 0),
                supervisorNotes: supervisorNotes,
                includeAuditTrail: includeAuditTrail,
                includeAllDocuments: includeAllDocuments
            )
            
            return .success(
                action: .sendToHR,
                caseId: backendId,
                caseNumber: conflictCase.caseNumber,
                details: details
            )
            
        } catch {
            await MainActor.run {
                self.isProcessing = false
                self.lastError = error.localizedDescription
            }
            
            return .failure(
                action: .sendToHR,
                caseId: backendId,
                caseNumber: conflictCase.caseNumber,
                error: error.localizedDescription
            )
        }
    }
    
    // MARK: - Export Package
    
    /// Generates comprehensive PDF package for download
    func exportPackage(
        conflictCase: ConflictCase,
        generatedDocument: GeneratedDocumentResult?,
        exportOptions: ExportOptions
    ) async -> (result: FinalizationResult, pdfData: Data?) {
        
        await MainActor.run {
            self.isProcessing = true
            self.currentStep = "Preparing export..."
            self.progress = 0.1
        }
        
        // Step 1: Configure report
        await MainActor.run {
            self.currentStep = "Configuring report settings..."
            self.progress = 0.15
        }
        
        var pdfConfig = ReportConfiguration.full
        pdfConfig.includeAuditTrail = exportOptions.includeAuditTrail
        pdfConfig.includeScannedDocuments = exportOptions.includeAllDocuments
        pdfConfig.includeFullStatements = exportOptions.includeStatements
        pdfConfig.includeAIAnalysis = exportOptions.includeAIAnalysis
        pdfConfig.includePolicyMatches = exportOptions.includePolicyMatches
        pdfConfig.includeRecommendations = exportOptions.includeRecommendations
        pdfConfig.includeGeneratedDocument = exportOptions.includeGeneratedDocument
        pdfConfig.includeSignatureBlocks = exportOptions.includeSignatureBlocks
        pdfConfig.reportTitle = exportOptions.reportTitle
        pdfConfig.confidentialityLevel = exportOptions.confidentialityLevel
        pdfConfig.preparedBy = AuditTrailService.shared.currentUserName
        
        // Step 2: Generate comprehensive PDF
        await MainActor.run {
            self.currentStep = "Generating PDF document..."
            self.progress = 0.4
        }
        
        let reportResult = await CaseReportService.shared.generateReport(
            for: conflictCase,
            configuration: pdfConfig
        )
        
        guard reportResult.success, let pdfData = reportResult.pdfData else {
            await MainActor.run {
                self.isProcessing = false
                self.lastError = reportResult.errorMessage ?? "Failed to generate PDF"
            }
            
            return (
                .failure(
                    action: .exportPackage,
                    caseId: conflictCase.backendId ?? conflictCase.id.uuidString,
                    caseNumber: conflictCase.caseNumber,
                    error: reportResult.errorMessage ?? "Failed to generate PDF"
                ),
                nil
            )
        }
        
        // Step 3: Record audit entry
        await MainActor.run {
            self.currentStep = "Recording export..."
            self.progress = 0.9
        }
        
        AuditTrailService.shared.logDocumentExported(
            caseId: conflictCase.id,
            caseNumber: conflictCase.caseNumber,
            documentType: "Case Package PDF",
            pageCount: reportResult.pageCount,
            fileSize: Int64(pdfData.count)
        )
        
        // Step 4: Complete
        await MainActor.run {
            self.currentStep = "Export ready"
            self.progress = 1.0
            self.isProcessing = false
        }
        
        let details = FinalizationDetails(
            closureReason: nil,
            hrRecipients: nil,
            urgencyLevel: nil,
            exportedDocumentIds: nil,
            pdfPageCount: reportResult.pageCount,
            pdfFileSize: Int64(pdfData.count),
            supervisorNotes: nil,
            includeAuditTrail: exportOptions.includeAuditTrail,
            includeAllDocuments: exportOptions.includeAllDocuments
        )
        
        return (
            .success(
                action: .exportPackage,
                caseId: conflictCase.backendId ?? conflictCase.id.uuidString,
                caseNumber: conflictCase.caseNumber,
                details: details
            ),
            pdfData
        )
    }
    
    // MARK: - API Methods
    
    private func updateCaseStatus(caseId: String, status: String, supervisorNotes: String?) async throws {
        guard let url = URL(string: "\(baseURL)/\(caseId)") else {
            throw FinalizationError.invalidURL
        }
        
        var requestBody: [String: Any] = ["status": status]
        if let notes = supervisorNotes {
            requestBody["supervisorNotes"] = notes
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FinalizationError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                throw FinalizationError.apiError(errorMessage)
            }
            throw FinalizationError.apiError("Failed to update case: HTTP \(httpResponse.statusCode)")
        }
    }
    
    private func recordHRSubmission(submission: HRSubmissionRequest) async throws {
        // Record the HR submission - in production this would integrate with HR systems
        // For now, we store it in the audit trail and potentially a separate table
        guard let url = URL(string: "\(baseURL)/\(submission.caseId)/audit") else {
            throw FinalizationError.invalidURL
        }
        
        let auditEntry: [String: Any] = [
            "action": "HR_SUBMISSION",
            "details": "Submitted to HR: \(submission.recipients.joined(separator: ", ")). Urgency: \(submission.urgencyLevel)",
            "userName": submission.submittedBy
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: auditEntry)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            // Non-fatal - continue even if audit fails
            print("⚠️ Warning: Failed to record HR submission audit entry")
            return
        }
    }
}

// MARK: - Export Options

struct ExportOptions {
    var includeAuditTrail: Bool = true
    var includeAllDocuments: Bool = true
    var includeStatements: Bool = true
    var includeAIAnalysis: Bool = true
    var includePolicyMatches: Bool = true
    var includeRecommendations: Bool = true
    var includeGeneratedDocument: Bool = true
    var includeSignatureBlocks: Bool = true
    var reportTitle: String = "Case Investigation Package"
    var confidentialityLevel: ReportConfidentialityLevel = .confidential
    
    static var full: ExportOptions { ExportOptions() }
    
    static var minimal: ExportOptions {
        var options = ExportOptions()
        options.includeAuditTrail = false
        options.includeAllDocuments = false
        options.includeStatements = false
        options.reportTitle = "Case Summary"
        return options
    }
}

// MARK: - HR Urgency Level

enum HRUrgencyLevel: String, CaseIterable, Identifiable {
    case low = "LOW"
    case standard = "STANDARD"
    case high = "HIGH"
    case critical = "CRITICAL"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .standard: return "Standard"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var description: String {
        switch self {
        case .low: return "No immediate action needed"
        case .standard: return "Review within 5 business days"
        case .high: return "Review within 24-48 hours"
        case .critical: return "Immediate attention required"
        }
    }
    
    var color: UIColor {
        switch self {
        case .low: return .systemGray
        case .standard: return .systemBlue
        case .high: return .systemOrange
        case .critical: return .systemRed
        }
    }
    
    var estimatedResponseDays: Int {
        switch self {
        case .low: return 10
        case .standard: return 5
        case .high: return 2
        case .critical: return 1
        }
    }
}

// MARK: - Closure Reason

enum CaseClosureReason: String, CaseIterable, Identifiable {
    case resolved = "RESOLVED"
    case noFurtherAction = "NO_FURTHER_ACTION"
    case employeeSeparation = "EMPLOYEE_SEPARATION"
    case withdrawn = "WITHDRAWN"
    case insufficient = "INSUFFICIENT_EVIDENCE"
    case other = "OTHER"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .resolved: return "Issue Resolved"
        case .noFurtherAction: return "No Further Action Required"
        case .employeeSeparation: return "Employee Separation"
        case .withdrawn: return "Complaint Withdrawn"
        case .insufficient: return "Insufficient Evidence"
        case .other: return "Other"
        }
    }
    
    var description: String {
        switch self {
        case .resolved: return "The matter has been addressed and resolved"
        case .noFurtherAction: return "Investigation complete, no disciplinary action warranted"
        case .employeeSeparation: return "Employee has left the organization"
        case .withdrawn: return "Complainant has withdrawn the complaint"
        case .insufficient: return "Unable to substantiate claims with available evidence"
        case .other: return "Other reason (specify in notes)"
        }
    }
}

// MARK: - Errors

enum FinalizationError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case notSynced
    case missingData(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let message):
            return message
        case .notSynced:
            return "Case has not been synced to server"
        case .missingData(let field):
            return "Missing required data: \(field)"
        }
    }
}
// MARK: - API Response Models

struct CaseCloseResponse: Codable {
    let success: Bool
    let message: String?
    let data: CaseCloseData?
    let error: String?
}

struct CaseCloseData: Codable {
    let id: String
    let caseNumber: String
    let status: String
    let closedAt: String?
    let isLocked: Bool?
    let closureDetails: ClosureDetails?
}

struct ClosureDetails: Codable {
    let closedAt: String?
    let closedBy: ClosedByUser?
    let closureReason: String?
    let closureSummary: String?
    let isLocked: Bool?
}

struct ClosedByUser: Codable {
    let id: String
    let name: String
    let email: String
}