//
//  CaseReportService.swift
//  MeetingIntelligence
//
//  Enterprise-Grade Professional Case Report Generation Service
//  Comprehensive PDF reports with full documentation
//

import Foundation
import UIKit
import PDFKit
import SwiftUI
import Combine

// MARK: - Report Configuration

struct ReportConfiguration {
    var includeExecutiveSummary: Bool = true
    var includeCaseDetails: Bool = true
    var includeInvolvedParties: Bool = true
    var includeDocumentSummary: Bool = true
    var includeFullStatements: Bool = true
    var includeScannedDocuments: Bool = true
    var includeAIAnalysis: Bool = true
    var includePolicyMatches: Bool = true
    var includeRecommendations: Bool = true
    var includeSelectedAction: Bool = true
    var includeGeneratedDocument: Bool = true
    var includeAuditTrail: Bool = true
    var includeSignatureBlocks: Bool = true
    var reportTitle: String = "Case Investigation Report"
    var confidentialityLevel: ReportConfidentialityLevel = .confidential
    var preparedBy: String = ""
    var preparedFor: String = ""
    
    static var full: ReportConfiguration { ReportConfiguration() }
    
    static var summary: ReportConfiguration {
        var config = ReportConfiguration()
        config.includeAuditTrail = false
        config.includeScannedDocuments = false
        config.includeFullStatements = false
        return config
    }
    
    static var executive: ReportConfiguration {
        var config = ReportConfiguration()
        config.includeFullStatements = false
        config.includeScannedDocuments = false
        config.includeAuditTrail = false
        config.includeDocumentSummary = true
        config.reportTitle = "Executive Case Summary"
        return config
    }
}

enum ReportConfidentialityLevel: String, CaseIterable {
    case confidential = "CONFIDENTIAL"
    case restricted = "RESTRICTED"
    case internalOnly = "INTERNAL USE ONLY"
    case hrOnly = "HR CONFIDENTIAL"
    
    var color: UIColor {
        switch self {
        case .confidential: return UIColor.systemRed
        case .restricted: return UIColor.systemOrange
        case .internalOnly: return UIColor.systemBlue
        case .hrOnly: return UIColor.systemPurple
        }
    }
}

struct ReportGenerationResult {
    let success: Bool
    let pdfData: Data?
    let pageCount: Int
    let generatedAt: Date
    let errorMessage: String?
    let reportId: UUID
    
    static func failure(_ message: String) -> ReportGenerationResult {
        ReportGenerationResult(success: false, pdfData: nil, pageCount: 0, generatedAt: Date(), errorMessage: message, reportId: UUID())
    }
}

// MARK: - Case Report Service

final class CaseReportService: ObservableObject {
    
    static let shared = CaseReportService()
    
    @Published var isGenerating: Bool = false
    @Published var generationProgress: Double = 0.0
    @Published var currentStep: String = ""
    
    // Page dimensions (A4)
    private let pageWidth: CGFloat = 595
    private let pageHeight: CGFloat = 842
    private let marginLeft: CGFloat = 50
    private let marginRight: CGFloat = 50
    private let marginTop: CGFloat = 60
    private let marginBottom: CGFloat = 50
    private var contentWidth: CGFloat { pageWidth - marginLeft - marginRight }
    private var contentHeight: CGFloat { pageHeight - marginTop - marginBottom }
    
    // Colors
    private let primaryColor = UIColor(red: 0.1, green: 0.3, blue: 0.6, alpha: 1.0)
    private let secondaryColor = UIColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1.0)
    private let accentColor = UIColor(red: 0.95, green: 0.95, blue: 0.98, alpha: 1.0)
    private let borderColor = UIColor(red: 0.85, green: 0.85, blue: 0.88, alpha: 1.0)
    private let textColor = UIColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1.0)
    private let subtleTextColor = UIColor(red: 0.4, green: 0.4, blue: 0.45, alpha: 1.0)
    
    // Formatters
    private let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy 'at' h:mm:ss a"
        return f
    }()
    
    private let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
    
    private let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy 'at' h:mm a"
        return f
    }()
    
    private init() {}
    
    // MARK: - Public API
    
    @MainActor
    func generateReport(for conflictCase: ConflictCase, configuration: ReportConfiguration = .full) async -> ReportGenerationResult {
        isGenerating = true
        generationProgress = 0.0
        currentStep = "Initializing..."
        
        defer {
            isGenerating = false
            generationProgress = 1.0
            currentStep = "Complete"
        }
        
        do {
            let pdfData = try await generatePDFReport(conflictCase: conflictCase, config: configuration)
            let pageCount = PDFDocument(data: pdfData)?.pageCount ?? 0
            return ReportGenerationResult(success: true, pdfData: pdfData, pageCount: pageCount, generatedAt: Date(), errorMessage: nil, reportId: UUID())
        } catch {
            return ReportGenerationResult.failure(error.localizedDescription)
        }
    }
    
    // MARK: - PDF Generation Core
    
    private func generatePDFReport(conflictCase: ConflictCase, config: ReportConfiguration) async throws -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        var totalPages = 1
        
        let data = renderer.pdfData { context in
            var currentY: CGFloat = marginTop
            var pageNumber = 1
            let facilityName = conflictCase.facilityName
            
            func newPage() {
                drawFooter(pageNumber: pageNumber, config: config, facilityName: facilityName)
                context.beginPage()
                pageNumber += 1
                totalPages = pageNumber
                drawHeader(config: config, caseNumber: conflictCase.caseNumber)
                currentY = marginTop + 35
            }
            
            func checkSpace(_ needed: CGFloat) {
                if currentY + needed > pageHeight - marginBottom - 20 {
                    newPage()
                }
            }
            
            // === PAGE 1: COVER PAGE ===
            context.beginPage()
            updateProgress(0.05, step: "Creating cover page...")
            currentY = drawCoverPage(conflictCase: conflictCase, config: config)
            
            // === PAGE 2+: TABLE OF CONTENTS ===
            newPage()
            updateProgress(0.08, step: "Building table of contents...")
            currentY = drawTableOfContents(y: currentY, config: config, conflictCase: conflictCase)
            
            // === EXECUTIVE SUMMARY ===
            if config.includeExecutiveSummary {
                newPage()
                updateProgress(0.12, step: "Writing executive summary...")
                currentY = drawSectionHeader("1. EXECUTIVE SUMMARY", y: currentY)
                currentY = drawExecutiveSummary(y: currentY, conflictCase: conflictCase, checkSpace: checkSpace)
            }
            
            // === CASE DETAILS ===
            if config.includeCaseDetails {
                newPage()
                updateProgress(0.18, step: "Documenting case details...")
                currentY = drawSectionHeader("2. CASE DETAILS", y: currentY)
                currentY = drawCaseDetails(y: currentY, conflictCase: conflictCase, checkSpace: checkSpace)
            }
            
            // === INVOLVED PARTIES ===
            if config.includeInvolvedParties {
                newPage()
                updateProgress(0.25, step: "Documenting involved parties...")
                currentY = drawSectionHeader("3. INVOLVED PARTIES", y: currentY)
                currentY = drawInvolvedParties(y: currentY, conflictCase: conflictCase, checkSpace: checkSpace, newPage: newPage)
            }
            
            // === FULL COMPLAINT STATEMENTS ===
            if config.includeFullStatements {
                newPage()
                updateProgress(0.35, step: "Including full statements...")
                currentY = drawSectionHeader("4. COMPLAINT STATEMENTS", y: currentY)
                currentY = drawFullStatements(y: currentY, conflictCase: conflictCase, checkSpace: checkSpace, newPage: newPage)
            }
            
            // === SCANNED DOCUMENTS ===
            if config.includeScannedDocuments {
                updateProgress(0.45, step: "Embedding scanned documents...")
                currentY = drawScannedDocumentsSection(y: currentY, conflictCase: conflictCase, checkSpace: checkSpace, newPage: newPage)
            }
            
            // === DASHMET INTELLIGENCE ANALYSIS ===
            if config.includeAIAnalysis, conflictCase.comparisonResult != nil {
                newPage()
                updateProgress(0.55, step: "Including DashMet Intelligence analysis...")
                currentY = drawSectionHeader("6. DASHMET INTELLIGENCE ANALYSIS RESULTS", y: currentY)
                currentY = drawAIAnalysis(y: currentY, conflictCase: conflictCase, checkSpace: checkSpace, newPage: newPage)
            }
            
            // === POLICY MATCHES ===
            if config.includePolicyMatches, !conflictCase.policyMatches.isEmpty {
                newPage()
                updateProgress(0.62, step: "Documenting policy matches...")
                currentY = drawSectionHeader("7. POLICY ALIGNMENTS", y: currentY)
                currentY = drawPolicyMatches(y: currentY, conflictCase: conflictCase, checkSpace: checkSpace, newPage: newPage)
            }
            
            // === RECOMMENDATIONS ===
            if config.includeRecommendations, !conflictCase.recommendations.isEmpty {
                newPage()
                updateProgress(0.68, step: "Recording recommendations...")
                currentY = drawSectionHeader("8. RECOMMENDED ACTIONS", y: currentY)
                currentY = drawRecommendations(y: currentY, conflictCase: conflictCase, checkSpace: checkSpace, newPage: newPage)
            }
            
            // === SELECTED ACTION & GENERATED DOCUMENT ===
            if config.includeSelectedAction || config.includeGeneratedDocument {
                newPage()
                updateProgress(0.75, step: "Documenting final action...")
                currentY = drawSectionHeader("9. SELECTED ACTION & DOCUMENTATION", y: currentY)
                currentY = drawSelectedAction(y: currentY, conflictCase: conflictCase, checkSpace: checkSpace, newPage: newPage)
            }
            
            // === SUPERVISOR NOTES & REVIEW COMMENTS ===
            if let supervisorNotes = conflictCase.supervisorNotes, !supervisorNotes.isEmpty {
                newPage()
                updateProgress(0.80, step: "Adding supervisor notes...")
                currentY = drawSectionHeader("10. SUPERVISOR NOTES & REVIEW COMMENTS", y: currentY)
                currentY = drawSupervisorNotes(y: currentY, notes: supervisorNotes, decision: conflictCase.supervisorDecision, checkSpace: checkSpace, newPage: newPage)
            }
            
            // === AUDIT TRAIL ===
            if config.includeAuditTrail, !conflictCase.auditLog.isEmpty {
                newPage()
                updateProgress(0.85, step: "Compiling audit trail...")
                currentY = drawSectionHeader("11. COMPLETE AUDIT TRAIL", y: currentY)
                currentY = drawAuditTrail(y: currentY, conflictCase: conflictCase, checkSpace: checkSpace, newPage: newPage)
            }
            
            // === SIGNATURE PAGE ===
            if config.includeSignatureBlocks {
                newPage()
                updateProgress(0.92, step: "Adding signature blocks...")
                currentY = drawSectionHeader("12. CERTIFICATIONS & SIGNATURES", y: currentY)
                currentY = drawSignatureBlocks(y: currentY, checkSpace: checkSpace)
            }
            
            // Final footer
            drawFooter(pageNumber: pageNumber, config: config, facilityName: facilityName)
            updateProgress(1.0, step: "Complete")
        }
        
        return data
    }
    
    private func updateProgress(_ progress: Double, step: String) {
        Task { @MainActor in
            self.generationProgress = progress
            self.currentStep = step
        }
    }
    
    // MARK: - Cover Page
    
    private func drawCoverPage(conflictCase: ConflictCase, config: ReportConfiguration) -> CGFloat {
        var y: CGFloat = 60
        
        // Professional gradient-like header background
        let headerRect = CGRect(x: 0, y: 0, width: pageWidth, height: 160)
        primaryColor.setFill()
        UIRectFill(headerRect)
        
        // Decorative accent stripe
        let accentStripe = CGRect(x: 0, y: 150, width: pageWidth, height: 10)
        secondaryColor.setFill()
        UIRectFill(accentStripe)
        
        // Facility name at top (if available)
        if let facilityName = conflictCase.facilityName, !facilityName.isEmpty {
            let facilityAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9)
            ]
            facilityName.uppercased().draw(at: CGPoint(x: marginLeft, y: 25), withAttributes: facilityAttrs)
        }
        
        // Main Title on header
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let title = config.reportTitle.uppercased()
        let titleSize = title.size(withAttributes: titleAttrs)
        title.draw(at: CGPoint(x: pageWidth/2 - titleSize.width/2, y: 65), withAttributes: titleAttrs)
        
        // Subtitle
        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.85)
        ]
        let subtitle = "Official Investigation Documentation"
        let subtitleSize = subtitle.size(withAttributes: subtitleAttrs)
        subtitle.draw(at: CGPoint(x: pageWidth/2 - subtitleSize.width/2, y: 105), withAttributes: subtitleAttrs)
        
        y = 185
        
        // Confidentiality Badge
        let confBadgeWidth: CGFloat = 200
        let confBadgeRect = CGRect(x: pageWidth/2 - confBadgeWidth/2, y: y, width: confBadgeWidth, height: 30)
        let confBadgePath = UIBezierPath(roundedRect: confBadgeRect, cornerRadius: 15)
        config.confidentialityLevel.color.setFill()
        confBadgePath.fill()
        
        let confAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let confText = "🔒 \(config.confidentialityLevel.rawValue)"
        let confSize = confText.size(withAttributes: confAttrs)
        confText.draw(at: CGPoint(x: pageWidth/2 - confSize.width/2, y: y + 8), withAttributes: confAttrs)
        y += 55
        
        // Case Number Box with professional styling
        let caseBoxRect = CGRect(x: marginLeft + 60, y: y, width: contentWidth - 120, height: 55)
        let caseBoxPath = UIBezierPath(roundedRect: caseBoxRect, cornerRadius: 10)
        UIColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1.0).setFill()
        caseBoxPath.fill()
        primaryColor.setStroke()
        caseBoxPath.lineWidth = 2
        caseBoxPath.stroke()
        
        // Case number icon and text
        let caseNumAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: primaryColor
        ]
        let caseNum = "📋 Case Number: \(conflictCase.caseNumber)"
        let caseNumSize = caseNum.size(withAttributes: caseNumAttrs)
        caseNum.draw(at: CGPoint(x: pageWidth/2 - caseNumSize.width/2, y: y + 16), withAttributes: caseNumAttrs)
        y += 80
        
        // Case Information Card
        let infoBoxRect = CGRect(x: marginLeft + 20, y: y, width: contentWidth - 40, height: 230)
        let infoBoxPath = UIBezierPath(roundedRect: infoBoxRect, cornerRadius: 12)
        UIColor.white.setFill()
        infoBoxPath.fill()
        
        // Subtle shadow effect
        let shadowPath = UIBezierPath(roundedRect: infoBoxRect.offsetBy(dx: 2, dy: 2), cornerRadius: 12)
        UIColor(white: 0.85, alpha: 0.5).setFill()
        shadowPath.fill()
        infoBoxPath.fill()
        
        borderColor.setStroke()
        infoBoxPath.lineWidth = 1
        infoBoxPath.stroke()
        
        // Info section header
        let sectionLabelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: primaryColor
        ]
        "CASE INFORMATION".draw(at: CGPoint(x: marginLeft + 35, y: y + 12), withAttributes: sectionLabelAttrs)
        
        // Divider under header
        let divider = UIBezierPath()
        divider.move(to: CGPoint(x: marginLeft + 35, y: y + 32))
        divider.addLine(to: CGPoint(x: pageWidth - marginRight - 35, y: y + 32))
        borderColor.setStroke()
        divider.lineWidth = 0.5
        divider.stroke()
        
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .semibold), .foregroundColor: subtleTextColor]
        let valueAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: textColor]
        
        let leftX = marginLeft + 40
        let rightX = pageWidth/2 + 10
        var infoY = y + 45
        
        let infoItems: [(String, String, String, String)] = [
            ("📁 CASE TYPE", conflictCase.type.displayName, "📊 STATUS", conflictCase.status.displayName),
            ("📅 INCIDENT DATE", shortDateFormatter.string(from: conflictCase.incidentDate), "🏢 DEPARTMENT", conflictCase.department),
            ("📍 LOCATION", conflictCase.location.isEmpty ? (conflictCase.facilityName ?? "Not Specified") : conflictCase.location, "⏰ SHIFT", conflictCase.shift ?? "Not Specified"),
            ("👤 CREATED BY", conflictCase.creatorName ?? "System", "📆 CREATED", shortDateFormatter.string(from: conflictCase.createdAt)),
            ("🔄 LAST UPDATED", shortDateFormatter.string(from: conflictCase.updatedAt), "👥 PARTIES", "\(conflictCase.involvedEmployees.count) person(s)")
        ]
        
        for item in infoItems {
            item.0.draw(at: CGPoint(x: leftX, y: infoY), withAttributes: labelAttrs)
            item.1.draw(at: CGPoint(x: leftX, y: infoY + 13), withAttributes: valueAttrs)
            item.2.draw(at: CGPoint(x: rightX, y: infoY), withAttributes: labelAttrs)
            item.3.draw(at: CGPoint(x: rightX, y: infoY + 13), withAttributes: valueAttrs)
            infoY += 36
        }
        
        y += 255
        
        // Prepared By Section at bottom with professional styling
        let prepY: CGFloat = pageHeight - 170
        
        // Preparer information box
        let prepBoxRect = CGRect(x: marginLeft, y: prepY - 10, width: contentWidth, height: 110)
        let prepBoxPath = UIBezierPath(roundedRect: prepBoxRect, cornerRadius: 8)
        UIColor(red: 0.98, green: 0.98, blue: 1.0, alpha: 1.0).setFill()
        prepBoxPath.fill()
        
        let prepLabelAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .semibold), .foregroundColor: primaryColor]
        let prepValueAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: textColor]
        
        // Use creator name as preparer if no explicit preparedBy is set
        let preparerName = config.preparedBy.isEmpty ? (conflictCase.creatorName ?? "System") : config.preparedBy
        
        "📝 PREPARED BY".draw(at: CGPoint(x: marginLeft + 15, y: prepY + 5), withAttributes: prepLabelAttrs)
        preparerName.draw(at: CGPoint(x: marginLeft + 15, y: prepY + 20), withAttributes: prepValueAttrs)
        
        "🕐 REPORT GENERATED".draw(at: CGPoint(x: marginLeft + 15, y: prepY + 50), withAttributes: prepLabelAttrs)
        fullDateFormatter.string(from: Date()).draw(at: CGPoint(x: marginLeft + 15, y: prepY + 65), withAttributes: prepValueAttrs)
        
        if !config.preparedFor.isEmpty {
            "📨 PREPARED FOR".draw(at: CGPoint(x: pageWidth/2, y: prepY + 5), withAttributes: prepLabelAttrs)
            config.preparedFor.draw(at: CGPoint(x: pageWidth/2, y: prepY + 20), withAttributes: prepValueAttrs)
        }
        
        // Department info if available
        if !conflictCase.department.isEmpty {
            "🏛️ DEPARTMENT".draw(at: CGPoint(x: pageWidth/2, y: prepY + 50), withAttributes: prepLabelAttrs)
            conflictCase.department.draw(at: CGPoint(x: pageWidth/2, y: prepY + 65), withAttributes: prepValueAttrs)
        }
        
        // Bottom decorative line
        let bottomLine = UIBezierPath()
        bottomLine.move(to: CGPoint(x: marginLeft, y: pageHeight - 60))
        bottomLine.addLine(to: CGPoint(x: pageWidth - marginRight, y: pageHeight - 60))
        primaryColor.setStroke()
        bottomLine.lineWidth = 3
        bottomLine.stroke()
        
        return y
    }
    
    // MARK: - Header & Footer
    
    private func drawHeader(config: ReportConfiguration, caseNumber: String) {
        let headerY: CGFloat = 20
        
        // Left: Confidentiality
        let leftAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .bold),
            .foregroundColor: config.confidentialityLevel.color
        ]
        config.confidentialityLevel.rawValue.draw(at: CGPoint(x: marginLeft, y: headerY), withAttributes: leftAttrs)
        
        // Center: Case Number
        let centerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .medium),
            .foregroundColor: subtleTextColor
        ]
        let centerText = "Case #\(caseNumber)"
        let centerSize = centerText.size(withAttributes: centerAttrs)
        centerText.draw(at: CGPoint(x: pageWidth/2 - centerSize.width/2, y: headerY), withAttributes: centerAttrs)
        
        // Header line
        let line = UIBezierPath()
        line.move(to: CGPoint(x: marginLeft, y: headerY + 18))
        line.addLine(to: CGPoint(x: pageWidth - marginRight, y: headerY + 18))
        borderColor.setStroke()
        line.lineWidth = 0.5
        line.stroke()
    }
    
    private func drawFooter(pageNumber: Int, config: ReportConfiguration, facilityName: String? = nil) {
        let footerY = pageHeight - 35
        
        // Footer line
        let line = UIBezierPath()
        line.move(to: CGPoint(x: marginLeft, y: footerY - 10))
        line.addLine(to: CGPoint(x: pageWidth - marginRight, y: footerY - 10))
        borderColor.setStroke()
        line.lineWidth = 0.5
        line.stroke()
        
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .regular),
            .foregroundColor: subtleTextColor
        ]
        
        // Left: Generated info
        let leftText = "Generated by DashMet Intelligence • \(timestampFormatter.string(from: Date()))"
        leftText.draw(at: CGPoint(x: marginLeft, y: footerY), withAttributes: footerAttrs)
        
        // Right: Page number
        let pageText = "Page \(pageNumber)"
        let pageSize = pageText.size(withAttributes: footerAttrs)
        pageText.draw(at: CGPoint(x: pageWidth - marginRight - pageSize.width, y: footerY), withAttributes: footerAttrs)
    }
    
    // MARK: - Section Header
    
    private func drawSectionHeader(_ title: String, y: CGFloat) -> CGFloat {
        var currentY = y
        
        // Section header background
        let headerRect = CGRect(x: marginLeft, y: currentY, width: contentWidth, height: 32)
        let headerPath = UIBezierPath(roundedRect: headerRect, cornerRadius: 4)
        primaryColor.setFill()
        headerPath.fill()
        
        // Section title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        title.draw(at: CGPoint(x: marginLeft + 15, y: currentY + 8), withAttributes: titleAttrs)
        
        return currentY + 45
    }
    
    // MARK: - Table of Contents
    
    private func drawTableOfContents(y: CGFloat, config: ReportConfiguration, conflictCase: ConflictCase) -> CGFloat {
        var currentY = y
        
        // TOC Header
        currentY = drawSectionHeader("TABLE OF CONTENTS", y: currentY)
        currentY += 10
        
        let tocItems: [(String, Bool)] = [
            ("1. Executive Summary", config.includeExecutiveSummary),
            ("2. Case Details", config.includeCaseDetails),
            ("3. Involved Parties", config.includeInvolvedParties),
            ("4. Complaint Statements (Full Text)", config.includeFullStatements),
            ("5. Scanned Documents & Evidence", config.includeScannedDocuments),
            ("6. DashMet Intelligence Analysis Results", config.includeAIAnalysis && conflictCase.comparisonResult != nil),
            ("7. Policy Alignments", config.includePolicyMatches && !conflictCase.policyMatches.isEmpty),
            ("8. Recommended Actions", config.includeRecommendations && !conflictCase.recommendations.isEmpty),
            ("9. Selected Action & Documentation", config.includeSelectedAction || config.includeGeneratedDocument),
            ("10. Complete Audit Trail", config.includeAuditTrail && !conflictCase.auditLog.isEmpty),
            ("11. Certifications & Signatures", config.includeSignatureBlocks)
        ]
        
        let numAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: primaryColor]
        let textAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11, weight: .regular), .foregroundColor: textColor]
        let excludedAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11, weight: .regular), .foregroundColor: UIColor.lightGray]
        
        for (item, included) in tocItems {
            let attrs = included ? textAttrs : excludedAttrs
            
            // Draw bullet
            if included {
                let bullet = "●"
                bullet.draw(at: CGPoint(x: marginLeft + 10, y: currentY), withAttributes: numAttrs)
            }
            
            // Draw item
            let displayText = included ? item : "\(item) (Not Included)"
            displayText.draw(at: CGPoint(x: marginLeft + 30, y: currentY), withAttributes: attrs)
            
            // Draw dotted line to page indicator
            if included {
                let dotsStart = marginLeft + 320
                let dotsEnd = pageWidth - marginRight - 30
                var dotX = dotsStart
                while dotX < dotsEnd {
                    ".".draw(at: CGPoint(x: dotX, y: currentY), withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: borderColor])
                    dotX += 6
                }
            }
            
            currentY += 24
        }
        
        return currentY + 20
    }
    
    // MARK: - Executive Summary
    
    private func drawExecutiveSummary(y: CGFloat, conflictCase: ConflictCase, checkSpace: (CGFloat) -> Void) -> CGFloat {
        var currentY = y
        
        let summaryText = generateExecutiveSummaryText(conflictCase: conflictCase)
        currentY = drawParagraph(summaryText, y: currentY, checkSpace: checkSpace)
        
        // Key metrics box
        checkSpace(120)
        currentY += 15
        
        let metricsRect = CGRect(x: marginLeft, y: currentY, width: contentWidth, height: 100)
        let metricsPath = UIBezierPath(roundedRect: metricsRect, cornerRadius: 8)
        accentColor.setFill()
        metricsPath.fill()
        borderColor.setStroke()
        metricsPath.lineWidth = 1
        metricsPath.stroke()
        
        // Metrics title
        let metricsTitleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .bold), .foregroundColor: primaryColor]
        "KEY METRICS".draw(at: CGPoint(x: marginLeft + 15, y: currentY + 10), withAttributes: metricsTitleAttrs)
        
        // Metrics values
        let metricLabelAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .medium), .foregroundColor: subtleTextColor]
        let metricValueAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 16, weight: .bold), .foregroundColor: primaryColor]
        
        let metricWidth = (contentWidth - 30) / 5
        let metrics: [(String, String)] = [
            ("Documents", "\(conflictCase.documents.count)"),
            ("Parties", "\(conflictCase.involvedEmployees.count)"),
            ("Witnesses", "\(conflictCase.witnesses.count)"),
            ("Policy Matches", "\(conflictCase.policyMatches.count)"),
            ("Audit Entries", "\(conflictCase.auditLog.count)")
        ]
        
        for (index, metric) in metrics.enumerated() {
            let x = marginLeft + 15 + CGFloat(index) * metricWidth
            metric.1.draw(at: CGPoint(x: x, y: currentY + 40), withAttributes: metricValueAttrs)
            metric.0.draw(at: CGPoint(x: x, y: currentY + 65), withAttributes: metricLabelAttrs)
        }
        
        return currentY + 120
    }
    
    private func generateExecutiveSummaryText(conflictCase: ConflictCase) -> String {
        var parts: [String] = []
        
        parts.append("This comprehensive investigation report documents Case \(conflictCase.caseNumber), classified as a \(conflictCase.type.displayName.lowercased()) matter. The incident occurred on \(shortDateFormatter.string(from: conflictCase.incidentDate)) within the \(conflictCase.department) department at \(conflictCase.location).")
        
        let complainants = conflictCase.involvedEmployees.filter { $0.isComplainant }
        let witnesses = conflictCase.witnesses
        
        if complainants.count >= 2 {
            parts.append("The primary parties involved are \(complainants[0].name) (\(complainants[0].role.isEmpty ? "Employee" : complainants[0].role)) and \(complainants[1].name) (\(complainants[1].role.isEmpty ? "Employee" : complainants[1].role)).")
        } else if complainants.count == 1 {
            parts.append("The primary complainant is \(complainants[0].name) (\(complainants[0].role.isEmpty ? "Employee" : complainants[0].role)).")
        }
        
        if !witnesses.isEmpty {
            parts.append("\(witnesses.count) witness statement(s) have been collected and documented.")
        }
        
        parts.append("\(conflictCase.documents.count) document(s) have been submitted as part of this investigation, including complaints, statements, and supporting evidence.")
        
        if let comparison = conflictCase.comparisonResult {
            parts.append("AI-assisted analysis identified \(comparison.agreementPoints.count) point(s) of agreement, \(comparison.contradictions.count) contradiction(s), and \(comparison.timelineDifferences.count) timeline discrepancy(ies) between the statements provided.")
        }
        
        if !conflictCase.policyMatches.isEmpty {
            parts.append("\(conflictCase.policyMatches.count) relevant company policy section(s) have been identified as applicable to this case.")
        }
        
        if let action = conflictCase.selectedAction {
            parts.append("Based on comprehensive analysis and supervisory review, the recommended course of action is: \(action.displayName). \(action.description)")
        }
        
        parts.append("The case is currently in '\(conflictCase.status.displayName)' status as of \(fullDateFormatter.string(from: conflictCase.updatedAt)).")
        
        return parts.joined(separator: "\n\n")
    }
    
    // MARK: - Case Details
    
    private func drawCaseDetails(y: CGFloat, conflictCase: ConflictCase, checkSpace: (CGFloat) -> Void) -> CGFloat {
        var currentY = y
        
        // Case description
        currentY = drawSubsectionHeader("Case Description", y: currentY)
        currentY = drawParagraph(conflictCase.description.isEmpty ? "No description provided." : conflictCase.description, y: currentY, checkSpace: checkSpace)
        currentY += 15
        
        // Detailed information table
        checkSpace(280)
        currentY = drawSubsectionHeader("Detailed Case Information", y: currentY)
        
        let details: [(String, String)] = [
            ("Case Reference Number", conflictCase.caseNumber),
            ("Case Classification", conflictCase.type.displayName),
            ("Current Status", conflictCase.status.displayName),
            ("Incident Date", shortDateFormatter.string(from: conflictCase.incidentDate)),
            ("Incident Location", conflictCase.location),
            ("Department/Unit", conflictCase.department),
            ("Work Shift", conflictCase.shift ?? "Not Specified"),
            ("Case Created By", conflictCase.createdBy.isEmpty ? "System" : conflictCase.createdBy),
            ("Case Creation Date", fullDateFormatter.string(from: conflictCase.createdAt)),
            ("Last Modified", fullDateFormatter.string(from: conflictCase.updatedAt)),
            ("Total Documents", "\(conflictCase.documents.count)"),
            ("Total Parties Involved", "\(conflictCase.involvedEmployees.count)"),
            ("Witness Statements", "\(conflictCase.witnessStatements.count)"),
            ("DashMet Intelligence Analysis Completed", conflictCase.comparisonResult != nil ? "Yes" : "No"),
            ("Policy Matches Found", "\(conflictCase.policyMatches.count)"),
            ("Recommendations Generated", "\(conflictCase.recommendations.count)"),
            ("Selected Action", conflictCase.selectedAction?.displayName ?? "Pending"),
            ("Case Closure Date", conflictCase.closedAt != nil ? fullDateFormatter.string(from: conflictCase.closedAt!) : "N/A")
        ]
        
        currentY = drawDetailTable(details, y: currentY, checkSpace: checkSpace)
        
        return currentY + 10
    }
    
    // MARK: - Involved Parties
    
    private func drawInvolvedParties(y: CGFloat, conflictCase: ConflictCase, checkSpace: (CGFloat) -> Void, newPage: () -> Void) -> CGFloat {
        var currentY = y
        
        let complainants = conflictCase.involvedEmployees.filter { $0.isComplainant }
        let witnesses = conflictCase.witnesses
        
        // Primary Parties
        currentY = drawSubsectionHeader("Primary Parties (\(complainants.count))", y: currentY)
        
        for (index, person) in complainants.enumerated() {
            checkSpace(140)
            currentY = drawPersonCard(person, index: index + 1, role: "Primary Party", y: currentY, conflictCase: conflictCase)
            currentY += 10
        }
        
        // Witnesses
        if !witnesses.isEmpty {
            currentY += 15
            currentY = drawSubsectionHeader("Witnesses (\(witnesses.count))", y: currentY)
            
            for (index, person) in witnesses.enumerated() {
                checkSpace(140)
                currentY = drawPersonCard(person, index: index + 1, role: "Witness", y: currentY, conflictCase: conflictCase)
                currentY += 10
            }
        }
        
        return currentY
    }
    
    private func drawPersonCard(_ person: InvolvedEmployee, index: Int, role: String, y: CGFloat, conflictCase: ConflictCase) -> CGFloat {
        var currentY = y
        
        // Card background
        let cardRect = CGRect(x: marginLeft, y: currentY, width: contentWidth, height: 125)
        let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 8)
        UIColor.white.setFill()
        cardPath.fill()
        borderColor.setStroke()
        cardPath.lineWidth = 1
        cardPath.stroke()
        
        // Role indicator bar
        let roleColor: UIColor = role == "Primary Party" ? UIColor.systemBlue : UIColor.systemGreen
        let roleBar = CGRect(x: marginLeft, y: currentY, width: 5, height: 125)
        let roleBarPath = UIBezierPath(roundedRect: roleBar, byRoundingCorners: [.topLeft, .bottomLeft], cornerRadii: CGSize(width: 8, height: 8))
        roleColor.setFill()
        roleBarPath.fill()
        
        let nameAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 14, weight: .bold), .foregroundColor: textColor]
        let roleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .semibold), .foregroundColor: roleColor]
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .medium), .foregroundColor: subtleTextColor]
        let valueAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .regular), .foregroundColor: textColor]
        
        var infoY = currentY + 12
        let leftCol = marginLeft + 20
        let rightCol = marginLeft + contentWidth/2
        
        // Name and role badge
        person.name.draw(at: CGPoint(x: leftCol, y: infoY), withAttributes: nameAttrs)
        
        let badgeText = "\(role) #\(index)"
        let badgeWidth = badgeText.size(withAttributes: roleAttrs).width + 16
        let badgeRect = CGRect(x: leftCol + person.name.size(withAttributes: nameAttrs).width + 10, y: infoY, width: badgeWidth, height: 18)
        let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: 9)
        roleColor.withAlphaComponent(0.15).setFill()
        badgePath.fill()
        badgeText.draw(at: CGPoint(x: badgeRect.minX + 8, y: infoY + 2), withAttributes: roleAttrs)
        
        infoY += 30
        
        // Details grid
        "Employee ID:".draw(at: CGPoint(x: leftCol, y: infoY), withAttributes: labelAttrs)
        (person.employeeId ?? "Not Provided").draw(at: CGPoint(x: leftCol + 70, y: infoY), withAttributes: valueAttrs)
        
        "Department:".draw(at: CGPoint(x: rightCol, y: infoY), withAttributes: labelAttrs)
        person.department.draw(at: CGPoint(x: rightCol + 70, y: infoY), withAttributes: valueAttrs)
        
        infoY += 20
        
        "Job Title/Role:".draw(at: CGPoint(x: leftCol, y: infoY), withAttributes: labelAttrs)
        (person.role.isEmpty ? "Not Specified" : person.role).draw(at: CGPoint(x: leftCol + 70, y: infoY), withAttributes: valueAttrs)
        
        "Party Type:".draw(at: CGPoint(x: rightCol, y: infoY), withAttributes: labelAttrs)
        (person.isComplainant ? "Complainant" : "Witness").draw(at: CGPoint(x: rightCol + 70, y: infoY), withAttributes: valueAttrs)
        
        infoY += 20
        
        // Check for associated documents - improved detection logic
        // For complainants: check complaintA/complaintB documents based on index
        // For witnesses: check witness statements with matching employeeId
        var hasStatement = false
        var hasSignature = false
        
        if person.isComplainant {
            // Check if this is complainant A (first) or B (second)
            let complainants = conflictCase.involvedEmployees.filter { $0.isComplainant }
            if let index = complainants.firstIndex(where: { $0.id == person.id }) {
                if index == 0 {
                    // Complainant A
                    if let docA = conflictCase.documents.first(where: { $0.type == .complaintA }) {
                        hasStatement = !docA.cleanedText.isEmpty || !docA.originalText.isEmpty || !docA.originalImageURLs.isEmpty
                        hasSignature = docA.signatureImageBase64 != nil && !docA.signatureImageBase64!.isEmpty
                    }
                } else if index == 1 {
                    // Complainant B
                    if let docB = conflictCase.documents.first(where: { $0.type == .complaintB }) {
                        hasStatement = !docB.cleanedText.isEmpty || !docB.originalText.isEmpty || !docB.originalImageURLs.isEmpty
                        hasSignature = docB.signatureImageBase64 != nil && !docB.signatureImageBase64!.isEmpty
                    }
                }
            }
        } else {
            // ROBUST witness document matching - try multiple strategies
            let witnessStatements = conflictCase.witnessStatements
            let witnesses = conflictCase.witnesses
            
            var witnessDoc: CaseDocument? = nil
            
            // Strategy 1: Match by employeeId (UUID match)
            witnessDoc = witnessStatements.first { doc in
                doc.employeeId == person.id
            }
            
            // Strategy 2: Match by submittedBy name (case-insensitive)
            if witnessDoc == nil {
                witnessDoc = witnessStatements.first { doc in
                    doc.submittedBy?.lowercased() == person.name.lowercased()
                }
            }
            
            // Strategy 3: Match by submittedById against person's employeeId (string ID like "53647")
            if witnessDoc == nil, let personEmployeeIdString = person.employeeId {
                witnessDoc = witnessStatements.first { doc in
                    doc.submittedById == personEmployeeIdString
                }
            }
            
            // Strategy 4: Match by index (if same count of witnesses and witness statements)
            if witnessDoc == nil, witnessStatements.count == witnesses.count {
                if let witnessIndex = witnesses.firstIndex(where: { $0.id == person.id }) {
                    witnessDoc = witnessStatements[witnessIndex]
                }
            }
            
            // Strategy 5: For single witness with single statement, assume match
            if witnessDoc == nil, witnessStatements.count == 1, witnesses.count == 1 {
                witnessDoc = witnessStatements.first
            }
            
            if let doc = witnessDoc {
                hasStatement = !doc.cleanedText.isEmpty || !doc.originalText.isEmpty || !doc.originalImageURLs.isEmpty
                hasSignature = doc.signatureImageBase64 != nil && !doc.signatureImageBase64!.isEmpty
            }
        }
        
        "Statement Submitted:".draw(at: CGPoint(x: leftCol, y: infoY), withAttributes: labelAttrs)
        let statText = hasStatement ? "Yes ✓" : "No"
        let statAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .medium), .foregroundColor: hasStatement ? UIColor.systemGreen : UIColor.systemRed]
        statText.draw(at: CGPoint(x: leftCol + 100, y: infoY), withAttributes: statAttrs)
        
        "Digital Signature:".draw(at: CGPoint(x: rightCol, y: infoY), withAttributes: labelAttrs)
        let sigText = hasSignature ? "Captured ✓" : "Not Captured"
        let sigAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .medium), .foregroundColor: hasSignature ? UIColor.systemGreen : UIColor.systemOrange]
        sigText.draw(at: CGPoint(x: rightCol + 100, y: infoY), withAttributes: sigAttrs)
        
        return currentY + 125
    }
    
    // MARK: - Full Statements
    
    private func drawFullStatements(y: CGFloat, conflictCase: ConflictCase, checkSpace: (CGFloat) -> Void, newPage: () -> Void) -> CGFloat {
        var currentY = y
        
        // Complaint A
        if let docA = conflictCase.complaintDocumentA {
            currentY = drawStatementDocument(docA, title: "COMPLAINANT A STATEMENT", party: conflictCase.complainantA, y: currentY, checkSpace: checkSpace, newPage: newPage)
            currentY += 20
        }
        
        // Complaint B
        if let docB = conflictCase.complaintDocumentB {
            newPage()
            currentY = marginTop + 35
            currentY = drawStatementDocument(docB, title: "COMPLAINANT B STATEMENT", party: conflictCase.complainantB, y: currentY, checkSpace: checkSpace, newPage: newPage)
            currentY += 20
        }
        
        // Witness Statements
        for (index, statement) in conflictCase.witnessStatements.enumerated() {
            newPage()
            currentY = marginTop + 35
            
            // ROBUST witness matching - try multiple strategies
            var witness: InvolvedEmployee? = nil
            let witnesses = conflictCase.witnesses
            
            // Strategy 1: Match by employeeId (UUID match)
            witness = witnesses.first { $0.id == statement.employeeId }
            
            // Strategy 2: Match by submittedBy name (case-insensitive)
            if witness == nil, let submittedByName = statement.submittedBy {
                witness = witnesses.first { $0.name.lowercased() == submittedByName.lowercased() }
            }
            
            // Strategy 3: Match by submittedById against employee's string ID
            if witness == nil, let submittedById = statement.submittedById {
                witness = witnesses.first { $0.employeeId == submittedById }
            }
            
            // Strategy 4: Match by index position (if same count)
            if witness == nil, conflictCase.witnessStatements.count == witnesses.count {
                witness = witnesses[index]
            }
            
            // Strategy 5: Single witness with single statement
            if witness == nil, conflictCase.witnessStatements.count == 1, witnesses.count == 1 {
                witness = witnesses.first
            }
            
            currentY = drawStatementDocument(statement, title: "WITNESS STATEMENT #\(index + 1)", party: witness, y: currentY, checkSpace: checkSpace, newPage: newPage)
            currentY += 20
        }
        
        if conflictCase.documents.filter({ $0.type == .complaintA || $0.type == .complaintB || $0.type == .witnessStatement }).isEmpty {
            currentY = drawParagraph("No complaint statements have been submitted for this case.", y: currentY, checkSpace: checkSpace)
        }
        
        return currentY
    }
    
    private func drawStatementDocument(_ doc: CaseDocument, title: String, party: InvolvedEmployee?, y: CGFloat, checkSpace: (CGFloat) -> Void, newPage: () -> Void) -> CGFloat {
        var currentY = y
        
        // Statement header
        let headerRect = CGRect(x: marginLeft, y: currentY, width: contentWidth, height: 60)
        let headerPath = UIBezierPath(roundedRect: headerRect, cornerRadius: 8)
        accentColor.setFill()
        headerPath.fill()
        secondaryColor.setStroke()
        headerPath.lineWidth = 2
        headerPath.stroke()
        
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 13, weight: .bold), .foregroundColor: primaryColor]
        title.draw(at: CGPoint(x: marginLeft + 15, y: currentY + 10), withAttributes: titleAttrs)
        
        let metaAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .regular), .foregroundColor: subtleTextColor]
        // Use party name first, then submittedBy, then fallback by document type - NEVER "Anonymous"
        let partyName: String
        if let name = party?.name {
            partyName = name
        } else if let submitted = doc.submittedBy, !submitted.isEmpty {
            partyName = submitted
        } else {
            // Fallback based on document type - no "Unknown" or "Anonymous"
            switch doc.type {
            case .complaintA:
                partyName = "Complainant A"
            case .complaintB:
                partyName = "Complainant B"
            case .witnessStatement:
                partyName = "Witness"
            default:
                partyName = "Submitter"
            }
        }
        let metaText = "Submitted by: \(partyName) | Date: \(fullDateFormatter.string(from: doc.createdAt)) | Pages: \(doc.pageCount)"
        metaText.draw(at: CGPoint(x: marginLeft + 15, y: currentY + 32), withAttributes: metaAttrs)
        
        currentY += 75
        
        // Document metadata box
        checkSpace(80)
        let metaBoxRect = CGRect(x: marginLeft, y: currentY, width: contentWidth, height: 65)
        let metaBoxPath = UIBezierPath(roundedRect: metaBoxRect, cornerRadius: 6)
        UIColor.white.setFill()
        metaBoxPath.fill()
        borderColor.setStroke()
        metaBoxPath.lineWidth = 0.5
        metaBoxPath.stroke()
        
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8, weight: .semibold), .foregroundColor: subtleTextColor]
        let valueAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .regular), .foregroundColor: textColor]
        
        var metaY = currentY + 10
        let col1 = marginLeft + 15
        let col2 = marginLeft + contentWidth/3
        let col3 = marginLeft + 2*contentWidth/3
        
        "DOCUMENT TYPE".draw(at: CGPoint(x: col1, y: metaY), withAttributes: labelAttrs)
        doc.type.displayName.draw(at: CGPoint(x: col1, y: metaY + 12), withAttributes: valueAttrs)
        
        "LANGUAGE DETECTED".draw(at: CGPoint(x: col2, y: metaY), withAttributes: labelAttrs)
        (doc.detectedLanguage ?? "English").draw(at: CGPoint(x: col2, y: metaY + 12), withAttributes: valueAttrs)
        
        "HANDWRITTEN".draw(at: CGPoint(x: col3, y: metaY), withAttributes: labelAttrs)
        (doc.isHandwritten == true ? "Yes" : "No").draw(at: CGPoint(x: col3, y: metaY + 12), withAttributes: valueAttrs)
        
        metaY += 35
        
        if let reviewTime = doc.employeeReviewTimestamp {
            "REVIEWED".draw(at: CGPoint(x: col1, y: metaY), withAttributes: labelAttrs)
            timestampFormatter.string(from: reviewTime).draw(at: CGPoint(x: col1, y: metaY + 12), withAttributes: valueAttrs)
        }
        
        if let sigTime = doc.employeeSignatureTimestamp {
            "SIGNED".draw(at: CGPoint(x: col2, y: metaY), withAttributes: labelAttrs)
            timestampFormatter.string(from: sigTime).draw(at: CGPoint(x: col2, y: metaY + 12), withAttributes: valueAttrs)
        }
        
        currentY += 80
        
        // Full statement text - Use ORIGINAL text (not cleaned), plus translated text if available
        let originalStatement = doc.originalText
        let translatedStatement = doc.translatedText
        
        if originalStatement.isEmpty && (translatedStatement?.isEmpty ?? true) {
            currentY = drawSubsectionHeader("Statement Text", y: currentY)
            currentY = drawParagraph("[No text content available for this document]", y: currentY, checkSpace: checkSpace)
        } else {
            // Original Statement Section
            if !originalStatement.isEmpty {
                currentY = drawSubsectionHeader("Original Statement", y: currentY)
                currentY = drawFullText(originalStatement, y: currentY, checkSpace: checkSpace, newPage: newPage)
            }
            
            // Translated Statement Section (if exists)
            if let translated = translatedStatement, !translated.isEmpty {
                checkSpace(60)
                currentY = drawSubsectionHeader("Translated Statement", y: currentY)
                currentY = drawFullText(translated, y: currentY, checkSpace: checkSpace, newPage: newPage)
            }
        }
        
        // Signature if available
        if let sigBase64 = doc.signatureImageBase64, let sigData = Data(base64Encoded: sigBase64), let sigImage = UIImage(data: sigData) {
            checkSpace(100)
            currentY += 15
            currentY = drawSubsectionHeader("Digital Signature", y: currentY)
            
            let sigRect = CGRect(x: marginLeft + 20, y: currentY, width: 200, height: 60)
            sigImage.draw(in: sigRect)
            
            let sigLabelAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8, weight: .regular), .foregroundColor: subtleTextColor]
            if let sigTime = doc.employeeSignatureTimestamp {
                "Signed: \(fullDateFormatter.string(from: sigTime))".draw(at: CGPoint(x: marginLeft + 20, y: currentY + 65), withAttributes: sigLabelAttrs)
            }
            
            currentY += 85
        }
        
        return currentY
    }
    
    // MARK: - Scanned Documents
    
    private func drawScannedDocumentsSection(y: CGFloat, conflictCase: ConflictCase, checkSpace: (CGFloat) -> Void, newPage: () -> Void) -> CGFloat {
        var currentY = y
        
        newPage()
        currentY = marginTop + 35
        currentY = drawSectionHeader("5. SCANNED DOCUMENTS & EVIDENCE", y: currentY)
        
        if conflictCase.documents.isEmpty {
            return drawParagraph("No documents have been uploaded for this case.", y: currentY, checkSpace: checkSpace)
        }
        
        for (index, doc) in conflictCase.documents.enumerated() {
            checkSpace(100)
            currentY = drawDocumentEntry(doc, index: index + 1, y: currentY, checkSpace: checkSpace, conflictCase: conflictCase)
            
            // Embed original scanned image if available
            if let imageBase64 = doc.originalImageBase64, let imageData = Data(base64Encoded: imageBase64), let image = UIImage(data: imageData) {
                newPage()
                currentY = marginTop + 35
                currentY = drawEmbeddedImage(image, title: "\(doc.type.displayName) - Original Scan", docIndex: index + 1, y: currentY)
            }
            
            currentY += 10
        }
        
        return currentY
    }
    
    private func drawDocumentEntry(_ doc: CaseDocument, index: Int, y: CGFloat, checkSpace: (CGFloat) -> Void, conflictCase: ConflictCase) -> CGFloat {
        var currentY = y
        
        let entryRect = CGRect(x: marginLeft, y: currentY, width: contentWidth, height: 85)
        let entryPath = UIBezierPath(roundedRect: entryRect, cornerRadius: 6)
        UIColor.white.setFill()
        entryPath.fill()
        borderColor.setStroke()
        entryPath.lineWidth = 1
        entryPath.stroke()
        
        // Type indicator
        let typeColor: UIColor = UIColor(doc.type.color)
        let typeBar = CGRect(x: marginLeft, y: currentY, width: 5, height: 85)
        let typeBarPath = UIBezierPath(roundedRect: typeBar, byRoundingCorners: [.topLeft, .bottomLeft], cornerRadii: CGSize(width: 6, height: 6))
        typeColor.setFill()
        typeBarPath.fill()
        
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12, weight: .bold), .foregroundColor: textColor]
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8, weight: .semibold), .foregroundColor: subtleTextColor]
        let valueAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .regular), .foregroundColor: textColor]
        
        var infoY = currentY + 12
        let leftCol = marginLeft + 20
        let midCol = marginLeft + contentWidth/3
        let rightCol = marginLeft + 2*contentWidth/3
        
        "Document #\(index): \(doc.type.displayName)".draw(at: CGPoint(x: leftCol, y: infoY), withAttributes: titleAttrs)
        infoY += 22
        
        "SUBMITTED".draw(at: CGPoint(x: leftCol, y: infoY), withAttributes: labelAttrs)
        fullDateFormatter.string(from: doc.createdAt).draw(at: CGPoint(x: leftCol, y: infoY + 12), withAttributes: valueAttrs)
        
        "PAGES".draw(at: CGPoint(x: midCol, y: infoY), withAttributes: labelAttrs)
        "\(doc.pageCount)".draw(at: CGPoint(x: midCol, y: infoY + 12), withAttributes: valueAttrs)
        
        "HAS IMAGE".draw(at: CGPoint(x: rightCol, y: infoY), withAttributes: labelAttrs)
        let hasImage = doc.originalImageBase64 != nil || !doc.originalImageURLs.isEmpty
        let imageText = hasImage ? "Yes ✓" : "No"
        let imageAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .medium), .foregroundColor: hasImage ? UIColor.systemGreen : UIColor.systemOrange]
        imageText.draw(at: CGPoint(x: rightCol, y: infoY + 12), withAttributes: imageAttrs)
        
        infoY += 30
        
        // Resolve submitter name using robust matching
        var submitterName: String? = nil
        
        // Strategy 1: Use document type to get complainant name
        if doc.type == .complaintA {
            submitterName = conflictCase.complainantA?.name
        } else if doc.type == .complaintB {
            submitterName = conflictCase.complainantB?.name
        } else if doc.type == .witnessStatement {
            // Robust witness matching
            let witnesses = conflictCase.witnesses
            let witnessStatements = conflictCase.witnessStatements
            
            if let statementIndex = witnessStatements.firstIndex(where: { $0.id == doc.id }) {
                var matchedWitness: InvolvedEmployee? = nil
                
                // Strategy 1: Match by employeeId (UUID match)
                matchedWitness = witnesses.first { $0.id == doc.employeeId }
                
                // Strategy 2: Match by submittedBy name (case-insensitive, not identifier)
                if matchedWitness == nil, let submittedByName = doc.submittedBy {
                    // Check if it's not a Firebase ID
                    let isIdentifier = submittedByName.contains(":") || (submittedByName.count >= 32 && submittedByName.allSatisfy { $0.isHexDigit || $0 == "-" })
                    if !isIdentifier {
                        matchedWitness = witnesses.first { $0.name.lowercased() == submittedByName.lowercased() }
                    }
                }
                
                // Strategy 3: Match by submittedById against employee's string ID
                if matchedWitness == nil, let submittedById = doc.submittedById {
                    matchedWitness = witnesses.first { $0.employeeId == submittedById }
                }
                
                // Strategy 4: Match by index position (if same count)
                if matchedWitness == nil, witnessStatements.count == witnesses.count {
                    matchedWitness = witnesses[statementIndex]
                }
                
                // Strategy 5: Single witness with single statement
                if matchedWitness == nil, witnessStatements.count == 1, witnesses.count == 1 {
                    matchedWitness = witnesses.first
                }
                
                submitterName = matchedWitness?.name
            }
        }
        
        // Fallback to doc.submittedBy if not an identifier, or use document type
        if submitterName == nil {
            if let submitted = doc.submittedBy {
                let isIdentifier = submitted.contains(":") || (submitted.count >= 32 && submitted.allSatisfy { $0.isHexDigit || $0 == "-" })
                if !isIdentifier {
                    submitterName = submitted
                }
            }
        }
        
        // Final fallback by document type
        if submitterName == nil {
            switch doc.type {
            case .complaintA:
                submitterName = "Complainant A"
            case .complaintB:
                submitterName = "Complainant B"
            case .witnessStatement:
                submitterName = "Witness"
            default:
                submitterName = "Submitter"
            }
        }
        
        // Always show SUBMITTED BY
        "SUBMITTED BY".draw(at: CGPoint(x: leftCol, y: infoY), withAttributes: labelAttrs)
        submitterName!.draw(at: CGPoint(x: leftCol + 70, y: infoY), withAttributes: valueAttrs)
        
        return currentY + 85
    }
    
    private func drawEmbeddedImage(_ image: UIImage, title: String, docIndex: Int, y: CGFloat) -> CGFloat {
        var currentY = y
        
        // Title bar
        let titleRect = CGRect(x: marginLeft, y: currentY, width: contentWidth, height: 28)
        let titlePath = UIBezierPath(roundedRect: titleRect, cornerRadius: 4)
        secondaryColor.setFill()
        titlePath.fill()
        
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11, weight: .bold), .foregroundColor: UIColor.white]
        title.draw(at: CGPoint(x: marginLeft + 12, y: currentY + 6), withAttributes: titleAttrs)
        currentY += 35
        
        // Calculate image dimensions to fit within margins while preserving aspect ratio
        let maxWidth = contentWidth - 20
        let maxHeight = pageHeight - currentY - marginBottom - 40
        
        let aspectRatio = image.size.width / image.size.height
        var imageWidth = maxWidth
        var imageHeight = imageWidth / aspectRatio
        
        if imageHeight > maxHeight {
            imageHeight = maxHeight
            imageWidth = imageHeight * aspectRatio
        }
        
        // Center the image
        let imageX = marginLeft + (contentWidth - imageWidth) / 2
        
        // Border
        let borderRect = CGRect(x: imageX - 2, y: currentY - 2, width: imageWidth + 4, height: imageHeight + 4)
        let borderPath = UIBezierPath(roundedRect: borderRect, cornerRadius: 4)
        borderColor.setStroke()
        borderPath.lineWidth = 1
        borderPath.stroke()
        
        // Image
        let imageRect = CGRect(x: imageX, y: currentY, width: imageWidth, height: imageHeight)
        image.draw(in: imageRect)
        
        return currentY + imageHeight + 15
    }
    
    // MARK: - AI Analysis
    
    private func drawAIAnalysis(y: CGFloat, conflictCase: ConflictCase, checkSpace: (CGFloat) -> Void, newPage: () -> Void) -> CGFloat {
        guard let analysis = conflictCase.comparisonResult else { return y }
        var currentY = y
        
        // Analysis metadata
        let metaAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .regular), .foregroundColor: subtleTextColor]
        "Analysis Generated: \(fullDateFormatter.string(from: analysis.generatedAt))".draw(at: CGPoint(x: marginLeft, y: currentY), withAttributes: metaAttrs)
        currentY += 20
        
        // Metrics summary
        checkSpace(90)
        currentY = drawAnalysisMetrics(analysis, y: currentY)
        currentY += 20
        
        // Neutral Summary
        currentY = drawSubsectionHeader("Neutral Summary", y: currentY)
        currentY = drawFullText(analysis.neutralSummary, y: currentY, checkSpace: checkSpace, newPage: newPage)
        currentY += 15
        
        // Agreement Points
        if !analysis.agreementPoints.isEmpty {
            checkSpace(80)
            currentY = drawSubsectionHeader("Points of Agreement (\(analysis.agreementPoints.count))", y: currentY)
            for point in analysis.agreementPoints {
                currentY = drawBulletPoint(point, y: currentY, bulletColor: UIColor.systemGreen, checkSpace: checkSpace)
            }
            currentY += 10
        }
        
        // Contradictions
        if !analysis.contradictions.isEmpty {
            checkSpace(80)
            currentY = drawSubsectionHeader("Contradictions Identified (\(analysis.contradictions.count))", y: currentY)
            for point in analysis.contradictions {
                currentY = drawBulletPoint(point, y: currentY, bulletColor: UIColor.systemRed, checkSpace: checkSpace)
            }
            currentY += 10
        }
        
        // Timeline Differences
        if !analysis.timelineDifferences.isEmpty {
            checkSpace(80)
            currentY = drawSubsectionHeader("Timeline Discrepancies (\(analysis.timelineDifferences.count))", y: currentY)
            for point in analysis.timelineDifferences {
                currentY = drawBulletPoint(point, y: currentY, bulletColor: UIColor.systemOrange, checkSpace: checkSpace)
            }
            currentY += 10
        }
        
        // Missing Details
        if !analysis.missingDetails.isEmpty {
            checkSpace(80)
            currentY = drawSubsectionHeader("Missing Details (\(analysis.missingDetails.count))", y: currentY)
            for point in analysis.missingDetails {
                currentY = drawBulletPoint(point, y: currentY, bulletColor: UIColor.systemYellow, checkSpace: checkSpace)
            }
            currentY += 10
        }
        
        // Side-by-Side Comparison
        if !analysis.sideBySideComparison.isEmpty {
            newPage()
            currentY = marginTop + 35
            currentY = drawSubsectionHeader("Side-by-Side Comparison", y: currentY)
            currentY = drawSideBySideComparison(analysis.sideBySideComparison, partyA: analysis.partyAName, partyB: analysis.partyBName, y: currentY, checkSpace: checkSpace, newPage: newPage)
        }
        
        return currentY
    }
    
    private func drawAnalysisMetrics(_ analysis: AIComparisonResult, y: CGFloat) -> CGFloat {
        let metricsRect = CGRect(x: marginLeft, y: y, width: contentWidth, height: 70)
        let metricsPath = UIBezierPath(roundedRect: metricsRect, cornerRadius: 8)
        accentColor.setFill()
        metricsPath.fill()
        
        let metrics: [(String, Int, UIColor)] = [
            ("Agreements", analysis.agreementPoints.count, UIColor.systemGreen),
            ("Contradictions", analysis.contradictions.count, UIColor.systemRed),
            ("Timeline Issues", analysis.timelineDifferences.count, UIColor.systemOrange),
            ("Missing Details", analysis.missingDetails.count, UIColor.systemYellow)
        ]
        
        let metricWidth = contentWidth / CGFloat(metrics.count)
        
        for (index, metric) in metrics.enumerated() {
            let x = marginLeft + CGFloat(index) * metricWidth + 15
            
            let countAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 24, weight: .bold), .foregroundColor: metric.2]
            "\(metric.1)".draw(at: CGPoint(x: x, y: y + 15), withAttributes: countAttrs)
            
            let labelAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .medium), .foregroundColor: subtleTextColor]
            metric.0.draw(at: CGPoint(x: x, y: y + 48), withAttributes: labelAttrs)
        }
        
        return y + 70
    }
    
    private func drawSideBySideComparison(_ items: [SideBySideComparisonItem], partyA: String, partyB: String, y: CGFloat, checkSpace: (CGFloat) -> Void, newPage: () -> Void) -> CGFloat {
        var currentY = y
        
        for item in items {
            checkSpace(120)
            
            // Topic header
            let topicRect = CGRect(x: marginLeft, y: currentY, width: contentWidth, height: 24)
            let topicPath = UIBezierPath(roundedRect: topicRect, cornerRadius: 4)
            UIColor(item.status.color).withAlphaComponent(0.2).setFill()
            topicPath.fill()
            
            let topicAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .bold), .foregroundColor: UIColor(item.status.color)]
            "\(item.topic) — \(item.status.displayName)".draw(at: CGPoint(x: marginLeft + 10, y: currentY + 5), withAttributes: topicAttrs)
            currentY += 28
            
            // Two columns
            let colWidth = (contentWidth - 15) / 2
            let labelAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8, weight: .bold), .foregroundColor: subtleTextColor]
            
            partyA.uppercased().draw(at: CGPoint(x: marginLeft, y: currentY), withAttributes: labelAttrs)
            partyB.uppercased().draw(at: CGPoint(x: marginLeft + colWidth + 15, y: currentY), withAttributes: labelAttrs)
            currentY += 14
            
            let textAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .regular), .foregroundColor: textColor]
            
            // Draw wrapped text in columns (simplified)
            let partyAText = NSAttributedString(string: item.partyAVersion, attributes: textAttrs)
            let partyBText = NSAttributedString(string: item.partyBVersion, attributes: textAttrs)
            
            let partyARect = CGRect(x: marginLeft, y: currentY, width: colWidth, height: 80)
            let partyBRect = CGRect(x: marginLeft + colWidth + 15, y: currentY, width: colWidth, height: 80)
            
            partyAText.draw(in: partyARect)
            partyBText.draw(in: partyBRect)
            
            currentY += 90
        }
        
        return currentY
    }
    
    // MARK: - Policy Matches
    
    private func drawPolicyMatches(y: CGFloat, conflictCase: ConflictCase, checkSpace: (CGFloat) -> Void, newPage: () -> Void) -> CGFloat {
        var currentY = y
        
        for (index, match) in conflictCase.policyMatches.enumerated() {
            checkSpace(100)
            
            let cardRect = CGRect(x: marginLeft, y: currentY, width: contentWidth, height: 90)
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 8)
            UIColor.white.setFill()
            cardPath.fill()
            borderColor.setStroke()
            cardPath.lineWidth = 1
            cardPath.stroke()
            
            // Confidence indicator
            let confWidth = CGFloat(match.matchConfidence) * 80
            let confRect = CGRect(x: pageWidth - marginRight - 90, y: currentY + 10, width: confWidth, height: 6)
            let confPath = UIBezierPath(roundedRect: confRect, cornerRadius: 3)
            UIColor.systemGreen.setFill()
            confPath.fill()
            
            let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11, weight: .bold), .foregroundColor: primaryColor]
            let sectionAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .semibold), .foregroundColor: secondaryColor]
            let descAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .regular), .foregroundColor: textColor]
            let confAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8, weight: .medium), .foregroundColor: subtleTextColor]
            
            "Policy Match #\(index + 1)".draw(at: CGPoint(x: marginLeft + 12, y: currentY + 10), withAttributes: titleAttrs)
            "\(Int(match.matchConfidence * 100))% Match".draw(at: CGPoint(x: pageWidth - marginRight - 90, y: currentY + 20), withAttributes: confAttrs)
            
            "Section \(match.sectionNumber): \(match.sectionTitle)".draw(at: CGPoint(x: marginLeft + 12, y: currentY + 30), withAttributes: sectionAttrs)
            
            let relevanceText = NSAttributedString(string: match.relevanceExplanation, attributes: descAttrs)
            let relevanceRect = CGRect(x: marginLeft + 12, y: currentY + 48, width: contentWidth - 24, height: 35)
            relevanceText.draw(in: relevanceRect)
            
            currentY += 100
        }
        
        return currentY
    }
    
    // MARK: - Recommendations
    
    private func drawRecommendations(y: CGFloat, conflictCase: ConflictCase, checkSpace: (CGFloat) -> Void, newPage: () -> Void) -> CGFloat {
        var currentY = y
        
        for (index, rec) in conflictCase.recommendations.enumerated() {
            checkSpace(180)
            
            let actionColor = UIColor(rec.action.color)
            
            let cardRect = CGRect(x: marginLeft, y: currentY, width: contentWidth, height: 160)
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 10)
            actionColor.withAlphaComponent(0.08).setFill()
            cardPath.fill()
            actionColor.setStroke()
            cardPath.lineWidth = 2
            cardPath.stroke()
            
            // Action indicator bar
            let actionBar = CGRect(x: marginLeft, y: currentY, width: 6, height: 160)
            let actionBarPath = UIBezierPath(roundedRect: actionBar, byRoundingCorners: [.topLeft, .bottomLeft], cornerRadii: CGSize(width: 10, height: 10))
            actionColor.setFill()
            actionBarPath.fill()
            
            let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 14, weight: .bold), .foregroundColor: actionColor]
            let labelAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8, weight: .bold), .foregroundColor: subtleTextColor]
            let valueAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .regular), .foregroundColor: textColor]
            
            var infoY = currentY + 15
            
            "Recommendation #\(index + 1): \(rec.action.displayName)".draw(at: CGPoint(x: marginLeft + 20, y: infoY), withAttributes: titleAttrs)
            infoY += 25
            
            "CONFIDENCE:  \(Int(rec.confidence * 100))%".draw(at: CGPoint(x: marginLeft + 20, y: infoY), withAttributes: labelAttrs)
            "RISK LEVEL:  \(rec.riskAssessment)".draw(at: CGPoint(x: marginLeft + 150, y: infoY), withAttributes: labelAttrs)
            infoY += 20
            
            "REASONING".draw(at: CGPoint(x: marginLeft + 20, y: infoY), withAttributes: labelAttrs)
            infoY += 14
            
            let reasonText = NSAttributedString(string: rec.reasoning, attributes: valueAttrs)
            let reasonRect = CGRect(x: marginLeft + 20, y: infoY, width: contentWidth - 40, height: 40)
            reasonText.draw(in: reasonRect)
            infoY += 45
            
            if !rec.suggestedNextSteps.isEmpty {
                "SUGGESTED NEXT STEPS".draw(at: CGPoint(x: marginLeft + 20, y: infoY), withAttributes: labelAttrs)
                infoY += 14
                
                for step in rec.suggestedNextSteps.prefix(3) {
                    "• \(step)".draw(at: CGPoint(x: marginLeft + 25, y: infoY), withAttributes: valueAttrs)
                    infoY += 14
                }
            }
            
            currentY += 170
        }
        
        return currentY
    }
    
    // MARK: - Selected Action & Generated Document
    
    private func drawSelectedAction(y: CGFloat, conflictCase: ConflictCase, checkSpace: (CGFloat) -> Void, newPage: () -> Void) -> CGFloat {
        var currentY = y
        
        // Selected Action
        if let action = conflictCase.selectedAction {
            checkSpace(120)
            
            let actionColor = UIColor(action.color)
            
            let actionRect = CGRect(x: marginLeft, y: currentY, width: contentWidth, height: 100)
            let actionPath = UIBezierPath(roundedRect: actionRect, cornerRadius: 10)
            actionColor.withAlphaComponent(0.15).setFill()
            actionPath.fill()
            actionColor.setStroke()
            actionPath.lineWidth = 3
            actionPath.stroke()
            
            let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 18, weight: .bold), .foregroundColor: actionColor]
            let descAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11, weight: .regular), .foregroundColor: textColor]
            let riskAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .semibold), .foregroundColor: subtleTextColor]
            
            "FINAL DECISION: \(action.displayName.uppercased())".draw(at: CGPoint(x: marginLeft + 20, y: currentY + 20), withAttributes: titleAttrs)
            action.description.draw(at: CGPoint(x: marginLeft + 20, y: currentY + 50), withAttributes: descAttrs)
            "Risk Level: \(action.riskLevel)".draw(at: CGPoint(x: marginLeft + 20, y: currentY + 72), withAttributes: riskAttrs)
            
            currentY += 120
        }
        
        // Supervisor Notes
        if let notes = conflictCase.supervisorNotes, !notes.isEmpty {
            checkSpace(80)
            currentY = drawSubsectionHeader("Supervisor Notes", y: currentY)
            currentY = drawFullText(notes, y: currentY, checkSpace: checkSpace, newPage: newPage)
            currentY += 15
        }
        
        // Supervisor Decision Rationale
        if let decision = conflictCase.supervisorDecision, !decision.isEmpty {
            checkSpace(80)
            currentY = drawSubsectionHeader("Decision Rationale", y: currentY)
            currentY = drawFullText(decision, y: currentY, checkSpace: checkSpace, newPage: newPage)
            currentY += 15
        }
        
        // Generated Document (Full)
        if let genDoc = conflictCase.generatedDocument {
            newPage()
            currentY = marginTop + 35
            currentY = drawGeneratedDocument(genDoc, y: currentY, checkSpace: checkSpace, newPage: newPage)
        }
        
        return currentY
    }
    
    private func drawGeneratedDocument(_ doc: GeneratedActionDocument, y: CGFloat, checkSpace: (CGFloat) -> Void, newPage: () -> Void) -> CGFloat {
        var currentY = y
        
        let actionColor = UIColor(doc.actionType.color)
        
        // Document header
        let headerRect = CGRect(x: marginLeft, y: currentY, width: contentWidth, height: 50)
        let headerPath = UIBezierPath(roundedRect: headerRect, cornerRadius: 8)
        actionColor.setFill()
        headerPath.fill()
        
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 14, weight: .bold), .foregroundColor: UIColor.white]
        let subtitleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .medium), .foregroundColor: UIColor.white.withAlphaComponent(0.9)]
        
        doc.title.draw(at: CGPoint(x: marginLeft + 15, y: currentY + 10), withAttributes: titleAttrs)
        "Document Type: \(doc.actionType.displayName) | Generated: \(fullDateFormatter.string(from: doc.createdAt))".draw(at: CGPoint(x: marginLeft + 15, y: currentY + 30), withAttributes: subtitleAttrs)
        
        currentY += 65
        
        // Approval status
        checkSpace(40)
        let approvalRect = CGRect(x: marginLeft, y: currentY, width: contentWidth, height: 30)
        let approvalPath = UIBezierPath(roundedRect: approvalRect, cornerRadius: 4)
        (doc.isApproved ? UIColor.systemGreen : UIColor.systemOrange).withAlphaComponent(0.15).setFill()
        approvalPath.fill()
        
        let approvalAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .semibold), .foregroundColor: doc.isApproved ? UIColor.systemGreen : UIColor.systemOrange]
        let approvalText = doc.isApproved ? "✓ APPROVED" + (doc.approvedAt != nil ? " on \(fullDateFormatter.string(from: doc.approvedAt!))" : "") : "⏳ PENDING APPROVAL"
        approvalText.draw(at: CGPoint(x: marginLeft + 15, y: currentY + 8), withAttributes: approvalAttrs)
        
        currentY += 45
        
        // Full document content
        currentY = drawSubsectionHeader("Complete Document Content", y: currentY)
        currentY = drawFullText(doc.content, y: currentY, checkSpace: checkSpace, newPage: newPage)
        currentY += 15
        
        // Talking Points
        if let points = doc.talkingPoints, !points.isEmpty {
            checkSpace(80)
            currentY = drawSubsectionHeader("Talking Points", y: currentY)
            for point in points {
                currentY = drawBulletPoint(point, y: currentY, bulletColor: primaryColor, checkSpace: checkSpace)
            }
            currentY += 10
        }
        
        // Behavioral Focus Areas
        if let areas = doc.behavioralFocusAreas, !areas.isEmpty {
            checkSpace(80)
            currentY = drawSubsectionHeader("Behavioral Focus Areas", y: currentY)
            for area in areas {
                currentY = drawBulletPoint(area, y: currentY, bulletColor: UIColor.systemOrange, checkSpace: checkSpace)
            }
            currentY += 10
        }
        
        // Follow-up Timeline
        if let timeline = doc.followUpTimeline, !timeline.isEmpty {
            checkSpace(60)
            currentY = drawSubsectionHeader("Follow-up Timeline", y: currentY)
            currentY = drawParagraph(timeline, y: currentY, checkSpace: checkSpace)
            currentY += 10
        }
        
        // Policy References
        if let refs = doc.policyReferences, !refs.isEmpty {
            checkSpace(80)
            currentY = drawSubsectionHeader("Policy References", y: currentY)
            for ref in refs {
                currentY = drawBulletPoint(ref, y: currentY, bulletColor: secondaryColor, checkSpace: checkSpace)
            }
            currentY += 10
        }
        
        // Supervisor Edits
        if let edits = doc.supervisorEdits, !edits.isEmpty {
            checkSpace(80)
            currentY = drawSubsectionHeader("Supervisor Modifications", y: currentY)
            currentY = drawFullText(edits, y: currentY, checkSpace: checkSpace, newPage: newPage)
        }
        
        return currentY
    }
    
    // MARK: - Audit Trail
    
    // MARK: - Supervisor Notes & Review Comments
    
    private func drawSupervisorNotes(y: CGFloat, notes: String, decision: String?, checkSpace: (CGFloat) -> Void, newPage: () -> Void) -> CGFloat {
        var currentY = y
        
        // Section intro
        let introText = "This section contains notes and comments from the supervisor review process, documenting the rationale behind decisions made during case investigation."
        currentY = drawParagraph(introText, y: currentY, checkSpace: checkSpace)
        currentY += 15
        
        // Notes box with professional styling
        checkSpace(100)
        
        let notesBoxRect = CGRect(x: marginLeft, y: currentY, width: contentWidth, height: 45)
        let notesBoxPath = UIBezierPath(roundedRect: notesBoxRect, cornerRadius: 8)
        UIColor(red: 0.93, green: 0.95, blue: 0.98, alpha: 1.0).setFill()
        notesBoxPath.fill()
        primaryColor.setStroke()
        notesBoxPath.lineWidth = 2
        notesBoxPath.stroke()
        
        // Notes header with icon representation
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: primaryColor
        ]
        "📝 SUPERVISOR NOTES".draw(at: CGPoint(x: marginLeft + 15, y: currentY + 14), withAttributes: headerAttrs)
        
        currentY += 60
        
        // Full notes text
        currentY = drawFullText(notes, y: currentY, checkSpace: checkSpace, newPage: newPage)
        currentY += 20
        
        // Decision rationale if available
        if let decision = decision, !decision.isEmpty {
            checkSpace(80)
            
            let decisionBoxRect = CGRect(x: marginLeft, y: currentY, width: contentWidth, height: 45)
            let decisionBoxPath = UIBezierPath(roundedRect: decisionBoxRect, cornerRadius: 8)
            UIColor(red: 0.95, green: 0.98, blue: 0.93, alpha: 1.0).setFill()
            decisionBoxPath.fill()
            UIColor.systemGreen.setStroke()
            decisionBoxPath.lineWidth = 2
            decisionBoxPath.stroke()
            
            "⚖️ DECISION RATIONALE".draw(at: CGPoint(x: marginLeft + 15, y: currentY + 14), withAttributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: UIColor.systemGreen.withAlphaComponent(0.8)
            ])
            
            currentY += 60
            currentY = drawFullText(decision, y: currentY, checkSpace: checkSpace, newPage: newPage)
            currentY += 15
        }
        
        return currentY
    }
    
    // MARK: - Audit Trail (Continued)
    
    private func drawAuditTrail(y: CGFloat, conflictCase: ConflictCase, checkSpace: (CGFloat) -> Void, newPage: () -> Void) -> CGFloat {
        var currentY = y
        
        // Audit trail intro
        let introText = "This section documents all actions taken on this case, providing a complete chronological record for compliance and review purposes. Each entry includes timestamp, action type, user identification, and detailed description."
        currentY = drawParagraph(introText, y: currentY, checkSpace: checkSpace)
        currentY += 15
        
        // Summary stats
        checkSpace(50)
        let summaryRect = CGRect(x: marginLeft, y: currentY, width: contentWidth, height: 40)
        let summaryPath = UIBezierPath(roundedRect: summaryRect, cornerRadius: 6)
        accentColor.setFill()
        summaryPath.fill()
        
        let statsAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .semibold), .foregroundColor: primaryColor]
        "Total Entries: \(conflictCase.auditLog.count) | First Entry: \(conflictCase.auditLog.last != nil ? timestampFormatter.string(from: conflictCase.auditLog.last!.timestamp) : "N/A") | Last Entry: \(conflictCase.auditLog.first != nil ? timestampFormatter.string(from: conflictCase.auditLog.first!.timestamp) : "N/A")".draw(at: CGPoint(x: marginLeft + 15, y: currentY + 12), withAttributes: statsAttrs)
        
        currentY += 55
        
        // Table header
        checkSpace(30)
        let headerRect = CGRect(x: marginLeft, y: currentY, width: contentWidth, height: 25)
        let headerPath = UIBezierPath(roundedRect: headerRect, cornerRadius: 4)
        primaryColor.setFill()
        headerPath.fill()
        
        let headerAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .bold), .foregroundColor: UIColor.white]
        
        "TIMESTAMP".draw(at: CGPoint(x: marginLeft + 10, y: currentY + 7), withAttributes: headerAttrs)
        "ACTION".draw(at: CGPoint(x: marginLeft + 130, y: currentY + 7), withAttributes: headerAttrs)
        "USER".draw(at: CGPoint(x: marginLeft + 280, y: currentY + 7), withAttributes: headerAttrs)
        "DETAILS".draw(at: CGPoint(x: marginLeft + 370, y: currentY + 7), withAttributes: headerAttrs)
        
        currentY += 25
        
        // Table rows
        let rowAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8, weight: .regular), .foregroundColor: textColor]
        
        for (index, entry) in conflictCase.auditLog.enumerated() {
            checkSpace(45)
            
            // Alternating row colors
            if index % 2 == 0 {
                let rowRect = CGRect(x: marginLeft, y: currentY, width: contentWidth, height: 40)
                accentColor.setFill()
                UIRectFill(rowRect)
            }
            
            // Row border
            let rowBorder = UIBezierPath()
            rowBorder.move(to: CGPoint(x: marginLeft, y: currentY + 40))
            rowBorder.addLine(to: CGPoint(x: pageWidth - marginRight, y: currentY + 40))
            borderColor.setStroke()
            rowBorder.lineWidth = 0.5
            rowBorder.stroke()
            
            timestampFormatter.string(from: entry.timestamp).draw(at: CGPoint(x: marginLeft + 10, y: currentY + 5), withAttributes: rowAttrs)
            
            let actionText = NSAttributedString(string: entry.action, attributes: rowAttrs)
            actionText.draw(in: CGRect(x: marginLeft + 130, y: currentY + 5, width: 145, height: 32))
            
            entry.userName.draw(at: CGPoint(x: marginLeft + 280, y: currentY + 5), withAttributes: rowAttrs)
            
            let detailsText = NSAttributedString(string: entry.details, attributes: rowAttrs)
            detailsText.draw(in: CGRect(x: marginLeft + 370, y: currentY + 5, width: 115, height: 32))
            
            currentY += 40
        }
        
        return currentY + 10
    }
    
    // MARK: - Signature Blocks
    
    private func drawSignatureBlocks(y: CGFloat, checkSpace: (CGFloat) -> Void) -> CGFloat {
        var currentY = y
        
        let introText = "The signatures below certify that all parties have reviewed this document and attest to the accuracy and completeness of the information contained herein."
        currentY = drawParagraph(introText, y: currentY, checkSpace: checkSpace)
        currentY += 20
        
        // Signature blocks (2x2 grid)
        let blockWidth = (contentWidth - 30) / 2
        let blockHeight: CGFloat = 100
        
        let signatures = [
            ("PREPARED BY", "Investigator/HR Representative"),
            ("REVIEWED BY", "Supervisor/Manager"),
            ("HR APPROVAL", "HR Representative"),
            ("MANAGEMENT APPROVAL", "Department Head/Director")
        ]
        
        for (index, sig) in signatures.enumerated() {
            let col = index % 2
            let row = index / 2
            
            let x = marginLeft + CGFloat(col) * (blockWidth + 30)
            let sigY = currentY + CGFloat(row) * (blockHeight + 20)
            
            // Block background
            let blockRect = CGRect(x: x, y: sigY, width: blockWidth, height: blockHeight)
            let blockPath = UIBezierPath(roundedRect: blockRect, cornerRadius: 8)
            UIColor.white.setFill()
            blockPath.fill()
            borderColor.setStroke()
            blockPath.lineWidth = 1
            blockPath.stroke()
            
            let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .bold), .foregroundColor: primaryColor]
            let roleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8, weight: .regular), .foregroundColor: subtleTextColor]
            let labelAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 7, weight: .medium), .foregroundColor: borderColor]
            
            sig.0.draw(at: CGPoint(x: x + 12, y: sigY + 10), withAttributes: titleAttrs)
            sig.1.draw(at: CGPoint(x: x + 12, y: sigY + 25), withAttributes: roleAttrs)
            
            // Signature line
            let sigLine = UIBezierPath()
            sigLine.move(to: CGPoint(x: x + 12, y: sigY + 65))
            sigLine.addLine(to: CGPoint(x: x + blockWidth - 12, y: sigY + 65))
            borderColor.setStroke()
            sigLine.lineWidth = 0.5
            sigLine.stroke()
            
            "Signature".draw(at: CGPoint(x: x + 12, y: sigY + 68), withAttributes: labelAttrs)
            
            // Date line
            let dateLine = UIBezierPath()
            dateLine.move(to: CGPoint(x: x + 12, y: sigY + 90))
            dateLine.addLine(to: CGPoint(x: x + blockWidth * 0.5, y: sigY + 90))
            dateLine.stroke()
            
            "Date".draw(at: CGPoint(x: x + 12, y: sigY + 93), withAttributes: labelAttrs)
        }
        
        return currentY + 2 * blockHeight + 40
    }
    
    // MARK: - Helper Drawing Functions
    
    private func drawSubsectionHeader(_ title: String, y: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: secondaryColor
        ]
        
        // Bullet point
        "▸".draw(at: CGPoint(x: marginLeft, y: y), withAttributes: attrs)
        title.draw(at: CGPoint(x: marginLeft + 15, y: y), withAttributes: attrs)
        
        // Underline
        let line = UIBezierPath()
        line.move(to: CGPoint(x: marginLeft, y: y + 16))
        line.addLine(to: CGPoint(x: marginLeft + 200, y: y + 16))
        secondaryColor.withAlphaComponent(0.3).setStroke()
        line.lineWidth = 1
        line.stroke()
        
        return y + 24
    }
    
    private func drawParagraph(_ text: String, y: CGFloat, checkSpace: (CGFloat) -> Void) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.alignment = .justified
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedText = NSAttributedString(string: text, attributes: attrs)
        let boundingRect = attributedText.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        
        checkSpace(boundingRect.height + 10)
        
        let textRect = CGRect(x: marginLeft, y: y, width: contentWidth, height: boundingRect.height + 5)
        attributedText.draw(in: textRect)
        
        return y + boundingRect.height + 10
    }
    
    private func drawFullText(_ text: String, y: CGFloat, checkSpace: (CGFloat) -> Void, newPage: () -> Void) -> CGFloat {
        var currentY = y
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 8
        paragraphStyle.alignment = .justified
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        // Split text into chunks that fit on remaining page space
        let words = text.split(separator: " ").map(String.init)
        var currentChunk = ""
        
        for word in words {
            let testChunk = currentChunk.isEmpty ? word : currentChunk + " " + word
            let testAttr = NSAttributedString(string: testChunk, attributes: attrs)
            let testRect = testAttr.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            
            // If this chunk would overflow the page
            if currentY + testRect.height > pageHeight - marginBottom - 30 {
                // Draw current chunk
                if !currentChunk.isEmpty {
                    let chunkAttr = NSAttributedString(string: currentChunk, attributes: attrs)
                    let chunkRect = chunkAttr.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                    chunkAttr.draw(in: CGRect(x: marginLeft, y: currentY, width: contentWidth, height: chunkRect.height))
                }
                
                // New page
                newPage()
                currentY = marginTop + 35
                currentChunk = word
            } else {
                currentChunk = testChunk
            }
        }
        
        // Draw remaining chunk
        if !currentChunk.isEmpty {
            let chunkAttr = NSAttributedString(string: currentChunk, attributes: attrs)
            let chunkRect = chunkAttr.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            chunkAttr.draw(in: CGRect(x: marginLeft, y: currentY, width: contentWidth, height: chunkRect.height))
            currentY += chunkRect.height + 5
        }
        
        return currentY
    }
    
    private func drawBulletPoint(_ text: String, y: CGFloat, bulletColor: UIColor, checkSpace: (CGFloat) -> Void) -> CGFloat {
        let bulletAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .bold), .foregroundColor: bulletColor]
        let textAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .regular), .foregroundColor: textColor]
        
        let attributedText = NSAttributedString(string: text, attributes: textAttrs)
        let boundingRect = attributedText.boundingRect(with: CGSize(width: contentWidth - 20, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        
        checkSpace(boundingRect.height + 6)
        
        "●".draw(at: CGPoint(x: marginLeft + 5, y: y), withAttributes: bulletAttrs)
        attributedText.draw(in: CGRect(x: marginLeft + 20, y: y, width: contentWidth - 20, height: boundingRect.height + 5))
        
        return y + boundingRect.height + 8
    }
    
    private func drawDetailTable(_ items: [(String, String)], y: CGFloat, checkSpace: (CGFloat) -> Void) -> CGFloat {
        var currentY = y
        
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .semibold), .foregroundColor: subtleTextColor]
        let valueAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .regular), .foregroundColor: textColor]
        
        let labelWidth: CGFloat = 160
        let valueWidth: CGFloat = contentWidth - labelWidth - 20
        
        for (index, item) in items.enumerated() {
            // Calculate text height for proper wrapping
            let valueAttrStr = NSAttributedString(string: item.1, attributes: valueAttrs)
            let boundingRect = valueAttrStr.boundingRect(
                with: CGSize(width: valueWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            let rowHeight = max(22, ceil(boundingRect.height) + 8)
            
            checkSpace(rowHeight)
            
            // Alternating background
            if index % 2 == 0 {
                let rowRect = CGRect(x: marginLeft, y: currentY, width: contentWidth, height: rowHeight)
                accentColor.setFill()
                UIRectFill(rowRect)
            }
            
            item.0.draw(at: CGPoint(x: marginLeft + 10, y: currentY + 4), withAttributes: labelAttrs)
            
            // Draw value with proper text wrapping
            let valueDrawRect = CGRect(x: marginLeft + labelWidth, y: currentY + 4, width: valueWidth, height: rowHeight - 8)
            valueAttrStr.draw(in: valueDrawRect)
            
            currentY += rowHeight
        }
        
        return currentY + 5
    }
}
