//
//  ConflictResolutionManager.swift
//  MeetingIntelligence
//
//  Manager for the Policy-Aware Conflict Resolution Assistant
//

import Foundation
import SwiftUI
import Combine
import PDFKit
import Vision

@MainActor
class ConflictResolutionManager: ObservableObject {
    static let shared = ConflictResolutionManager()
    
    // MARK: - Published Properties
    
    // Policies
    @Published var policies: [WorkplacePolicy] = []
    @Published var activePolicy: WorkplacePolicy?
    @Published var isLoadingPolicies = false
    @Published var policyError: String?
    
    // Cases
    @Published var cases: [ConflictCase] = []
    @Published var currentCase: ConflictCase?
    @Published var isLoadingCases = false
    @Published var caseError: String?
    
    // Document Processing
    @Published var isProcessingDocument = false
    @Published var processingProgress: Double = 0
    @Published var processingStatus: String = ""
    
    // AI Analysis
    @Published var isAnalyzing = false
    @Published var analysisProgress: Double = 0
    @Published var analysisStatus: String = ""
    
    // MARK: - Private Properties
    
    // Database sync services
    private let caseService = ConflictCaseService.shared
    private let policyService = WorkplacePolicyService.shared
    
    // User context for API calls (set from AppState)
    var currentUserId: String?
    var currentOrganizationId: String?
    var currentFacilityId: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        // Clear any legacy UserDefaults cache to prevent stale data
        UserDefaults.standard.removeObject(forKey: "conflictResolution.cases")
    }
    
    /// Set user context for API calls (call this when user logs in)
    func setUserContext(userId: String, organizationId: String, facilityId: String?) {
        self.currentUserId = userId.isEmpty ? nil : userId
        self.currentOrganizationId = organizationId.isEmpty ? nil : organizationId
        self.currentFacilityId = facilityId
        
        print("📋 ConflictResolutionManager context set - userId: \(userId), orgId: \(organizationId), facilityId: \(facilityId ?? "nil")")
        
        // Load policies and cases from database
        if !userId.isEmpty && !organizationId.isEmpty {
            Task {
                await loadPoliciesFromDatabase()
                await loadCasesFromDatabase()
            }
        } else {
            print("⚠️ User context incomplete - cannot load from database")
        }
    }
    
    // MARK: - Policy Management (Database-Backed)
    
    /// Load policies from database (single source of truth)
    func loadPoliciesFromDatabase() async {
        guard let organizationId = currentOrganizationId else {
            print("Cannot load policies: organizationId not set")
            return
        }
        
        isLoadingPolicies = true
        policyError = nil
        
        do {
            let remotePolicies = try await policyService.fetchPolicies(organizationId: organizationId)
            
            policies = remotePolicies.map { $0.toWorkplacePolicy() }
            
            // Set active policy
            activePolicy = policies.first { $0.status == .active }
            if activePolicy == nil {
                activePolicy = policies.first
            }
            
            print("✅ Loaded \(policies.count) policies from database")
        } catch {
            policyError = "Failed to load policies: \(error.localizedDescription)"
            print("Error loading policies from database: \(error)")
        }
        
        isLoadingPolicies = false
    }
    
    /// Create a new policy from uploaded document
    func createPolicy(
        name: String,
        version: String,
        effectiveDate: Date,
        description: String,
        documentURL: URL
    ) async throws -> WorkplacePolicy {
        guard let userId = currentUserId, let orgId = currentOrganizationId else {
            throw PolicyError.failedToReadDocument
        }
        
        isProcessingDocument = true
        processingProgress = 0
        processingStatus = "Reading document..."
        
        defer {
            isProcessingDocument = false
            processingProgress = 0
            processingStatus = ""
        }
        
        // Small helper to allow UI to update between steps
        func advanceProgress(_ value: Double, _ status: String) async {
            processingProgress = value
            processingStatus = status
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s for animation
        }
        
        // 1. Extract text from document
        await advanceProgress(0.1, "Reading document...")
        let extractedText = try await extractTextFromDocument(url: documentURL)
        
        // 2. Create document source
        await advanceProgress(0.25, "Extracting text...")
        
        let fileName = documentURL.lastPathComponent
        let fileType = documentURL.pathExtension.uppercased()
        
        let documentSource = PolicyDocumentSource(
            fileName: fileName,
            fileURL: documentURL.absoluteString,
            fileType: fileType,
            pageCount: countPages(url: documentURL),
            originalText: extractedText
        )
        
        // 3. AI-powered section analysis with progressive discipline detection
        await advanceProgress(0.4, "AI analyzing policy structure...")
        
        var sections: [PolicySection] = []
        do {
            print("📡 Calling AI parse-sections endpoint...")
            sections = try await policyService.aiParseSections(text: extractedText, policyName: name)
            await advanceProgress(0.7, "AI identified \(sections.count) sections")
            print("✅ AI parsing succeeded: \(sections.count) sections")
        } catch {
            print("⚠️ AI parsing failed: \(error). Creating single section fallback.")
            sections = [PolicySection(
                sectionNumber: "1",
                title: "Full Policy",
                content: String(extractedText.prefix(5000)),
                type: .overview,
                orderIndex: 0
            )]
        }
        
        // 4. Create policy object
        await advanceProgress(0.8, "Saving policy...")
        
        let policy = WorkplacePolicy(
            name: name,
            version: version,
            effectiveDate: effectiveDate,
            status: .draft,
            description: description,
            documentSource: documentSource,
            sections: sections,
            organizationId: orgId,
            createdBy: userId,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // 5. Save to database (backend is source of truth)
        let created = try await policyService.createPolicy(
            policy,
            creatorId: userId,
            organizationId: orgId,
            facilityId: currentFacilityId
        )
        
        print("✅ Policy saved to database with ID: \(created.id)")
        
        // 6. Reload from database to ensure consistency
        let savedPolicy = created.toWorkplacePolicy()
        policies.append(savedPolicy)
        
        processingProgress = 1.0
        processingStatus = "Complete!"
        
        return savedPolicy
    }
    
    /// Activate a policy
    func activatePolicy(_ policy: WorkplacePolicy) async {
        // Deactivate current active policy
        if let currentActive = activePolicy {
            if let index = policies.firstIndex(where: { $0.id == currentActive.id }) {
                policies[index].status = .superseded
                
                // Sync to database
                do {
                    _ = try await policyService.updatePolicy(id: currentActive.id.uuidString, updates: ["status": "SUPERSEDED"])
                } catch {
                    print("Error updating superseded policy: \(error)")
                }
            }
        }
        
        // Activate the new policy
        if let index = policies.firstIndex(where: { $0.id == policy.id }) {
            policies[index].status = .active
            policies[index].updatedAt = Date()
            activePolicy = policies[index]
            
            // Sync to database
            do {
                _ = try await policyService.updatePolicy(id: policy.id.uuidString, updates: ["status": "ACTIVE"])
            } catch {
                print("Error updating active policy: \(error)")
            }
        }
    }
    
    /// Delete a policy
    func deletePolicy(_ policy: WorkplacePolicy) async {
        // Delete from database
        do {
            try await policyService.deletePolicy(id: policy.id.uuidString)
        } catch {
            print("Error deleting policy from database: \(error)")
        }
        
        // Remove from local array
        policies.removeAll { $0.id == policy.id }
        if activePolicy?.id == policy.id {
            activePolicy = policies.first { $0.status == .active }
        }
    }
    
    /// Update a policy
    func updatePolicy(_ policy: WorkplacePolicy) async {
        if let index = policies.firstIndex(where: { $0.id == policy.id }) {
            var updatedPolicy = policy
            updatedPolicy.updatedAt = Date()
            policies[index] = updatedPolicy
            
            if activePolicy?.id == policy.id {
                activePolicy = updatedPolicy
            }
            
            // Sync to database
            var updates: [String: Any] = [
                "name": policy.name,
                "version": policy.version,
                "effectiveDate": ISO8601DateFormatter().string(from: policy.effectiveDate),
                "status": policy.status.rawValue,
                "description": policy.description
            ]
            
            if let docSource = policy.documentSource {
                updates["documentFileName"] = docSource.fileName
                updates["documentFileUrl"] = docSource.fileURL
                updates["documentFileType"] = docSource.fileType
                updates["documentPageCount"] = docSource.pageCount
                if let originalText = docSource.originalText {
                    updates["originalText"] = originalText
                }
            }
            
            if !policy.sections.isEmpty {
                let sectionsArray = policy.sections.map { section -> [String: Any] in
                    var dict: [String: Any] = [
                        "id": section.id.uuidString,
                        "sectionNumber": section.sectionNumber,
                        "title": section.title,
                        "content": section.content,
                        "type": section.type.rawValue,
                        "orderIndex": section.orderIndex
                    ]
                    if let v = section.firstProgression { dict["firstProgression"] = v }
                    if let v = section.secondProgression { dict["secondProgression"] = v }
                    if let v = section.thirdProgression { dict["thirdProgression"] = v }
                    if let v = section.fourthProgression { dict["fourthProgression"] = v }
                    return dict
                }
                updates["sections"] = sectionsArray
            }
            
            do {
                _ = try await policyService.updatePolicy(id: policy.id.uuidString, updates: updates)
                print("✅ Policy updated in database")
            } catch {
                print("Error updating policy in database: \(error)")
            }
        }
    }
    
    // MARK: - Document Text Extraction
    
    /// Extract text from PDF or DOC file
    private func extractTextFromDocument(url: URL) async throws -> String {
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "pdf":
            return try extractTextFromPDF(url: url)
        case "doc", "docx":
            return try extractTextFromWord(url: url)
        case "txt":
            return try String(contentsOf: url, encoding: .utf8)
        default:
            throw PolicyError.unsupportedFileType
        }
    }
    
    /// Extract text from PDF
    private func extractTextFromPDF(url: URL) throws -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw PolicyError.failedToReadDocument
        }
        
        var fullText = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex),
               let pageText = page.string {
                fullText += pageText + "\n\n"
            }
        }
        
        return fullText
    }
    
    /// Extract text from Word document (basic implementation)
    private func extractTextFromWord(url: URL) throws -> String {
        // For DOC/DOCX, we'll use a simplified approach
        // In production, you'd use a proper library or server-side processing
        let data = try Data(contentsOf: url)
        
        // Try to read as plain text first
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        
        // For DOCX, try to extract from XML
        // This is a simplified approach - production would use proper DOCX parsing
        throw PolicyError.unsupportedFileType
    }
    
    /// Count pages in document
    private func countPages(url: URL) -> Int {
        if url.pathExtension.lowercased() == "pdf",
           let pdfDocument = PDFDocument(url: url) {
            return pdfDocument.pageCount
        }
        return 1
    }
    
    // MARK: - Case Management (Database-Backed)
    
    /// Load cases from database
    func loadCasesFromDatabase() async {
        guard let organizationId = currentOrganizationId else {
            print("Cannot load cases: organizationId not set")
            return
        }
        
        isLoadingCases = true
        caseError = nil
        
        do {
            let remoteCases = try await caseService.fetchCases(organizationId: organizationId, createdBy: currentUserId)
            cases = remoteCases.map { $0.toConflictCase() }
        } catch {
            caseError = "Failed to load cases: \(error.localizedDescription)"
            print("Error loading cases from database: \(error)")
        }
        
        isLoadingCases = false
    }
    
    /// Refresh a single case from the API and update the in-memory array.
    /// Call this when opening a case detail to ensure documents are up-to-date.
    func refreshCase(backendId: String) async {
        do {
            let apiCase = try await caseService.fetchCase(id: backendId)
            var refreshedCase = apiCase.toConflictCase()
            
            if let index = cases.firstIndex(where: { $0.backendId == backendId || $0.id == refreshedCase.id }) {
                // Preserve the local UUID so CaseDetailView can still find this case
                refreshedCase.id = cases[index].id
                cases[index] = refreshedCase
            } else {
                cases.insert(refreshedCase, at: 0)
            }
            
            if currentCase?.backendId == backendId {
                currentCase = refreshedCase
            }
            
            print("✅ Case \(backendId) refreshed from API — \(refreshedCase.documents.count) documents")
        } catch {
            print("⚠️ Failed to refresh case \(backendId): \(error.localizedDescription)")
        }
    }
    
    /// Create a new case and save to database
    func createCase(
        type: CaseType,
        incidentDate: Date,
        location: String,
        department: String,
        shift: String?,
        involvedEmployees: [InvolvedEmployee]
    ) async -> ConflictCase {
        let caseNumber = ConflictCase.generateCaseNumber()
        
        let newCase = ConflictCase(
            caseNumber: caseNumber,
            type: type,
            status: .draft,
            incidentDate: incidentDate,
            location: location,
            department: department,
            shift: shift,
            involvedEmployees: involvedEmployees,
            createdBy: currentUserId ?? "",
            activePolicyId: activePolicy?.id
        )
        
        // Add to local array first
        cases.insert(newCase, at: 0)
        currentCase = newCase
        
        // Save to database
        print("🔍 Creating case - userId: \(currentUserId ?? "nil"), orgId: \(currentOrganizationId ?? "nil")")
        
        if let userId = currentUserId, !userId.isEmpty,
           let orgId = currentOrganizationId, !orgId.isEmpty {
            do {
                print("📤 Saving case to database...")
                
                // Policy ID is now the backend UUID directly
                var backendPolicyId: String? = nil
                if let localPolicyId = newCase.activePolicyId {
                    backendPolicyId = localPolicyId.uuidString
                    print("🔍 Active policy - ID: \(backendPolicyId ?? "nil")")
                }
                
                let created = try await caseService.createCase(
                    newCase,
                    creatorId: userId,
                    organizationId: orgId,
                    facilityId: currentFacilityId,
                    activePolicyBackendId: backendPolicyId
                )
                
                // Update with backend ID
                if let index = cases.firstIndex(where: { $0.id == newCase.id }) {
                    cases[index].backendId = created.id
                    currentCase?.backendId = created.id
                    print("✅ Case saved to database with ID: \(created.id)")
                }
            } catch {
                caseError = "Failed to save case to database: \(error.localizedDescription)"
                print("❌ Error saving case to database: \(error)")
            }
        } else {
            caseError = "Cannot save to database: User context not set. Please log out and log in again."
            print("⚠️ Cannot save to database - missing userId or organizationId")
        }
        
        return newCase
    }
    
    /// Update a case and sync to database
    func updateCase(_ updatedCase: ConflictCase) async {
        if let index = cases.firstIndex(where: { $0.id == updatedCase.id }) {
            var caseToUpdate = updatedCase
            caseToUpdate.updatedAt = Date()
            cases[index] = caseToUpdate
            
            if currentCase?.id == updatedCase.id {
                currentCase = caseToUpdate
            }
            
            objectWillChange.send()
            
            // Sync to database
            if let backendId = caseToUpdate.backendId, let userId = currentUserId {
                do {
                    var updates: [String: Any] = [
                        "status": caseToUpdate.status.rawValue,
                        "caseType": caseToUpdate.type.rawValue
                    ]
                    
                    if !caseToUpdate.description.isEmpty {
                        updates["description"] = caseToUpdate.description
                    }
                    if let notes = caseToUpdate.supervisorNotes {
                        updates["supervisorNotes"] = notes
                    }
                    if let decision = caseToUpdate.supervisorDecision {
                        updates["finalDecision"] = decision
                    }
                    if let action = caseToUpdate.selectedAction {
                        updates["selectedActionType"] = action.rawValue
                    }
                    if let comparison = caseToUpdate.comparisonResult,
                       let data = try? JSONEncoder().encode(comparison),
                       let json = try? JSONSerialization.jsonObject(with: data) {
                        updates["aiComparisonResultJson"] = json
                    }
                    if !caseToUpdate.recommendations.isEmpty,
                       let data = try? JSONEncoder().encode(caseToUpdate.recommendations),
                       let json = try? JSONSerialization.jsonObject(with: data) {
                        updates["aiRecommendationsJson"] = json
                    }
                    // Save full recommendation result for UI restoration
                    if let recResult = caseToUpdate.recommendationResult,
                       let data = try? JSONEncoder().encode(recResult),
                       let json = try? JSONSerialization.jsonObject(with: data) {
                        updates["recommendationResultJson"] = json
                    }
                    if !caseToUpdate.policyMatches.isEmpty,
                       let data = try? JSONEncoder().encode(caseToUpdate.policyMatches),
                       let json = try? JSONSerialization.jsonObject(with: data) {
                        updates["policyMatchesJson"] = json
                    }
                    // Save full policy matching result for UI restoration
                    if let polResult = caseToUpdate.policyMatchingResult,
                       let data = try? JSONEncoder().encode(polResult),
                       let json = try? JSONSerialization.jsonObject(with: data) {
                        updates["policyMatchingResultJson"] = json
                    }
                    if let actionDoc = caseToUpdate.generatedDocument,
                       let data = try? JSONEncoder().encode(actionDoc),
                       let json = try? JSONSerialization.jsonObject(with: data) {
                        updates["generatedActionDocJson"] = json
                    }
                    // Save full generated document result for complete UI restoration
                    if let fullResult = caseToUpdate.fullGeneratedDocumentResult,
                       let data = try? JSONEncoder().encode(fullResult),
                       let json = try? JSONSerialization.jsonObject(with: data) {
                        updates["fullGeneratedDocumentResultJson"] = json
                    }
                    
                    // Save per-employee generated documents
                    if let empDocs = caseToUpdate.employeeGeneratedDocuments, !empDocs.isEmpty,
                       let data = try? JSONEncoder().encode(empDocs),
                       let json = try? JSONSerialization.jsonObject(with: data) {
                        updates["employeeGeneratedDocumentsJson"] = json
                    }
                    
                    // Save approved employee names
                    if !caseToUpdate.approvedEmployeeNames.isEmpty {
                        updates["approvedEmployeeNamesJson"] = caseToUpdate.approvedEmployeeNames
                    }
                    
                    // Save target employee IDs for action
                    if !caseToUpdate.selectedTargetEmployeeIds.isEmpty {
                        updates["selectedTargetEmployeeIdsJson"] = caseToUpdate.selectedTargetEmployeeIds.map { $0.uuidString }
                        print("🎯 Manager: sending selectedTargetEmployeeIdsJson: \(caseToUpdate.selectedTargetEmployeeIds.map { $0.uuidString })")
                    }
                    
                    // Sync involved employees to backend
                    if !caseToUpdate.involvedEmployees.isEmpty {
                        let employeesData = caseToUpdate.involvedEmployees.map { emp -> [String: Any] in
                            var empDict: [String: Any] = [
                                "id": emp.id.uuidString,
                                "name": emp.name,
                                "role": emp.role,
                                "department": emp.department,
                                "isComplainant": emp.isComplainant
                            ]
                            if let employeeId = emp.employeeId {
                                empDict["employeeId"] = employeeId
                            }
                            return empDict
                        }
                        updates["involvedEmployeesJson"] = employeesData
                    }
                    
                    _ = try await caseService.updateCase(id: backendId, updates: updates, userId: userId)
                } catch {
                    caseError = "Failed to sync case update: \(error.localizedDescription)"
                    print("Error updating case in database: \(error)")
                }
            }
        }
    }
    
    /// Legacy sync version for non-async contexts
    func updateCaseSync(_ updatedCase: ConflictCase) {
        Task {
            await updateCase(updatedCase)
        }
    }
    
    /// Update case status and sync to database
    func updateCaseStatus(_ caseId: UUID, to newStatus: CaseStatus) async {
        if let index = cases.firstIndex(where: { $0.id == caseId }) {
            var updatedCase = cases[index]
            updatedCase.status = newStatus
            updatedCase.updatedAt = Date()
            
            // Add audit entry for status change
            let auditEntry = CaseAuditEntry(
                action: "Status changed to \(newStatus.rawValue)",
                details: "Case status updated",
                userId: currentUserId ?? "supervisor",
                userName: "Supervisor"
            )
            updatedCase.auditLog.append(auditEntry)
            
            cases[index] = updatedCase
            
            if currentCase?.id == caseId {
                currentCase = updatedCase
            }
            
            objectWillChange.send()
            
            // Sync to database
            if let backendId = updatedCase.backendId, let userId = currentUserId {
                do {
                    _ = try await caseService.updateCase(
                        id: backendId,
                        updates: ["status": newStatus.rawValue],
                        userId: userId
                    )
                } catch {
                    print("Error updating case status in database: \(error)")
                }
            }
        }
    }
    
    /// Delete a case from database
    func deleteCase(_ caseToDelete: ConflictCase) async {
        // Remove from local array
        cases.removeAll { $0.id == caseToDelete.id }
        if currentCase?.id == caseToDelete.id {
            currentCase = nil
        }
        objectWillChange.send()
        
        // Delete from database
        if let backendId = caseToDelete.backendId {
            do {
                try await caseService.deleteCase(id: backendId)
            } catch {
                caseError = "Failed to delete case from database: \(error.localizedDescription)"
                print("Error deleting case from database: \(error)")
            }
        }
    }
    
    /// Add document to case and sync to database
    func addDocument(to caseId: UUID, document: CaseDocument) async {
        if let index = cases.firstIndex(where: { $0.id == caseId }) {
            var updatedCase = cases[index]
            updatedCase.documents.append(document)
            updatedCase.updatedAt = Date()
            
            // Add audit entry
            let auditEntry = CaseAuditEntry(
                action: "Document Added",
                details: "Added \(document.type.displayName)",
                userId: currentUserId ?? "",
                userName: "User"
            )
            updatedCase.auditLog.append(auditEntry)
            
            cases[index] = updatedCase
            if currentCase?.id == caseId {
                currentCase = updatedCase
            }
            objectWillChange.send()
            
            // Sync to database
            if let backendId = updatedCase.backendId {
                print("📤 Adding document to database - backendId: \(backendId)")
                if let userId = currentUserId {
                    do {
                        try await caseService.addDocument(caseId: backendId, document: document, userId: userId)
                        print("✅ Document synced to database")
                    } catch {
                        print("❌ Error adding document to database: \(error)")
                        // Case might not exist - try to create it first
                        caseError = "Document saved locally but failed to sync to database"
                    }
                } else {
                    print("⚠️ No userId available for document sync")
                }
            } else {
                print("⚠️ No backendId - document only saved locally")
                caseError = "Case not synced to database. Please sync case first."
            }
        }
    }
    
    /// Delete document from case and sync to database
    func deleteDocument(from caseId: UUID, documentId: UUID) async {
        if let index = cases.firstIndex(where: { $0.id == caseId }) {
            var updatedCase = cases[index]
            
            let removedDoc = updatedCase.documents.first { $0.id == documentId }
            updatedCase.documents.removeAll { $0.id == documentId }
            updatedCase.updatedAt = Date()
            
            if let doc = removedDoc {
                let auditEntry = CaseAuditEntry(
                    action: "Document Removed",
                    details: "Removed \(doc.type.displayName)",
                    userId: currentUserId ?? "",
                    userName: "User"
                )
                updatedCase.auditLog.append(auditEntry)
            }
            
            cases[index] = updatedCase
            if currentCase?.id == caseId {
                currentCase = updatedCase
            }
            objectWillChange.send()
            
            // Sync to database
            if let backendId = updatedCase.backendId, let userId = currentUserId {
                do {
                    try await caseService.removeDocument(
                        caseId: backendId,
                        documentId: documentId.uuidString,
                        userId: userId
                    )
                } catch {
                    print("Error removing document from database: \(error)")
                }
            }
        }
    }
    
    /// Sync all cases with database
    func syncCases() async {
        guard let orgId = currentOrganizationId, let userId = currentUserId else {
            return
        }
        
        isLoadingCases = true
        
        let syncedCases = await caseService.syncCases(
            localCases: cases,
            organizationId: orgId,
            creatorId: userId,
            facilityId: currentFacilityId
        )
        
        cases = syncedCases
        isLoadingCases = false
    }
    
    /// Finalize case and sync to database
    func finalizeCase(_ caseToClose: ConflictCase) async {
        await updateCaseStatus(caseToClose.id, to: .closed)
        
        // Update timestamp
        if let index = cases.firstIndex(where: { $0.id == caseToClose.id }) {
            cases[index].closedAt = Date()
        }
    }
    
    /// Re-open a closed/locked case via the dedicated reopen endpoint
    func reopenCase(_ caseId: UUID) async throws {
        guard let index = cases.firstIndex(where: { $0.id == caseId }) else { return }
        let caseToReopen = cases[index]
        
        if let backendId = caseToReopen.backendId, let userId = currentUserId {
            let reopenedData = try await caseService.reopenCase(id: backendId, reopenedBy: userId, reason: "Re-opened by supervisor")
            var updatedCase = reopenedData.toConflictCase()
            updatedCase.id = caseToReopen.id // Preserve local UUID
            cases[index] = updatedCase
        } else {
            // Local only — just update status
            cases[index].status = .awaitingAction
            cases[index].isLocked = false
            cases[index].closedAt = nil
            cases[index].closedBy = nil
            cases[index].closureReason = nil
            cases[index].closureSummary = nil
        }
        
        if currentCase?.id == caseId {
            currentCase = cases[index]
        }
        objectWillChange.send()
    }
    
    // MARK: - Statistics
    
    var totalCases: Int { cases.count }
    var openCases: Int { cases.filter { $0.status != .closed }.count }
    var closedCases: Int { cases.filter { $0.status == .closed }.count }
    var draftCases: Int { cases.filter { $0.status == .draft }.count }
    var escalatedCases: Int { cases.filter { $0.status == .escalated }.count }
    
    var activePoliciesCount: Int { policies.filter { $0.status == .active }.count }
}

// MARK: - Policy Errors
enum PolicyError: LocalizedError {
    case unsupportedFileType
    case failedToReadDocument
    case failedToParseDocument
    case policyNotFound
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "Unsupported file type. Please upload a PDF, DOC, or TXT file."
        case .failedToReadDocument:
            return "Failed to read the document. Please try again."
        case .failedToParseDocument:
            return "Failed to parse the document structure."
        case .policyNotFound:
            return "Policy not found."
        }
    }
}
