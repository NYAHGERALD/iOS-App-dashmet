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
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        loadPolicies()
        loadCases()
    }
    
    // MARK: - Policy Management
    
    /// Load policies from storage
    func loadPolicies() {
        isLoadingPolicies = true
        
        if let data = userDefaults.data(forKey: policiesKey),
           let decoded = try? JSONDecoder().decode([WorkplacePolicy].self, from: data) {
            policies = decoded
            
            // Load active policy
            if let activePolicyData = userDefaults.data(forKey: activePolicyKey),
               let activeId = try? JSONDecoder().decode(UUID.self, from: activePolicyData) {
                activePolicy = policies.first { $0.id == activeId }
            } else {
                // Default to first active policy
                activePolicy = policies.first { $0.status == .active }
            }
        }
        
        isLoadingPolicies = false
    }
    
    /// Save policies to storage
    private func savePolicies() {
        if let encoded = try? JSONEncoder().encode(policies) {
            userDefaults.set(encoded, forKey: policiesKey)
        }
        
        if let activePolicy = activePolicy,
           let encoded = try? JSONEncoder().encode(activePolicy.id) {
            userDefaults.set(encoded, forKey: activePolicyKey)
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
            organizationId: "", // Will be set from app state
            createdBy: "", // Will be set from current user
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // 5. Save policy
        policies.append(policy)
        savePolicies()
        
        processingProgress = 1.0
        processingStatus = "Complete!"
        
        return policy
    }
    
    /// Activate a policy
    func activatePolicy(_ policy: WorkplacePolicy) {
        // Deactivate current active policy
        if let currentActive = activePolicy {
            if let index = policies.firstIndex(where: { $0.id == currentActive.id }) {
                policies[index].status = .superseded
            }
        }
        
        // Activate the new policy
        if let index = policies.firstIndex(where: { $0.id == policy.id }) {
            policies[index].status = .active
            policies[index].updatedAt = Date()
            activePolicy = policies[index]
        }
        
        savePolicies()
    }
    
    /// Delete a policy
    func deletePolicy(_ policy: WorkplacePolicy) {
        policies.removeAll { $0.id == policy.id }
        if activePolicy?.id == policy.id {
            activePolicy = policies.first { $0.status == .active }
        }
        savePolicies()
    }
    
    /// Update a policy
    func updatePolicy(_ policy: WorkplacePolicy) {
        if let index = policies.firstIndex(where: { $0.id == policy.id }) {
            policies[index] = policy
            policies[index].updatedAt = Date()
            
            if activePolicy?.id == policy.id {
                activePolicy = policies[index]
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
    
    // MARK: - Case Management
    
    /// Load cases from storage
    func loadCases() {
        isLoadingCases = true
        
        if let data = userDefaults.data(forKey: casesKey),
           let decoded = try? JSONDecoder().decode([ConflictCase].self, from: data) {
            cases = decoded
        }
        
        isLoadingCases = false
    }
    
    /// Save cases to storage
    private func saveCases() {
        if let encoded = try? JSONEncoder().encode(cases) {
            userDefaults.set(encoded, forKey: casesKey)
        }
    }
    
    /// Create a new case
    func createCase(
        type: CaseType,
        incidentDate: Date,
        location: String,
        department: String,
        shift: String?,
        involvedEmployees: [InvolvedEmployee]
    ) -> ConflictCase {
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
            createdBy: "", // Set from current user
            activePolicyId: activePolicy?.id
        )
        
        cases.insert(newCase, at: 0)
        currentCase = newCase
        saveCases()
        
        return newCase
    }
    
    /// Update a case
    func updateCase(_ updatedCase: ConflictCase) {
        if let index = cases.firstIndex(where: { $0.id == updatedCase.id }) {
            var caseToUpdate = updatedCase
            caseToUpdate.updatedAt = Date()
            cases[index] = caseToUpdate
            
            if currentCase?.id == updatedCase.id {
                currentCase = caseToUpdate
            }
            
            // Explicitly notify observers
            objectWillChange.send()
        }
        saveCases()
    }
    
    /// Delete a case
    func deleteCase(_ caseToDelete: ConflictCase) {
        cases.removeAll { $0.id == caseToDelete.id }
        if currentCase?.id == caseToDelete.id {
            currentCase = nil
        }
        objectWillChange.send()
        saveCases()
    }
    
    /// Add document to case
    func addDocument(to caseId: UUID, document: CaseDocument) {
        if let index = cases.firstIndex(where: { $0.id == caseId }) {
            var updatedCase = cases[index]
            updatedCase.documents.append(document)
            updatedCase.updatedAt = Date()
            
            // Add audit entry
            let auditEntry = CaseAuditEntry(
                action: "Document Added",
                details: "Added \(document.type.displayName)",
                userId: "",
                userName: "Supervisor"
            )
            updatedCase.auditLog.append(auditEntry)
            
            // Replace the case in the array to trigger @Published update
            cases[index] = updatedCase
            
            if currentCase?.id == caseId {
                currentCase = updatedCase
            }
            
            // Explicitly notify observers
            objectWillChange.send()
        }
        saveCases()
    }
    
    /// Delete document from case
    func deleteDocument(from caseId: UUID, documentId: UUID) {
        if let index = cases.firstIndex(where: { $0.id == caseId }) {
            var updatedCase = cases[index]
            if let docIndex = updatedCase.documents.firstIndex(where: { $0.id == documentId }) {
                let documentType = updatedCase.documents[docIndex].type.displayName
                updatedCase.documents.remove(at: docIndex)
                updatedCase.updatedAt = Date()
                
                // Add audit entry
                let auditEntry = CaseAuditEntry(
                    action: "Document Deleted",
                    details: "Removed \(documentType)",
                    userId: "",
                    userName: "Supervisor"
                )
                updatedCase.auditLog.append(auditEntry)
                
                // Replace case in array to trigger @Published update
                cases[index] = updatedCase
                
                if currentCase?.id == caseId {
                    currentCase = updatedCase
                }
                
                // Explicitly notify observers
                objectWillChange.send()
            }
        }
        saveCases()
    }
    
    /// Finalize and close a case
    func finalizeCase(_ caseToClose: ConflictCase) {
        if let index = cases.firstIndex(where: { $0.id == caseToClose.id }) {
            var updatedCase = cases[index]
            updatedCase.status = .closed
            updatedCase.closedAt = Date()
            updatedCase.updatedAt = Date()
            
            // Add audit entry
            let auditEntry = CaseAuditEntry(
                action: "Case Finalized",
                details: "Case closed and locked",
                userId: "",
                userName: "Supervisor"
            )
            updatedCase.auditLog.append(auditEntry)
            
            // Replace case in array to trigger @Published update
            cases[index] = updatedCase
            
            if currentCase?.id == caseToClose.id {
                currentCase = updatedCase
            }
            
            // Explicitly notify observers
            objectWillChange.send()
        }
        saveCases()
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
