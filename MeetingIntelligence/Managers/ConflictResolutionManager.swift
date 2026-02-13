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
import NaturalLanguage

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
    
    private let userDefaults = UserDefaults.standard
    private let policiesKey = "conflictResolution.policies"
    private let casesKey = "conflictResolution.cases"
    private let activePolicyKey = "conflictResolution.activePolicy"
    private let policyBackendIdsKey = "conflictResolution.policyBackendIds" // Maps local UUID to backend ID
    
    // Database sync services
    private let caseService = ConflictCaseService.shared
    private let policyService = WorkplacePolicyService.shared
    
    // Policy backend ID mapping
    private var policyBackendIds: [UUID: String] = [:]
    
    // User context for API calls (set from AppState)
    var currentUserId: String?
    var currentOrganizationId: String?
    var currentFacilityId: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        loadPolicies()
        // Cases will be loaded from database when user context is set
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
            print("⚠️ User context incomplete - loading from local cache only")
            loadPoliciesFromCache()
            loadCasesFromCache()
        }
    }
    
    // MARK: - Policy Management (Database-Backed)
    
    /// Load policies from database
    func loadPoliciesFromDatabase() async {
        guard let organizationId = currentOrganizationId else {
            print("Cannot load policies: organizationId not set")
            loadPoliciesFromCache()
            return
        }
        
        isLoadingPolicies = true
        policyError = nil
        
        do {
            let remotePolicies = try await policyService.fetchPolicies(organizationId: organizationId)
            
            // Convert and store
            policies = remotePolicies.map { apiData in
                let policy = apiData.toWorkplacePolicy()
                // Store backend ID mapping
                policyBackendIds[policy.id] = apiData.id
                return policy
            }
            
            // Save backend ID mapping
            savePolicyBackendIds()
            
            // Save to local cache
            savePolicies()
            
            // Set active policy
            activePolicy = policies.first { $0.status == .active }
            if activePolicy == nil {
                activePolicy = policies.first
            }
            
            print("✅ Loaded \(policies.count) policies from database")
        } catch {
            policyError = "Failed to load policies: \(error.localizedDescription)"
            print("Error loading policies from database: \(error)")
            // Fall back to local cache
            loadPoliciesFromCache()
        }
        
        isLoadingPolicies = false
    }
    
    /// Load policies from local cache (fallback)
    private func loadPoliciesFromCache() {
        if let data = userDefaults.data(forKey: policiesKey),
           let decoded = try? JSONDecoder().decode([WorkplacePolicy].self, from: data) {
            policies = decoded
            
            // Load active policy
            if let activePolicyData = userDefaults.data(forKey: activePolicyKey),
               let activeId = try? JSONDecoder().decode(UUID.self, from: activePolicyData) {
                activePolicy = policies.first { $0.id == activeId }
            } else {
                activePolicy = policies.first { $0.status == .active }
            }
        }
        
        // Load backend ID mapping
        loadPolicyBackendIds()
    }
    
    /// Load policies from storage (legacy - now loads from cache)
    func loadPolicies() {
        isLoadingPolicies = true
        loadPoliciesFromCache()
        isLoadingPolicies = false
    }
    
    /// Save policies to local cache
    private func savePolicies() {
        if let encoded = try? JSONEncoder().encode(policies) {
            userDefaults.set(encoded, forKey: policiesKey)
        }
        
        if let activePolicy = activePolicy,
           let encoded = try? JSONEncoder().encode(activePolicy.id) {
            userDefaults.set(encoded, forKey: activePolicyKey)
        }
    }
    
    /// Save policy backend ID mapping
    private func savePolicyBackendIds() {
        let stringKeyDict = Dictionary(uniqueKeysWithValues: policyBackendIds.map { (key, value) in
            (key.uuidString, value)
        })
        if let encoded = try? JSONEncoder().encode(stringKeyDict) {
            userDefaults.set(encoded, forKey: policyBackendIdsKey)
        }
    }
    
    /// Load policy backend ID mapping
    private func loadPolicyBackendIds() {
        if let data = userDefaults.data(forKey: policyBackendIdsKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            policyBackendIds = Dictionary(uniqueKeysWithValues: decoded.compactMap { (key, value) -> (UUID, String)? in
                guard let uuid = UUID(uuidString: key) else { return nil }
                return (uuid, value)
            })
        }
    }
    
    /// Create a new policy from uploaded document
    func createPolicy(
        name: String,
        version: String,
        effectiveDate: Date,
        description: String,
        documentURL: URL
    ) async throws -> WorkplacePolicy {
        isProcessingDocument = true
        processingProgress = 0
        processingStatus = "Reading document..."
        
        defer {
            isProcessingDocument = false
            processingProgress = 0
            processingStatus = ""
        }
        
        // 1. Extract text from document
        processingProgress = 0.1
        let extractedText = try await extractTextFromDocument(url: documentURL)
        
        // 2. Create document source
        processingProgress = 0.3
        processingStatus = "Processing document..."
        
        let fileName = documentURL.lastPathComponent
        let fileType = documentURL.pathExtension.uppercased()
        
        let documentSource = PolicyDocumentSource(
            fileName: fileName,
            fileURL: documentURL.absoluteString,
            fileType: fileType,
            pageCount: countPages(url: documentURL),
            originalText: extractedText
        )
        
        // 3. Parse into sections
        processingProgress = 0.5
        processingStatus = "Analyzing structure..."
        
        let sections = await parsePolicySections(from: extractedText)
        
        // 4. Create policy
        processingProgress = 0.8
        processingStatus = "Saving policy..."
        
        var policy = WorkplacePolicy(
            name: name,
            version: version,
            effectiveDate: effectiveDate,
            status: .draft,
            description: description,
            documentSource: documentSource,
            sections: sections,
            organizationId: currentOrganizationId ?? "",
            createdBy: currentUserId ?? "",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // 5. Save policy locally first
        policies.append(policy)
        savePolicies()
        
        // 6. Sync to database
        if let userId = currentUserId, let orgId = currentOrganizationId {
            do {
                let created = try await policyService.createPolicy(
                    policy,
                    creatorId: userId,
                    organizationId: orgId,
                    facilityId: currentFacilityId
                )
                
                // Store backend ID mapping
                policyBackendIds[policy.id] = created.id
                savePolicyBackendIds()
                
                print("✅ Policy synced to database with ID: \(created.id)")
            } catch {
                policyError = "Failed to sync policy to database: \(error.localizedDescription)"
                print("Error syncing policy to database: \(error)")
            }
        }
        
        processingProgress = 1.0
        processingStatus = "Complete!"
        
        return policy
    }
    
    /// Activate a policy
    func activatePolicy(_ policy: WorkplacePolicy) async {
        // Deactivate current active policy
        if let currentActive = activePolicy {
            if let index = policies.firstIndex(where: { $0.id == currentActive.id }) {
                policies[index].status = .superseded
                
                // Sync to database
                if let backendId = policyBackendIds[currentActive.id] {
                    do {
                        _ = try await policyService.updatePolicy(id: backendId, updates: ["status": "SUPERSEDED"])
                    } catch {
                        print("Error updating superseded policy: \(error)")
                    }
                }
            }
        }
        
        // Activate the new policy
        if let index = policies.firstIndex(where: { $0.id == policy.id }) {
            policies[index].status = .active
            policies[index].updatedAt = Date()
            activePolicy = policies[index]
            
            // Sync to database
            if let backendId = policyBackendIds[policy.id] {
                do {
                    _ = try await policyService.updatePolicy(id: backendId, updates: ["status": "ACTIVE"])
                } catch {
                    print("Error updating active policy: \(error)")
                }
            }
        }
        
        savePolicies()
    }
    
    /// Delete a policy
    func deletePolicy(_ policy: WorkplacePolicy) async {
        // Delete from database first
        if let backendId = policyBackendIds[policy.id] {
            do {
                try await policyService.deletePolicy(id: backendId)
                policyBackendIds.removeValue(forKey: policy.id)
                savePolicyBackendIds()
            } catch {
                print("Error deleting policy from database: \(error)")
            }
        }
        
        // Remove locally
        policies.removeAll { $0.id == policy.id }
        if activePolicy?.id == policy.id {
            activePolicy = policies.first { $0.status == .active }
        }
        savePolicies()
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
            if let backendId = policyBackendIds[policy.id] {
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
                    if let sectionsData = try? JSONEncoder().encode(policy.sections),
                       let sectionsArray = try? JSONSerialization.jsonObject(with: sectionsData) {
                        updates["sections"] = sectionsArray
                    }
                }
                
                do {
                    _ = try await policyService.updatePolicy(id: backendId, updates: updates)
                    print("✅ Policy updated in database")
                } catch {
                    print("Error updating policy in database: \(error)")
                }
            }
        }
        savePolicies()
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
    
    // MARK: - Policy Section Parsing
    
    /// Parse policy text into structured sections
    private func parsePolicySections(from text: String) async -> [PolicySection] {
        var sections: [PolicySection] = []
        
        // Common section patterns
        let sectionPatterns = [
            #"(?m)^(\d+\.?\d*\.?\d*)\s+([A-Z][A-Za-z\s]+)$"#,  // "1.2.3 Section Title"
            #"(?m)^(Section|Article|Chapter)\s+(\d+)[:\s]*(.+)$"#,  // "Section 1: Title"
            #"(?m)^([A-Z][A-Z\s]+)$"#  // "ALL CAPS TITLE"
        ]
        
        // Split by common patterns
        let lines = text.components(separatedBy: .newlines)
        var currentSection: PolicySection?
        var currentContent = ""
        var orderIndex = 0
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Check if this line looks like a section header
            if isSectionHeader(trimmedLine) {
                // Save previous section
                if var section = currentSection {
                    section.content = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    sections.append(section)
                    currentContent = ""
                }
                
                // Start new section
                let (number, title) = parseSectionHeader(trimmedLine)
                let sectionType = detectSectionType(title: title, content: "")
                
                currentSection = PolicySection(
                    sectionNumber: number,
                    title: title,
                    content: "",
                    type: sectionType,
                    keywords: extractKeywords(from: title),
                    orderIndex: orderIndex
                )
                orderIndex += 1
            } else {
                currentContent += trimmedLine + "\n"
            }
        }
        
        // Save last section
        if var section = currentSection {
            section.content = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
            sections.append(section)
        }
        
        // If no sections detected, create a single "Full Policy" section
        if sections.isEmpty {
            sections.append(PolicySection(
                sectionNumber: "1",
                title: "Full Policy",
                content: text,
                type: .overview,
                orderIndex: 0
            ))
        }
        
        return sections
    }
    
    /// Check if a line looks like a section header
    private func isSectionHeader(_ line: String) -> Bool {
        // Numbered section (1.2.3 Title)
        if line.range(of: #"^\d+\.?\d*\.?\d*\s+[A-Z]"#, options: .regularExpression) != nil {
            return true
        }
        
        // "Section X" or "Article X"
        if line.range(of: #"^(Section|Article|Chapter)\s+\d+"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }
        
        // ALL CAPS line (likely a header)
        if line.count > 3 && line.count < 100 && line == line.uppercased() && line.contains(where: { $0.isLetter }) {
            return true
        }
        
        return false
    }
    
    /// Parse section header into number and title
    private func parseSectionHeader(_ line: String) -> (String, String) {
        // Try numbered format first
        if let match = line.range(of: #"^(\d+\.?\d*\.?\d*)\s+(.+)$"#, options: .regularExpression) {
            let fullMatch = String(line[match])
            let components = fullMatch.split(separator: " ", maxSplits: 1)
            if components.count >= 2 {
                return (String(components[0]), String(components[1]))
            }
        }
        
        // Try "Section X: Title" format
        if let match = line.range(of: #"^(Section|Article|Chapter)\s+(\d+)[:\s]*(.*)$"#, options: [.regularExpression, .caseInsensitive]) {
            let fullMatch = String(line[match])
            if let numberMatch = fullMatch.range(of: #"\d+"#, options: .regularExpression) {
                let number = String(fullMatch[numberMatch])
                let title = fullMatch.replacingOccurrences(of: #"(Section|Article|Chapter)\s+\d+[:\s]*"#, with: "", options: [.regularExpression, .caseInsensitive])
                return (number, title.isEmpty ? line : title)
            }
        }
        
        // Default: no number, line is the title
        return ("", line)
    }
    
    /// Detect section type based on title and content
    private func detectSectionType(title: String, content: String) -> PolicySectionType {
        let lowercaseTitle = title.lowercased()
        
        if lowercaseTitle.contains("overview") || lowercaseTitle.contains("introduction") || lowercaseTitle.contains("purpose") {
            return .overview
        }
        if lowercaseTitle.contains("definition") || lowercaseTitle.contains("terminology") {
            return .definitions
        }
        if lowercaseTitle.contains("guideline") || lowercaseTitle.contains("standard") || lowercaseTitle.contains("expectation") {
            return .guidelines
        }
        if lowercaseTitle.contains("procedure") || lowercaseTitle.contains("process") || lowercaseTitle.contains("step") {
            return .procedures
        }
        if lowercaseTitle.contains("violation") || lowercaseTitle.contains("misconduct") || lowercaseTitle.contains("prohibited") {
            return .violations
        }
        if lowercaseTitle.contains("consequence") || lowercaseTitle.contains("discipline") || lowercaseTitle.contains("action") || lowercaseTitle.contains("penalty") {
            return .consequences
        }
        if lowercaseTitle.contains("report") || lowercaseTitle.contains("complaint") || lowercaseTitle.contains("escalat") {
            return .reporting
        }
        if lowercaseTitle.contains("appeal") || lowercaseTitle.contains("grievance") || lowercaseTitle.contains("review") {
            return .appeals
        }
        
        return .other
    }
    
    /// Extract keywords from text using NaturalLanguage
    private func extractKeywords(from text: String) -> [String] {
        var keywords: [String] = []
        
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            if let tag = tag, tag == .noun || tag == .verb {
                let word = String(text[tokenRange]).lowercased()
                if word.count > 3 && !keywords.contains(word) {
                    keywords.append(word)
                }
            }
            return true
        }
        
        return Array(keywords.prefix(10))
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
            let remoteCases = try await caseService.fetchCases(organizationId: organizationId)
            cases = remoteCases.map { $0.toConflictCase() }
        } catch {
            caseError = "Failed to load cases: \(error.localizedDescription)"
            print("Error loading cases from database: \(error)")
            // Fall back to local cache
            loadCasesFromCache()
        }
        
        isLoadingCases = false
    }
    
    /// Load cases from local cache (fallback)
    private func loadCasesFromCache() {
        if let data = userDefaults.data(forKey: casesKey),
           let decoded = try? JSONDecoder().decode([ConflictCase].self, from: data) {
            cases = decoded
        }
    }
    
    /// Save cases to local cache (for offline support)
    private func saveCasesToCache() {
        if let encoded = try? JSONEncoder().encode(cases) {
            userDefaults.set(encoded, forKey: casesKey)
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
        saveCasesToCache()
        
        // Save to database
        print("🔍 Creating case - userId: \(currentUserId ?? "nil"), orgId: \(currentOrganizationId ?? "nil")")
        
        if let userId = currentUserId, !userId.isEmpty,
           let orgId = currentOrganizationId, !orgId.isEmpty {
            do {
                print("📤 Saving case to database...")
                
                // Look up backend policy ID from local UUID
                var backendPolicyId: String? = nil
                if let localPolicyId = newCase.activePolicyId {
                    backendPolicyId = policyBackendIds[localPolicyId]
                    print("🔍 Active policy lookup - local: \(localPolicyId), backend: \(backendPolicyId ?? "not found")")
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
                    saveCasesToCache()
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
            saveCasesToCache()
            
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
                    if !caseToUpdate.policyMatches.isEmpty,
                       let data = try? JSONEncoder().encode(caseToUpdate.policyMatches),
                       let json = try? JSONSerialization.jsonObject(with: data) {
                        updates["policyMatchesJson"] = json
                    }
                    if let actionDoc = caseToUpdate.generatedDocument,
                       let data = try? JSONEncoder().encode(actionDoc),
                       let json = try? JSONSerialization.jsonObject(with: data) {
                        updates["generatedActionDocJson"] = json
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
            saveCasesToCache()
            
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
        saveCasesToCache()
        
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
            saveCasesToCache()
            
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
            saveCasesToCache()
            
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
        saveCasesToCache()
        isLoadingCases = false
    }
    
    /// Finalize case and sync to database
    func finalizeCase(_ caseToClose: ConflictCase) async {
        await updateCaseStatus(caseToClose.id, to: .closed)
        
        // Update timestamp
        if let index = cases.firstIndex(where: { $0.id == caseToClose.id }) {
            cases[index].closedAt = Date()
            saveCasesToCache()
        }
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
