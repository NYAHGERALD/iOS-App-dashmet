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
    case plainText = "txt"
    case html = "html"
    case email = "email"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .pdf: return "PDF Document"
        case .plainText: return "Plain Text"
        case .html: return "HTML"
        case .email: return "Email Ready"
        }
    }
    
    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .plainText: return "doc.text"
        case .html: return "chevron.left.forwardslash.chevron.right"
        case .email: return "envelope.fill"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .plainText: return "txt"
        case .html: return "html"
        case .email: return "eml"
        }
    }
    
    var mimeType: String {
        switch self {
        case .pdf: return "application/pdf"
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
