//
//  WorkplacePolicy.swift
//  MeetingIntelligence
//
//  Workplace Policy model for the Conflict Resolution Assistant
//

import Foundation
import SwiftUI

// MARK: - Policy Status
enum PolicyStatus: String, Codable, CaseIterable {
    case draft = "DRAFT"
    case active = "ACTIVE"
    case archived = "ARCHIVED"
    case superseded = "SUPERSEDED"
    
    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .active: return "Active"
        case .archived: return "Archived"
        case .superseded: return "Superseded"
        }
    }
    
    var color: Color {
        switch self {
        case .draft: return Color(hex: "6B7280")
        case .active: return Color(hex: "10B981")
        case .archived: return Color(hex: "F59E0B")
        case .superseded: return Color(hex: "EF4444")
        }
    }
}

// MARK: - Policy Section Type
enum PolicySectionType: String, Codable, CaseIterable {
    case overview = "OVERVIEW"
    case definitions = "DEFINITIONS"
    case guidelines = "GUIDELINES"
    case procedures = "PROCEDURES"
    case violations = "VIOLATIONS"
    case consequences = "CONSEQUENCES"
    case reporting = "REPORTING"
    case appeals = "APPEALS"
    case other = "OTHER"
    
    var displayName: String {
        switch self {
        case .overview: return "Overview"
        case .definitions: return "Definitions"
        case .guidelines: return "Guidelines"
        case .procedures: return "Procedures"
        case .violations: return "Violations"
        case .consequences: return "Consequences"
        case .reporting: return "Reporting"
        case .appeals: return "Appeals"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .overview: return "doc.text"
        case .definitions: return "book.closed"
        case .guidelines: return "list.bullet.clipboard"
        case .procedures: return "arrow.triangle.branch"
        case .violations: return "exclamationmark.triangle"
        case .consequences: return "hammer"
        case .reporting: return "megaphone"
        case .appeals: return "arrow.uturn.backward.circle"
        case .other: return "folder"
        }
    }
}

// MARK: - Policy Section
struct PolicySection: Identifiable, Codable, Hashable {
    let id: UUID
    var sectionNumber: String       // e.g., "3.2.1"
    var title: String
    var content: String
    var type: PolicySectionType
    var keywords: [String]          // For searchability
    var parentSectionId: UUID?      // For nested sections
    var orderIndex: Int
    
    init(
        id: UUID = UUID(),
        sectionNumber: String,
        title: String,
        content: String,
        type: PolicySectionType = .other,
        keywords: [String] = [],
        parentSectionId: UUID? = nil,
        orderIndex: Int = 0
    ) {
        self.id = id
        self.sectionNumber = sectionNumber
        self.title = title
        self.content = content
        self.type = type
        self.keywords = keywords
        self.parentSectionId = parentSectionId
        self.orderIndex = orderIndex
    }
    
    var displayTitle: String {
        if !sectionNumber.isEmpty {
            return "\(sectionNumber) \(title)"
        }
        return title
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PolicySection, rhs: PolicySection) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Policy Document Source
struct PolicyDocumentSource: Identifiable, Codable {
    let id: UUID
    var fileName: String
    var fileURL: String
    var fileType: String            // PDF, DOC, DOCX
    var uploadedAt: Date
    var pageCount: Int
    var originalText: String?       // Raw extracted text
    
    init(
        id: UUID = UUID(),
        fileName: String,
        fileURL: String,
        fileType: String,
        uploadedAt: Date = Date(),
        pageCount: Int = 0,
        originalText: String? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.fileURL = fileURL
        self.fileType = fileType
        self.uploadedAt = uploadedAt
        self.pageCount = pageCount
        self.originalText = originalText
    }
}

// MARK: - Workplace Policy (Main Model)
struct WorkplacePolicy: Identifiable, Codable {
    let id: UUID
    var name: String
    var version: String
    var effectiveDate: Date
    var expiryDate: Date?
    var status: PolicyStatus
    var description: String
    
    // Document Source
    var documentSource: PolicyDocumentSource?
    
    // Structured Sections
    var sections: [PolicySection]
    
    // Metadata
    var organizationId: String
    var createdBy: String
    var createdAt: Date
    var updatedAt: Date
    var lastReviewedAt: Date?
    var reviewedBy: String?
    
    // Processing Status
    var isProcessing: Bool
    var processingError: String?
    
    init(
        id: UUID = UUID(),
        name: String = "",
        version: String = "1.0",
        effectiveDate: Date = Date(),
        expiryDate: Date? = nil,
        status: PolicyStatus = .draft,
        description: String = "",
        documentSource: PolicyDocumentSource? = nil,
        sections: [PolicySection] = [],
        organizationId: String = "",
        createdBy: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastReviewedAt: Date? = nil,
        reviewedBy: String? = nil,
        isProcessing: Bool = false,
        processingError: String? = nil
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.effectiveDate = effectiveDate
        self.expiryDate = expiryDate
        self.status = status
        self.description = description
        self.documentSource = documentSource
        self.sections = sections
        self.organizationId = organizationId
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastReviewedAt = lastReviewedAt
        self.reviewedBy = reviewedBy
        self.isProcessing = isProcessing
        self.processingError = processingError
    }
    
    // MARK: - Computed Properties
    
    var isActive: Bool {
        status == .active
    }
    
    var isExpired: Bool {
        if let expiryDate = expiryDate {
            return expiryDate < Date()
        }
        return false
    }
    
    var sectionCount: Int {
        sections.count
    }
    
    var formattedEffectiveDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: effectiveDate)
    }
    
    var formattedExpiryDate: String? {
        guard let expiryDate = expiryDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: expiryDate)
    }
    
    // Get sections by type
    func sections(ofType type: PolicySectionType) -> [PolicySection] {
        sections.filter { $0.type == type }
    }
    
    // Search sections by keyword
    func searchSections(query: String) -> [PolicySection] {
        let lowercasedQuery = query.lowercased()
        return sections.filter { section in
            section.title.lowercased().contains(lowercasedQuery) ||
            section.content.lowercased().contains(lowercasedQuery) ||
            section.keywords.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }
    
    // Get top-level sections (no parent)
    var topLevelSections: [PolicySection] {
        sections.filter { $0.parentSectionId == nil }
            .sorted { $0.orderIndex < $1.orderIndex }
    }
    
    // Get child sections for a given parent
    func childSections(for parentId: UUID) -> [PolicySection] {
        sections.filter { $0.parentSectionId == parentId }
            .sorted { $0.orderIndex < $1.orderIndex }
    }
}

// MARK: - Policy Processing Result
struct PolicyProcessingResult {
    var extractedText: String
    var detectedSections: [PolicySection]
    var suggestedKeywords: [String: [String]]  // sectionId: keywords
    var processingTime: TimeInterval
    var confidence: Double
    
    init(
        extractedText: String = "",
        detectedSections: [PolicySection] = [],
        suggestedKeywords: [String: [String]] = [:],
        processingTime: TimeInterval = 0,
        confidence: Double = 0
    ) {
        self.extractedText = extractedText
        self.detectedSections = detectedSections
        self.suggestedKeywords = suggestedKeywords
        self.processingTime = processingTime
        self.confidence = confidence
    }
}
