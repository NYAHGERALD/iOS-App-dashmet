//
//  DocumentExportService.swift
//  MeetingIntelligence
//
//  Phase 8: Document Export Service
//  Handles exporting generated documents to PDF, Word, and other formats
//

import Foundation
import UIKit
import PDFKit

// MARK: - Export Format
enum ExportFormat: String, CaseIterable, Identifiable {
    case pdf = "pdf"
    case docx = "docx"
    case plainText = "txt"
    case html = "html"
    case email = "email"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .pdf: return "PDF Document"
        case .docx: return "Word Document"
        case .plainText: return "Plain Text"
        case .html: return "HTML"
        case .email: return "Email Ready"
        }
    }
    
    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .docx: return "doc.richtext"
        case .plainText: return "doc.text"
        case .html: return "chevron.left.forwardslash.chevron.right"
        case .email: return "envelope.fill"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .docx: return "docx"
        case .plainText: return "txt"
        case .html: return "html"
        case .email: return "eml"
        }
    }
    
    var mimeType: String {
        switch self {
        case .pdf: return "application/pdf"
        case .docx: return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case .plainText: return "text/plain"
        case .html: return "text/html"
        case .email: return "message/rfc822"
        }
    }
}

// MARK: - Export Destination
enum ExportDestination: String, CaseIterable, Identifiable {
    case download = "download"
    case email = "email"
    case saveToCase = "save_to_case"
    case share = "share"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .download: return "Download to Device"
        case .email: return "Send via Email"
        case .saveToCase: return "Save to Case File"
        case .share: return "Share"
        }
    }
    
    var icon: String {
        switch self {
        case .download: return "arrow.down.circle.fill"
        case .email: return "envelope.fill"
        case .saveToCase: return "folder.fill.badge.plus"
        case .share: return "square.and.arrow.up"
        }
    }
}

// MARK: - Export Result
struct ExportResult {
    let success: Bool
    let format: ExportFormat
    let destination: ExportDestination
    let fileURL: URL?
    let fileData: Data?
    let errorMessage: String?
}

// MARK: - Document Export Service
class DocumentExportService {
    static let shared = DocumentExportService()
    
    private init() {}
    
    // MARK: - Export Document
    
    /// Export a generated document to the specified format
    func exportDocument(
        _ document: GeneratedDocument,
        format: ExportFormat,
        caseNumber: String,
        includeSignatures: Bool = false,
        signatures: [String: UIImage] = [:]
    ) async throws -> Data {
        
        switch format {
        case .pdf:
            return try await generatePDF(document: document, caseNumber: caseNumber, includeSignatures: includeSignatures, signatures: signatures)
        case .docx:
            return try await generateDOCX(document: document, caseNumber: caseNumber)
        case .plainText:
            return try generatePlainText(document: document)
        case .html:
            return try generateHTML(document: document, caseNumber: caseNumber)
        case .email:
            return try generateEmailFormat(document: document, caseNumber: caseNumber)
        }
    }
    
    // MARK: - PDF Generation
    
    private func generatePDF(
        document: GeneratedDocument,
        caseNumber: String,
        includeSignatures: Bool,
        signatures: [String: UIImage]
    ) async throws -> Data {
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // Letter size
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var currentY: CGFloat = 50
            let margin: CGFloat = 50
            let contentWidth = pageRect.width - (margin * 2)
            
            // Header
            let titleFont = UIFont.systemFont(ofSize: 18, weight: .bold)
            let headerFont = UIFont.systemFont(ofSize: 12, weight: .regular)
            let bodyFont = UIFont.systemFont(ofSize: 11, weight: .regular)
            let sectionFont = UIFont.systemFont(ofSize: 13, weight: .semibold)
            
            // Company Header (placeholder)
            let companyName = "ORGANIZATION NAME"
            let companyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: UIColor.darkGray
            ]
            companyName.draw(at: CGPoint(x: margin, y: currentY), withAttributes: companyAttrs)
            currentY += 30
            
            // Document Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]
            document.title.draw(at: CGPoint(x: margin, y: currentY), withAttributes: titleAttrs)
            currentY += 30
            
            // Case Number and Date
            let headerText = "Case: \(caseNumber) | Date: \(Date().formatted(date: .abbreviated, time: .omitted))"
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: headerFont,
                .foregroundColor: UIColor.gray
            ]
            headerText.draw(at: CGPoint(x: margin, y: currentY), withAttributes: headerAttrs)
            currentY += 20
            
            // Separator line
            let separatorPath = UIBezierPath()
            separatorPath.move(to: CGPoint(x: margin, y: currentY))
            separatorPath.addLine(to: CGPoint(x: pageRect.width - margin, y: currentY))
            UIColor.lightGray.setStroke()
            separatorPath.lineWidth = 0.5
            separatorPath.stroke()
            currentY += 20
            
            // Document content based on type
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: UIColor.black
            ]
            
            let sectionAttrs: [NSAttributedString.Key: Any] = [
                .font: sectionFont,
                .foregroundColor: UIColor.black
            ]
            
            switch document {
            case .coaching(let doc):
                currentY = drawCoachingContent(doc, context: context, pageRect: pageRect, startY: currentY, margin: margin, contentWidth: contentWidth, bodyAttrs: bodyAttrs, sectionAttrs: sectionAttrs)
                
            case .counseling(let doc):
                currentY = drawCounselingContent(doc, context: context, pageRect: pageRect, startY: currentY, margin: margin, contentWidth: contentWidth, bodyAttrs: bodyAttrs, sectionAttrs: sectionAttrs)
                
            case .warning(let doc):
                currentY = drawWarningContent(doc, context: context, pageRect: pageRect, startY: currentY, margin: margin, contentWidth: contentWidth, bodyAttrs: bodyAttrs, sectionAttrs: sectionAttrs, includeSignatures: includeSignatures, signatures: signatures)
                
            case .escalation(let doc):
                currentY = drawEscalationContent(doc, context: context, pageRect: pageRect, startY: currentY, margin: margin, contentWidth: contentWidth, bodyAttrs: bodyAttrs, sectionAttrs: sectionAttrs)
            }
            
            // Footer
            let footerY = pageRect.height - 30
            let footerText = "Generated by Conflict Resolution Assistant | Page 1"
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.gray
            ]
            let footerSize = footerText.size(withAttributes: footerAttrs)
            footerText.draw(at: CGPoint(x: (pageRect.width - footerSize.width) / 2, y: footerY), withAttributes: footerAttrs)
        }
        
        return data
    }
    
    private func drawCoachingContent(_ doc: CoachingDocument, context: UIGraphicsPDFRendererContext, pageRect: CGRect, startY: CGFloat, margin: CGFloat, contentWidth: CGFloat, bodyAttrs: [NSAttributedString.Key: Any], sectionAttrs: [NSAttributedString.Key: Any]) -> CGFloat {
        var currentY = startY
        
        // Overview
        "Overview".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 20
        currentY = drawWrappedText(doc.overview, at: CGPoint(x: margin, y: currentY), width: contentWidth, attributes: bodyAttrs)
        currentY += 15
        
        // Discussion Outline
        "Discussion Outline".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 20
        currentY = drawWrappedText("Opening: " + doc.discussionOutline.opening, at: CGPoint(x: margin, y: currentY), width: contentWidth, attributes: bodyAttrs)
        currentY += 10
        
        // Key Points
        "Key Points:".draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttrs)
        currentY += 15
        for point in doc.discussionOutline.keyPoints {
            currentY = drawWrappedText("• " + point, at: CGPoint(x: margin + 10, y: currentY), width: contentWidth - 10, attributes: bodyAttrs)
            currentY += 5
        }
        currentY += 10
        
        // Talking Points
        "Talking Points".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 20
        for point in doc.talkingPoints {
            currentY = drawWrappedText("• " + point, at: CGPoint(x: margin + 10, y: currentY), width: contentWidth - 10, attributes: bodyAttrs)
            currentY += 5
        }
        currentY += 10
        
        // Questions to Ask
        "Questions to Ask".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 20
        for question in doc.questionsToAsk {
            currentY = drawWrappedText("• " + question, at: CGPoint(x: margin + 10, y: currentY), width: contentWidth - 10, attributes: bodyAttrs)
            currentY += 5
        }
        currentY += 10
        
        // Follow-up Plan
        "Follow-up Plan".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 20
        currentY = drawWrappedText("Timeline: " + doc.followUpPlan.timeline, at: CGPoint(x: margin, y: currentY), width: contentWidth, attributes: bodyAttrs)
        
        return currentY
    }
    
    private func drawCounselingContent(_ doc: CounselingDocument, context: UIGraphicsPDFRendererContext, pageRect: CGRect, startY: CGFloat, margin: CGFloat, contentWidth: CGFloat, bodyAttrs: [NSAttributedString.Key: Any], sectionAttrs: [NSAttributedString.Key: Any]) -> CGFloat {
        var currentY = startY
        
        // Employee Info
        "Employee(s): \(doc.employeeNames.joined(separator: ", "))".draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttrs)
        currentY += 15
        "Date: \(doc.documentDate)".draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttrs)
        currentY += 20
        
        // Incident Summary
        "Incident Summary".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 20
        currentY = drawWrappedText(doc.incidentSummary, at: CGPoint(x: margin, y: currentY), width: contentWidth, attributes: bodyAttrs)
        currentY += 15
        
        // Discussion Points
        "Discussion Points".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 20
        for point in doc.discussionPoints {
            currentY = drawWrappedText("• " + point, at: CGPoint(x: margin + 10, y: currentY), width: contentWidth - 10, attributes: bodyAttrs)
            currentY += 5
        }
        currentY += 10
        
        // Expectations
        "Expectations".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 20
        for expectation in doc.expectations {
            currentY = drawWrappedText("• " + expectation, at: CGPoint(x: margin + 10, y: currentY), width: contentWidth - 10, attributes: bodyAttrs)
            currentY += 5
        }
        currentY += 10
        
        // Consequences
        "Consequences".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 20
        currentY = drawWrappedText(doc.consequences, at: CGPoint(x: margin, y: currentY), width: contentWidth, attributes: bodyAttrs)
        currentY += 15
        
        // Acknowledgment
        "Acknowledgment".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 20
        currentY = drawWrappedText(doc.acknowledgmentSection, at: CGPoint(x: margin, y: currentY), width: contentWidth, attributes: bodyAttrs)
        currentY += 30
        
        // Signature Lines
        currentY = drawSignatureLine("Employee Signature", at: CGPoint(x: margin, y: currentY), width: contentWidth / 2 - 20)
        currentY += 40
        currentY = drawSignatureLine("Supervisor Signature", at: CGPoint(x: margin, y: currentY), width: contentWidth / 2 - 20)
        
        return currentY
    }
    
    private func drawWarningContent(_ doc: WarningDocument, context: UIGraphicsPDFRendererContext, pageRect: CGRect, startY: CGFloat, margin: CGFloat, contentWidth: CGFloat, bodyAttrs: [NSAttributedString.Key: Any], sectionAttrs: [NSAttributedString.Key: Any], includeSignatures: Bool, signatures: [String: UIImage]) -> CGFloat {
        var currentY = startY
        
        // Warning Level Badge
        let warningAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: UIColor.orange
        ]
        "[\(doc.warningLevel)]".draw(at: CGPoint(x: margin, y: currentY), withAttributes: warningAttrs)
        currentY += 20
        
        // Employee Info
        "Employee(s): \(doc.employeeNames.joined(separator: ", "))".draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttrs)
        currentY += 15
        "Date: \(doc.documentDate)".draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttrs)
        currentY += 20
        
        // Company Rules Violated
        "Company Rules Violated".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 20
        for rule in doc.companyRulesViolated {
            currentY = drawWrappedText("• " + rule, at: CGPoint(x: margin + 10, y: currentY), width: contentWidth - 10, attributes: bodyAttrs)
            currentY += 5
        }
        currentY += 10
        
        // Description
        "Description of Incident".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 20
        currentY = drawWrappedText(doc.describeInDetail, at: CGPoint(x: margin, y: currentY), width: contentWidth, attributes: bodyAttrs)
        currentY += 15
        
        // Conduct Deficiency
        "Conduct Deficiency".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 20
        currentY = drawWrappedText(doc.conductDeficiency, at: CGPoint(x: margin, y: currentY), width: contentWidth, attributes: bodyAttrs)
        currentY += 15
        
        // Required Corrective Action
        "Required Corrective Action".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 20
        for action in doc.requiredCorrectiveAction {
            currentY = drawWrappedText("• " + action, at: CGPoint(x: margin + 10, y: currentY), width: contentWidth - 10, attributes: bodyAttrs)
            currentY += 5
        }
        currentY += 10
        
        // Consequences
        "Consequences of Non-Compliance".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 20
        currentY = drawWrappedText(doc.consequencesOfNotPerforming, at: CGPoint(x: margin, y: currentY), width: contentWidth, attributes: bodyAttrs)
        currentY += 15
        
        // Review Date
        "Review Date: \(doc.reviewDate)".draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttrs)
        currentY += 30
        
        // Signature Section
        "Acknowledgment".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 20
        currentY = drawWrappedText(doc.signatureSection.employeeAcknowledgment, at: CGPoint(x: margin, y: currentY), width: contentWidth, attributes: bodyAttrs)
        currentY += 20
        
        // Draw signature lines or actual signatures
        if includeSignatures {
            if let employeeSig = signatures["employee"] {
                employeeSig.draw(in: CGRect(x: margin, y: currentY, width: 150, height: 50))
                currentY += 60
            }
        }
        currentY = drawSignatureLine("Employee Signature", at: CGPoint(x: margin, y: currentY), width: contentWidth / 2 - 20)
        currentY += 40
        
        if includeSignatures {
            if let supervisorSig = signatures["supervisor"] {
                supervisorSig.draw(in: CGRect(x: margin, y: currentY, width: 150, height: 50))
                currentY += 60
            }
        }
        currentY = drawSignatureLine("Supervisor Signature", at: CGPoint(x: margin, y: currentY), width: contentWidth / 2 - 20)
        
        return currentY
    }
    
    private func drawEscalationContent(_ doc: EscalationDocument, context: UIGraphicsPDFRendererContext, pageRect: CGRect, startY: CGFloat, margin: CGFloat, contentWidth: CGFloat, bodyAttrs: [NSAttributedString.Key: Any], sectionAttrs: [NSAttributedString.Key: Any]) -> CGFloat {
        var currentY = startY
        
        // Urgency Level
        let urgencyColor: UIColor = doc.urgencyLevel == "Critical" ? .red : (doc.urgencyLevel == "High" ? .orange : .blue)
        let urgencyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: urgencyColor
        ]
        "URGENCY: \(doc.urgencyLevel.uppercased())".draw(at: CGPoint(x: margin, y: currentY), withAttributes: urgencyAttrs)
        currentY += 20
        
        // Prepared By
        "Prepared by: \(doc.preparedBy) | Date: \(doc.documentDate)".draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttrs)
        currentY += 20
        
        // Case Summary
        "Case Summary".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 20
        "Case Number: \(doc.caseSummary.caseNumber)".draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttrs)
        currentY += 15
        "Type: \(doc.caseSummary.caseType)".draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttrs)
        currentY += 15
        "Incident Date: \(doc.caseSummary.incidentDate)".draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttrs)
        currentY += 15
        "Location: \(doc.caseSummary.location)".draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttrs)
        currentY += 15
        "Department: \(doc.caseSummary.department)".draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttrs)
        currentY += 20
        
        // Involved Parties
        "Involved Parties".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 20
        for party in doc.involvedParties {
            currentY = drawWrappedText("\(party.name) (\(party.role)): \(party.summary)", at: CGPoint(x: margin, y: currentY), width: contentWidth, attributes: bodyAttrs)
            currentY += 10
        }
        currentY += 10
        
        // Analysis Findings
        "Analysis Findings".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 20
        for finding in doc.analysisFindings {
            currentY = drawWrappedText("• " + finding, at: CGPoint(x: margin + 10, y: currentY), width: contentWidth - 10, attributes: bodyAttrs)
            currentY += 5
        }
        currentY += 10
        
        // Supervisor Notes
        "Supervisor Notes".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 20
        currentY = drawWrappedText(doc.supervisorNotes, at: CGPoint(x: margin, y: currentY), width: contentWidth, attributes: bodyAttrs)
        currentY += 15
        
        // Recommended Actions
        "Recommended Actions".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 20
        for action in doc.recommendedActions {
            currentY = drawWrappedText("• " + action, at: CGPoint(x: margin + 10, y: currentY), width: contentWidth - 10, attributes: bodyAttrs)
            currentY += 5
        }
        currentY += 10
        
        // Requested HR Actions
        "Requested HR Actions".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 20
        for action in doc.requestedHRActions {
            currentY = drawWrappedText("➤ " + action, at: CGPoint(x: margin + 10, y: currentY), width: contentWidth - 10, attributes: bodyAttrs)
            currentY += 5
        }
        
        return currentY
    }
    
    private func drawWrappedText(_ text: String, at point: CGPoint, width: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let boundingRect = attributedString.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        attributedString.draw(in: CGRect(x: point.x, y: point.y, width: width, height: boundingRect.height))
        return point.y + boundingRect.height
    }
    
    private func drawSignatureLine(_ label: String, at point: CGPoint, width: CGFloat) -> CGFloat {
        let lineY = point.y + 30
        
        // Draw line
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: point.x, y: lineY))
        linePath.addLine(to: CGPoint(x: point.x + width, y: lineY))
        UIColor.black.setStroke()
        linePath.lineWidth = 0.5
        linePath.stroke()
        
        // Draw label
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.gray
        ]
        label.draw(at: CGPoint(x: point.x, y: lineY + 5), withAttributes: labelAttrs)
        
        return lineY + 20
    }
    
    // MARK: - Word Document (DOCX) Generation
    
    private func generateDOCX(document: GeneratedDocument, caseNumber: String) async throws -> Data {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // Create DOCX structure
        let wordDir = tempDir.appendingPathComponent("word")
        let relsDir = tempDir.appendingPathComponent("_rels")
        let wordRelsDir = wordDir.appendingPathComponent("_rels")
        
        try FileManager.default.createDirectory(at: wordDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: relsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: wordRelsDir, withIntermediateDirectories: true)
        
        // Generate XML content
        let contentTypes = generateDOCXContentTypes()
        let rels = generateDOCXRels()
        let documentRels = generateDOCXDocumentRels()
        let styles = generateDOCXStyles()
        let documentXML = generateDOCXContent(document: document, caseNumber: caseNumber)
        
        // Write files
        try contentTypes.write(to: tempDir.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)
        try rels.write(to: relsDir.appendingPathComponent(".rels"), atomically: true, encoding: .utf8)
        try documentRels.write(to: wordRelsDir.appendingPathComponent("document.xml.rels"), atomically: true, encoding: .utf8)
        try documentXML.write(to: wordDir.appendingPathComponent("document.xml"), atomically: true, encoding: .utf8)
        try styles.write(to: wordDir.appendingPathComponent("styles.xml"), atomically: true, encoding: .utf8)
        
        // Create ZIP archive (DOCX)
        let docxPath = tempDir.appendingPathComponent("output.docx")
        _ = try ZipUtility.createZipFile(from: tempDir, to: docxPath)
        
        return try Data(contentsOf: docxPath)
    }
    
    private func generateDOCXContentTypes() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
            <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
        </Types>
        """
    }
    
    private func generateDOCXRels() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """
    }
    
    private func generateDOCXDocumentRels() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        </Relationships>
        """
    }
    
    private func generateDOCXStyles() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:docDefaults>
                <w:rPrDefault>
                    <w:rPr>
                        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
                        <w:sz w:val="22"/>
                        <w:szCs w:val="22"/>
                    </w:rPr>
                </w:rPrDefault>
            </w:docDefaults>
            <w:style w:type="paragraph" w:styleId="Title">
                <w:name w:val="Title"/>
                <w:pPr><w:jc w:val="center"/></w:pPr>
                <w:rPr><w:b/><w:sz w:val="32"/></w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="Heading1">
                <w:name w:val="Heading 1"/>
                <w:pPr><w:spacing w:before="240" w:after="120"/></w:pPr>
                <w:rPr><w:b/><w:sz w:val="28"/><w:color w:val="1A4F96"/></w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="Heading2">
                <w:name w:val="Heading 2"/>
                <w:pPr><w:spacing w:before="200" w:after="80"/></w:pPr>
                <w:rPr><w:b/><w:sz w:val="24"/><w:color w:val="3380CC"/></w:rPr>
            </w:style>
        </w:styles>
        """
    }
    
    private func generateDOCXContent(document: GeneratedDocument, caseNumber: String) -> String {
        var content = ""
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        let timestamp = dateFormatter.string(from: Date())
        
        // Title
        content += docxParagraph(document.title.uppercased(), style: "Title", bold: true, fontSize: 32)
        content += docxParagraph("Case: \(caseNumber)  |  Date: \(timestamp)", style: nil, bold: false, fontSize: 18, colorHex: "666666", alignment: "center")
        content += docxParagraph("", style: nil, bold: false, fontSize: 12) // spacer
        
        switch document {
        case .coaching(let doc):
            content += docxHeading1("OVERVIEW")
            content += docxParagraph(doc.overview, style: nil, bold: false, fontSize: 22)
            
            content += docxHeading1("DISCUSSION OUTLINE")
            content += docxHeading2("Opening")
            content += docxParagraph(doc.discussionOutline.opening, style: nil, bold: false, fontSize: 22)
            
            content += docxHeading2("Key Points")
            for point in doc.discussionOutline.keyPoints {
                content += docxBullet(point)
            }
            
            if !doc.discussionOutline.transitionStatements.isEmpty {
                content += docxHeading2("Transition Statements")
                for statement in doc.discussionOutline.transitionStatements {
                    content += docxBullet(statement)
                }
            }
            
            content += docxHeading1("TALKING POINTS")
            for point in doc.talkingPoints {
                content += docxBullet(point)
            }
            
            if !doc.questionsToAsk.isEmpty {
                content += docxHeading1("QUESTIONS TO ASK")
                for question in doc.questionsToAsk {
                    content += docxBullet(question)
                }
            }
            
            if !doc.behavioralFocusAreas.isEmpty {
                content += docxHeading1("BEHAVIORAL FOCUS AREAS")
                for area in doc.behavioralFocusAreas {
                    content += docxHeading2(area.area)
                    content += docxParagraph(area.description, style: nil, bold: false, fontSize: 22)
                    content += docxParagraph("Expected Change: \(area.expectedChange)", style: nil, bold: true, fontSize: 20, colorHex: "27AE60")
                }
            }
            
            content += docxHeading1("FOLLOW-UP PLAN")
            content += docxParagraph("Timeline: \(doc.followUpPlan.timeline)", style: nil, bold: false, fontSize: 22)
            if !doc.followUpPlan.checkInDates.isEmpty {
                content += docxHeading2("Check-in Dates")
                for date in doc.followUpPlan.checkInDates {
                    content += docxBullet(date)
                }
            }
            if !doc.followUpPlan.successIndicators.isEmpty {
                content += docxHeading2("Success Indicators")
                for indicator in doc.followUpPlan.successIndicators {
                    content += docxBullet(indicator)
                }
            }
            
        case .counseling(let doc):
            content += docxHeading1("INCIDENT SUMMARY")
            content += docxParagraph(doc.incidentSummary, style: nil, bold: false, fontSize: 22)
            
            content += docxHeading1("DISCUSSION POINTS")
            for point in doc.discussionPoints {
                content += docxBullet(point)
            }
            
            content += docxHeading1("POLICY REFERENCES")
            for policy in doc.policyReferences {
                content += docxBullet(policy)
            }
            
            content += docxHeading1("EXPECTATIONS")
            for expectation in doc.expectations {
                content += docxBullet(expectation)
            }
            
            content += docxHeading1("IMPROVEMENT PLAN")
            content += docxParagraph("Timeline: \(doc.improvementPlan.timeline)", style: nil, bold: false, fontSize: 22)
            content += docxHeading2("Goals")
            for goal in doc.improvementPlan.goals {
                content += docxBullet(goal)
            }
            if !doc.improvementPlan.supportProvided.isEmpty {
                content += docxHeading2("Support Provided")
                for support in doc.improvementPlan.supportProvided {
                    content += docxBullet(support)
                }
            }
            
            content += docxHeading1("CONSEQUENCES")
            content += docxParagraph(doc.consequences, style: nil, bold: false, fontSize: 22)
            
        case .warning(let doc):
            content += docxHeading1("WARNING LEVEL")
            content += docxParagraph(doc.warningLevel.uppercased(), style: nil, bold: true, fontSize: 24, colorHex: "C0392B")
            
            content += docxHeading1("COMPANY RULES VIOLATED")
            for rule in doc.companyRulesViolated {
                content += docxBullet(rule)
            }
            
            content += docxHeading1("DETAILED DESCRIPTION")
            content += docxParagraph(doc.describeInDetail, style: nil, bold: false, fontSize: 22)
            
            content += docxHeading1("CONDUCT DEFICIENCY")
            content += docxParagraph(doc.conductDeficiency, style: nil, bold: false, fontSize: 22)
            
            content += docxHeading1("REQUIRED CORRECTIVE ACTION")
            for action in doc.requiredCorrectiveAction {
                content += docxBullet(action)
            }
            
            content += docxHeading1("CONSEQUENCES OF NOT PERFORMING")
            content += docxParagraph(doc.consequencesOfNotPerforming, style: nil, bold: false, fontSize: 22, colorHex: "C0392B")
            
            content += docxHeading1("REVIEW DATE")
            content += docxParagraph(doc.reviewDate, style: nil, bold: false, fontSize: 22)
            
            if !doc.priorActions.isEmpty {
                content += docxHeading1("PRIOR ACTIONS")
                content += docxParagraph(doc.priorActions, style: nil, bold: false, fontSize: 22)
            }
            
        case .escalation(let doc):
            content += docxHeading1("CASE SUMMARY")
            content += docxParagraph("Case Number: \(doc.caseSummary.caseNumber)", style: nil, bold: false, fontSize: 22)
            content += docxParagraph("Case Type: \(doc.caseSummary.caseType)", style: nil, bold: false, fontSize: 22)
            content += docxParagraph("Incident Date: \(doc.caseSummary.incidentDate)", style: nil, bold: false, fontSize: 22)
            content += docxParagraph("Location: \(doc.caseSummary.location)", style: nil, bold: false, fontSize: 22)
            content += docxParagraph("Department: \(doc.caseSummary.department)", style: nil, bold: false, fontSize: 22)
            
            content += docxHeading1("URGENCY LEVEL")
            content += docxParagraph(doc.urgencyLevel.uppercased(), style: nil, bold: true, fontSize: 24, colorHex: "E74C3C")
            
            if !doc.involvedParties.isEmpty {
                content += docxHeading1("INVOLVED PARTIES")
                for party in doc.involvedParties {
                    content += docxHeading2(party.name)
                    content += docxParagraph("Role: \(party.role)", style: nil, bold: false, fontSize: 20, colorHex: "666666")
                    content += docxParagraph(party.summary, style: nil, bold: false, fontSize: 22)
                }
            }
            
            if !doc.incidentTimeline.isEmpty {
                content += docxHeading1("INCIDENT TIMELINE")
                for event in doc.incidentTimeline {
                    content += docxBullet("\(event.date): \(event.event)")
                }
            }
            
            if !doc.evidenceSummary.isEmpty {
                content += docxHeading1("EVIDENCE SUMMARY")
                for evidence in doc.evidenceSummary {
                    content += docxBullet(evidence)
                }
            }
            
            if !doc.policyReferences.isEmpty {
                content += docxHeading1("POLICY REFERENCES")
                for policy in doc.policyReferences {
                    content += docxBullet("\(policy.section): \(policy.relevance)")
                }
            }
            
            if !doc.analysisFindings.isEmpty {
                content += docxHeading1("ANALYSIS FINDINGS")
                for finding in doc.analysisFindings {
                    content += docxBullet(finding)
                }
            }
            
            if !doc.supervisorNotes.isEmpty {
                content += docxHeading1("SUPERVISOR NOTES")
                content += docxParagraph(doc.supervisorNotes, style: nil, bold: false, fontSize: 22)
            }
            
            content += docxHeading1("RECOMMENDED ACTIONS")
            for action in doc.recommendedActions {
                content += docxBullet(action)
            }
            
            content += docxHeading1("REQUESTED HR ACTIONS")
            for action in doc.requestedHRActions {
                content += docxBullet(action)
            }
        }
        
        // Signature sections
        content += docxParagraph("", style: nil, bold: false, fontSize: 22)
        content += docxHeading1("ACKNOWLEDGMENT")
        content += docxParagraph("I acknowledge receipt and understanding of this document.", style: nil, bold: false, fontSize: 22)
        content += docxParagraph("", style: nil, bold: false, fontSize: 22)
        content += docxParagraph("Employee Signature: _____________________________     Date: ____________", style: nil, bold: false, fontSize: 22)
        content += docxParagraph("", style: nil, bold: false, fontSize: 22)
        content += docxParagraph("Supervisor Signature: ____________________________     Date: ____________", style: nil, bold: false, fontSize: 22)
        
        return wrapDOCXDocument(content: content)
    }
    
    private func docxParagraph(_ text: String, style: String?, bold: Bool, fontSize: Int, colorHex: String? = nil, alignment: String? = nil) -> String {
        var pPr = ""
        if style != nil || alignment != nil {
            pPr = "<w:pPr>"
            if let style = style {
                pPr += "<w:pStyle w:val=\"\(style)\"/>"
            }
            if let alignment = alignment {
                pPr += "<w:jc w:val=\"\(alignment)\"/>"
            }
            pPr += "</w:pPr>"
        }
        
        var rPr = ""
        if bold || colorHex != nil || fontSize != 22 {
            rPr = "<w:rPr>"
            if bold { rPr += "<w:b/>" }
            if let color = colorHex { rPr += "<w:color w:val=\"\(color)\"/>" }
            if fontSize != 22 { rPr += "<w:sz w:val=\"\(fontSize)\"/><w:szCs w:val=\"\(fontSize)\"/>" }
            rPr += "</w:rPr>"
        }
        
        let escapedText = escapeXMLCharacters(text)
        return "<w:p>\(pPr)<w:r>\(rPr)<w:t>\(escapedText)</w:t></w:r></w:p>"
    }
    
    private func docxHeading1(_ text: String) -> String {
        return docxParagraph(text, style: "Heading1", bold: true, fontSize: 28, colorHex: "1A4F96")
    }
    
    private func docxHeading2(_ text: String) -> String {
        return docxParagraph(text, style: "Heading2", bold: true, fontSize: 24, colorHex: "3380CC")
    }
    
    private func docxBullet(_ text: String) -> String {
        let escapedText = escapeXMLCharacters(text)
        return "<w:p><w:pPr><w:spacing w:after=\"60\"/></w:pPr><w:r><w:t>• \(escapedText)</w:t></w:r></w:p>"
    }
    
    private func wrapDOCXDocument(content: String) -> String {
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:body>
                \(content)
                <w:sectPr>
                    <w:pgSz w:w="12240" w:h="15840"/>
                    <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
                </w:sectPr>
            </w:body>
        </w:document>
        """
    }
    
    private func escapeXMLCharacters(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    // MARK: - Plain Text Generation
    
    private func generatePlainText(document: GeneratedDocument) throws -> Data {
        var text = ""
        
        text += document.title.uppercased() + "\n"
        text += String(repeating: "=", count: 50) + "\n\n"
        
        switch document {
        case .coaching(let doc):
            text += "OVERVIEW\n\(doc.overview)\n\n"
            text += "DISCUSSION OUTLINE\n"
            text += "Opening: \(doc.discussionOutline.opening)\n\n"
            text += "Key Points:\n"
            for point in doc.discussionOutline.keyPoints {
                text += "- \(point)\n"
            }
            text += "\nTALKING POINTS\n"
            for point in doc.talkingPoints {
                text += "- \(point)\n"
            }
            text += "\nQUESTIONS TO ASK\n"
            for question in doc.questionsToAsk {
                text += "- \(question)\n"
            }
            text += "\nFOLLOW-UP PLAN\n"
            text += "Timeline: \(doc.followUpPlan.timeline)\n"
            
        case .counseling(let doc):
            text += "Employee(s): \(doc.employeeNames.joined(separator: ", "))\n"
            text += "Date: \(doc.documentDate)\n\n"
            text += "INCIDENT SUMMARY\n\(doc.incidentSummary)\n\n"
            text += "DISCUSSION POINTS\n"
            for point in doc.discussionPoints {
                text += "- \(point)\n"
            }
            text += "\nEXPECTATIONS\n"
            for expectation in doc.expectations {
                text += "- \(expectation)\n"
            }
            text += "\nCONSEQUENCES\n\(doc.consequences)\n\n"
            text += "ACKNOWLEDGMENT\n\(doc.acknowledgmentSection)\n"
            
        case .warning(let doc):
            text += "[\(doc.warningLevel)]\n\n"
            text += "Employee(s): \(doc.employeeNames.joined(separator: ", "))\n"
            text += "Date: \(doc.documentDate)\n\n"
            text += "COMPANY RULES VIOLATED\n"
            for rule in doc.companyRulesViolated {
                text += "- \(rule)\n"
            }
            text += "\nDESCRIPTION\n\(doc.describeInDetail)\n\n"
            text += "CONDUCT DEFICIENCY\n\(doc.conductDeficiency)\n\n"
            text += "REQUIRED CORRECTIVE ACTION\n"
            for action in doc.requiredCorrectiveAction {
                text += "- \(action)\n"
            }
            text += "\nCONSEQUENCES\n\(doc.consequencesOfNotPerforming)\n\n"
            text += "Review Date: \(doc.reviewDate)\n"
            
        case .escalation(let doc):
            text += "URGENCY: \(doc.urgencyLevel)\n"
            text += "Prepared by: \(doc.preparedBy)\n"
            text += "Date: \(doc.documentDate)\n\n"
            text += "CASE SUMMARY\n"
            text += "Case Number: \(doc.caseSummary.caseNumber)\n"
            text += "Type: \(doc.caseSummary.caseType)\n"
            text += "Incident Date: \(doc.caseSummary.incidentDate)\n"
            text += "Location: \(doc.caseSummary.location)\n"
            text += "Department: \(doc.caseSummary.department)\n\n"
            text += "INVOLVED PARTIES\n"
            for party in doc.involvedParties {
                text += "- \(party.name) (\(party.role)): \(party.summary)\n"
            }
            text += "\nANALYSIS FINDINGS\n"
            for finding in doc.analysisFindings {
                text += "- \(finding)\n"
            }
            text += "\nSUPERVISOR NOTES\n\(doc.supervisorNotes)\n\n"
            text += "RECOMMENDED ACTIONS\n"
            for action in doc.recommendedActions {
                text += "- \(action)\n"
            }
            text += "\nREQUESTED HR ACTIONS\n"
            for action in doc.requestedHRActions {
                text += "-> \(action)\n"
            }
        }
        
        guard let data = text.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        
        return data
    }
    
    // MARK: - HTML Generation
    
    private func generateHTML(document: GeneratedDocument, caseNumber: String) throws -> Data {
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>\(document.title)</title>
            <style>
                body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
                h1 { color: #333; border-bottom: 2px solid #007AFF; padding-bottom: 10px; }
                h2 { color: #555; margin-top: 30px; }
                .meta { color: #888; font-size: 0.9em; margin-bottom: 20px; }
                .urgency-critical { color: #FF3B30; font-weight: bold; }
                .urgency-high { color: #FF9500; font-weight: bold; }
                ul { padding-left: 20px; }
                li { margin-bottom: 5px; }
                .signature-line { border-top: 1px solid #000; width: 200px; margin-top: 40px; padding-top: 5px; font-size: 0.8em; color: #666; }
            </style>
        </head>
        <body>
            <h1>\(document.title)</h1>
            <div class="meta">Case: \(caseNumber) | Generated: \(Date().formatted())</div>
        """
        
        switch document {
        case .coaching(let doc):
            html += """
            <h2>Overview</h2>
            <p>\(doc.overview)</p>
            <h2>Discussion Outline</h2>
            <p><strong>Opening:</strong> \(doc.discussionOutline.opening)</p>
            <h3>Key Points</h3>
            <ul>
            \(doc.discussionOutline.keyPoints.map { "<li>\($0)</li>" }.joined(separator: "\n"))
            </ul>
            <h2>Talking Points</h2>
            <ul>
            \(doc.talkingPoints.map { "<li>\($0)</li>" }.joined(separator: "\n"))
            </ul>
            <h2>Questions to Ask</h2>
            <ul>
            \(doc.questionsToAsk.map { "<li>\($0)</li>" }.joined(separator: "\n"))
            </ul>
            <h2>Follow-up Plan</h2>
            <p>Timeline: \(doc.followUpPlan.timeline)</p>
            """
            
        case .counseling(let doc):
            html += """
            <p><strong>Employee(s):</strong> \(doc.employeeNames.joined(separator: ", "))</p>
            <p><strong>Date:</strong> \(doc.documentDate)</p>
            <h2>Incident Summary</h2>
            <p>\(doc.incidentSummary)</p>
            <h2>Discussion Points</h2>
            <ul>
            \(doc.discussionPoints.map { "<li>\($0)</li>" }.joined(separator: "\n"))
            </ul>
            <h2>Expectations</h2>
            <ul>
            \(doc.expectations.map { "<li>\($0)</li>" }.joined(separator: "\n"))
            </ul>
            <h2>Consequences</h2>
            <p>\(doc.consequences)</p>
            <h2>Acknowledgment</h2>
            <p>\(doc.acknowledgmentSection)</p>
            <div class="signature-line">Employee Signature</div>
            <div class="signature-line">Supervisor Signature</div>
            """
            
        case .warning(let doc):
            html += """
            <p><strong style="color: #FF9500;">[\(doc.warningLevel)]</strong></p>
            <p><strong>Employee(s):</strong> \(doc.employeeNames.joined(separator: ", "))</p>
            <p><strong>Date:</strong> \(doc.documentDate)</p>
            <h2>Company Rules Violated</h2>
            <ul>
            \(doc.companyRulesViolated.map { "<li>\($0)</li>" }.joined(separator: "\n"))
            </ul>
            <h2>Description</h2>
            <p>\(doc.describeInDetail)</p>
            <h2>Conduct Deficiency</h2>
            <p>\(doc.conductDeficiency)</p>
            <h2>Required Corrective Action</h2>
            <ul>
            \(doc.requiredCorrectiveAction.map { "<li>\($0)</li>" }.joined(separator: "\n"))
            </ul>
            <h2>Consequences of Non-Compliance</h2>
            <p>\(doc.consequencesOfNotPerforming)</p>
            <p><strong>Review Date:</strong> \(doc.reviewDate)</p>
            <div class="signature-line">Employee Signature</div>
            <div class="signature-line">Supervisor Signature</div>
            """
            
        case .escalation(let doc):
            let urgencyClass = doc.urgencyLevel == "Critical" ? "urgency-critical" : (doc.urgencyLevel == "High" ? "urgency-high" : "")
            html += """
            <p class="\(urgencyClass)">URGENCY: \(doc.urgencyLevel)</p>
            <p><strong>Prepared by:</strong> \(doc.preparedBy)</p>
            <p><strong>Date:</strong> \(doc.documentDate)</p>
            <h2>Case Summary</h2>
            <ul>
                <li>Case Number: \(doc.caseSummary.caseNumber)</li>
                <li>Type: \(doc.caseSummary.caseType)</li>
                <li>Incident Date: \(doc.caseSummary.incidentDate)</li>
                <li>Location: \(doc.caseSummary.location)</li>
                <li>Department: \(doc.caseSummary.department)</li>
            </ul>
            <h2>Involved Parties</h2>
            <ul>
            \(doc.involvedParties.map { "<li><strong>\($0.name)</strong> (\($0.role)): \($0.summary)</li>" }.joined(separator: "\n"))
            </ul>
            <h2>Analysis Findings</h2>
            <ul>
            \(doc.analysisFindings.map { "<li>\($0)</li>" }.joined(separator: "\n"))
            </ul>
            <h2>Supervisor Notes</h2>
            <p>\(doc.supervisorNotes)</p>
            <h2>Recommended Actions</h2>
            <ul>
            \(doc.recommendedActions.map { "<li>\($0)</li>" }.joined(separator: "\n"))
            </ul>
            <h2>Requested HR Actions</h2>
            <ul>
            \(doc.requestedHRActions.map { "<li><strong>\($0)</strong></li>" }.joined(separator: "\n"))
            </ul>
            """
        }
        
        html += """
        </body>
        </html>
        """
        
        guard let data = html.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        
        return data
    }
    
    // MARK: - Email Format Generation
    
    private func generateEmailFormat(document: GeneratedDocument, caseNumber: String) throws -> Data {
        let plainText = try generatePlainText(document: document)
        guard let textString = String(data: plainText, encoding: .utf8) else {
            throw ExportError.encodingFailed
        }
        
        let emailContent = """
        Subject: \(document.title) - Case \(caseNumber)
        
        \(textString)
        
        ---
        This document was generated by the Conflict Resolution Assistant.
        Please do not reply directly to this email.
        """
        
        guard let data = emailContent.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        
        return data
    }
    
    // MARK: - Save to File
    
    func saveToFile(data: Data, filename: String, format: ExportFormat) throws -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent("\(filename).\(format.fileExtension)")
        
        try data.write(to: fileURL)
        
        return fileURL
    }
}

// MARK: - Export Error

enum ExportError: Error, LocalizedError {
    case encodingFailed
    case saveFailed
    case invalidDocument
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode document"
        case .saveFailed:
            return "Failed to save document"
        case .invalidDocument:
            return "Invalid document format"
        }
    }
}
