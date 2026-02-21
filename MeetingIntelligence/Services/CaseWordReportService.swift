//
//  CaseWordReportService.swift
//  MeetingIntelligence
//
//  Enterprise-Grade Professional Case Report Generation Service
//  Generates Microsoft Word (.docx) documents with full documentation
//

import Foundation
import UIKit
import Combine
import ZIPFoundation

// MARK: - Word Report Configuration

struct WordReportConfiguration {
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
    var confidentialityLevel: WordConfidentialityLevel = .confidential
    var preparedBy: String = ""
    var preparedFor: String = ""
    
    static var full: WordReportConfiguration { WordReportConfiguration() }
    
    static var summary: WordReportConfiguration {
        var config = WordReportConfiguration()
        config.includeAuditTrail = false
        config.includeScannedDocuments = false
        config.includeFullStatements = false
        return config
    }
}

enum WordConfidentialityLevel: String, CaseIterable {
    case confidential = "CONFIDENTIAL"
    case restricted = "RESTRICTED"
    case internalOnly = "INTERNAL USE ONLY"
    case hrOnly = "HR CONFIDENTIAL"
    
    var colorHex: String {
        switch self {
        case .confidential: return "C0392B"  // Red
        case .restricted: return "E67E22"    // Orange
        case .internalOnly: return "2980B9"  // Blue
        case .hrOnly: return "8E44AD"        // Purple
        }
    }
}

struct WordReportGenerationResult {
    let success: Bool
    let docxData: Data?
    let generatedAt: Date
    let errorMessage: String?
    let reportId: String
    
    static func failure(_ message: String) -> WordReportGenerationResult {
        WordReportGenerationResult(success: false, docxData: nil, generatedAt: Date(), errorMessage: message, reportId: "")
    }
}

// MARK: - Case Word Report Service

final class CaseWordReportService: ObservableObject {
    
    static let shared = CaseWordReportService()
    
    @Published var isGenerating: Bool = false
    @Published var generationProgress: Double = 0.0
    @Published var currentStep: String = ""
    
    // Colors (as hex for Word XML)
    private let primaryColorHex = "1A4F96"     // Dark blue
    private let secondaryColorHex = "3380CC"   // Medium blue
    private let accentColorHex = "F2F5FA"      // Light blue-gray
    private let borderColorHex = "D9D9DE"      // Light gray
    private let textColorHex = "262633"        // Dark gray
    private let subtleTextColorHex = "666673"  // Medium gray
    
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
    
    // MARK: - Name Resolution Helpers
    
    /// Checks if a string looks like an identifier (UUID, Firebase ID, hex string, etc.) rather than a human name
    private func looksLikeIdentifier(_ string: String) -> Bool {
        // Empty or very short strings
        if string.isEmpty || string.count < 3 {
            return true
        }
        
        // Firebase composite IDs contain colons (e.g., "88b27ad1e888864d569ce2529e43fc24:f81b1eeb5d33e2c0060fe7fa9f5517e6")
        if string.contains(":") {
            return true
        }
        
        // Standard UUID format (8-4-4-4-12 with hyphens)
        if string.count == 36 && string.contains("-") {
            let uuidPattern = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
            if string.range(of: uuidPattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        // Long hex strings (32+ characters, all hex digits)
        if string.count >= 32 {
            let hexPattern = "^[0-9a-fA-F]+$"
            if string.range(of: hexPattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        // Contains only hex characters and is longer than 20 chars (likely an ID)
        if string.count > 20 {
            let cleanedString = string.filter { $0.isHexDigit || $0 == "-" || $0 == "_" }
            if cleanedString.count == string.count {
                return true
            }
        }
        
        return false
    }
    
    /// Resolves the employee name for a document by checking multiple sources
    /// Returns the employee name or nil if no name can be found (NEVER returns an ID)
    private func resolveEmployeeName(for doc: CaseDocument, in conflictCase: ConflictCase) -> String? {
        // Strategy 1: Use doc.employeeId (UUID) to match InvolvedEmployee.id
        if let docEmployeeId = doc.employeeId {
            if let employee = conflictCase.involvedEmployees.first(where: { $0.id == docEmployeeId }) {
                return employee.name
            }
            // Also check complainantA and complainantB
            if let compA = conflictCase.complainantA, compA.id == docEmployeeId {
                return compA.name
            }
            if let compB = conflictCase.complainantB, compB.id == docEmployeeId {
                return compB.name
            }
        }
        
        // Strategy 2: Based on document type, use the corresponding complainant
        switch doc.type {
        case .complaintA:
            if let compA = conflictCase.complainantA {
                return compA.name
            }
        case .complaintB:
            if let compB = conflictCase.complainantB {
                return compB.name
            }
        default:
            break
        }
        
        // Strategy 3: Try submittedById to match against employee IDs
        if let submittedById = doc.submittedById {
            // Try matching against InvolvedEmployee.id.uuidString
            if let employee = conflictCase.involvedEmployees.first(where: { $0.id.uuidString == submittedById }) {
                return employee.name
            }
            // Try matching against InvolvedEmployee.employeeId (external ID)
            if let employee = conflictCase.involvedEmployees.first(where: { $0.employeeId == submittedById }) {
                return employee.name
            }
            // Check complainants
            if let compA = conflictCase.complainantA, compA.id.uuidString == submittedById {
                return compA.name
            }
            if let compB = conflictCase.complainantB, compB.id.uuidString == submittedById {
                return compB.name
            }
        }
        
        // Strategy 4: Only use submittedBy if it looks like a real name (not an identifier)
        if let submittedBy = doc.submittedBy, !looksLikeIdentifier(submittedBy) {
            return submittedBy
        }
        
        // No name found - return nil (caller will use "Anonymous Submitter")
        return nil
    }
    
    // MARK: - Public API
    
    @MainActor
    func generateReport(for conflictCase: ConflictCase, configuration: WordReportConfiguration = .full) async -> WordReportGenerationResult {
        isGenerating = true
        generationProgress = 0.0
        currentStep = "Initializing..."
        
        defer {
            isGenerating = false
            generationProgress = 1.0
            currentStep = "Complete"
        }
        
        do {
            let docxData = try await generateWordReport(conflictCase: conflictCase, config: configuration)
            return WordReportGenerationResult(
                success: true,
                docxData: docxData,
                generatedAt: Date(),
                errorMessage: nil,
                reportId: conflictCase.caseNumber
            )
        } catch {
            return WordReportGenerationResult.failure(error.localizedDescription)
        }
    }
    
    // MARK: - Word Document Generation
    
    private func generateWordReport(conflictCase: ConflictCase, config: WordReportConfiguration) async throws -> Data {
        updateProgress(0.05, step: "Creating document structure...")
        
        // Create temporary directory for DOCX contents
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // Create DOCX structure
        let wordDir = tempDir.appendingPathComponent("word")
        let relsDir = tempDir.appendingPathComponent("_rels")
        let wordRelsDir = wordDir.appendingPathComponent("_rels")
        let mediaDir = wordDir.appendingPathComponent("media")
        
        try FileManager.default.createDirectory(at: wordDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: relsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: wordRelsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)
        
        updateProgress(0.10, step: "Downloading images from Firebase...")
        
        // Log document data for debugging
        print("📋 Word Report: Processing \(conflictCase.documents.count) documents")
        for (index, doc) in conflictCase.documents.enumerated() {
            print("📄 Document \(index + 1) [\(doc.type.displayName)]:")
            print("   - originalImageBase64: \(doc.originalImageBase64 != nil ? "\(doc.originalImageBase64!.prefix(50))..." : "nil")")
            print("   - processedImageBase64: \(doc.processedImageBase64 != nil ? "\(doc.processedImageBase64!.prefix(50))..." : "nil")")
            print("   - originalImageURLs: \(doc.originalImageURLs)")
            print("   - processedImageURLs: \(doc.processedImageURLs)")
            print("   - signatureImageBase64: \(doc.signatureImageBase64 != nil ? "\(doc.signatureImageBase64!.prefix(50))..." : "nil")")
        }
        
        // Extract and save images from documents (both scanned images and signatures)
        var imageFiles: [(name: String, data: Data, docIndex: Int, isSignature: Bool)] = []
        for (index, doc) in conflictCase.documents.enumerated() {
            // Extract scanned document image - try base64 first, then download from URL
            var scannedImageData: Data? = nil
            
            // Strategy 1: Try base64 data (local storage)
            if let base64String = doc.processedImageBase64 ?? doc.originalImageBase64,
               let cleanBase64 = cleanBase64String(base64String),
               let imageData = Data(base64Encoded: cleanBase64) {
                scannedImageData = imageData
                print("📷 Document \(index + 1): Found base64 image data (\(imageData.count) bytes)")
            }
            
            // Strategy 2: Download from Firebase Storage URL
            if scannedImageData == nil {
                let urls = !doc.processedImageURLs.isEmpty ? doc.processedImageURLs : doc.originalImageURLs
                if let firstURL = urls.first, let url = URL(string: firstURL) {
                    print("📷 Document \(index + 1): Downloading image from \(firstURL.prefix(80))...")
                    if let downloadedData = try? await downloadImageData(from: url) {
                        scannedImageData = downloadedData
                        print("✅ Document \(index + 1): Downloaded image (\(downloadedData.count) bytes)")
                    } else {
                        print("⚠️ Document \(index + 1): Failed to download image from URL")
                    }
                } else {
                    print("⚠️ Document \(index + 1): No image URLs available")
                }
            }
            
            // Save scanned image if we got it
            if let imageData = scannedImageData {
                let imageName = "image\(index + 1).png"
                imageFiles.append((name: imageName, data: imageData, docIndex: index, isSignature: false))
                try imageData.write(to: mediaDir.appendingPathComponent(imageName))
                print("✅ Document \(index + 1): Saved scanned image as \(imageName)")
            } else {
                print("⚠️ Document \(index + 1): No scanned image found")
            }
            
            // Extract signature image
            // NOTE: signatureImageBase64 may contain EITHER base64 data OR a Firebase Storage URL
            if let sigField = doc.signatureImageBase64, !sigField.isEmpty {
                print("✍️ Document \(index + 1): Signature field found (\(sigField.count) chars)")
                var sigData: Data? = nil
                
                // Check if it's a URL (Firebase Storage URL starts with https://)
                if sigField.hasPrefix("https://") || sigField.hasPrefix("http://") {
                    print("   - Signature is a URL, downloading from Firebase...")
                    if let url = URL(string: sigField) {
                        sigData = try? await downloadImageData(from: url)
                        if sigData != nil {
                            print("   ✅ Downloaded signature from Firebase (\(sigData!.count) bytes)")
                        } else {
                            print("   ❌ Failed to download signature from URL")
                        }
                    }
                } else {
                    // Try to decode as base64
                    print("   - Signature appears to be base64, decoding...")
                    if let cleanSigBase64 = cleanBase64String(sigField) {
                        sigData = Data(base64Encoded: cleanSigBase64)
                        if sigData != nil {
                            print("   ✅ Decoded signature base64 (\(sigData!.count) bytes)")
                        } else {
                            print("   ❌ Failed to decode signature base64")
                        }
                    }
                }
                
                // Save signature if we got it
                if let data = sigData {
                    let sigName = "signature\(index + 1).png"
                    imageFiles.append((name: sigName, data: data, docIndex: index, isSignature: true))
                    try data.write(to: mediaDir.appendingPathComponent(sigName))
                    print("✅ Document \(index + 1): Saved signature image")
                }
            } else {
                print("   Document \(index + 1): No signature field")
            }
        }
        
        print("📊 Total images extracted: \(imageFiles.count) (scanned: \(imageFiles.filter{!$0.isSignature}.count), signatures: \(imageFiles.filter{$0.isSignature}.count))")
        
        updateProgress(0.30, step: "Generating document structure...")
        
        // Generate XML files with image support
        let contentTypes = generateContentTypes(hasImages: !imageFiles.isEmpty)
        let rels = generateRels()
        let documentRels = generateDocumentRels(imageFiles: imageFiles)
        let styles = generateStyles()
        let documentXML = generateDocumentXML(conflictCase: conflictCase, config: config, imageFiles: imageFiles)
        let headerXML = generateHeaderXML(caseNumber: conflictCase.caseNumber, config: config)
        let footerXML = generateFooterXML(facilityName: conflictCase.facilityName)
        
        updateProgress(0.70, step: "Writing document files...")
        
        // Write files
        try contentTypes.write(to: tempDir.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)
        try rels.write(to: relsDir.appendingPathComponent(".rels"), atomically: true, encoding: .utf8)
        try documentRels.write(to: wordRelsDir.appendingPathComponent("document.xml.rels"), atomically: true, encoding: .utf8)
        try documentXML.write(to: wordDir.appendingPathComponent("document.xml"), atomically: true, encoding: .utf8)
        try styles.write(to: wordDir.appendingPathComponent("styles.xml"), atomically: true, encoding: .utf8)
        try headerXML.write(to: wordDir.appendingPathComponent("header1.xml"), atomically: true, encoding: .utf8)
        try footerXML.write(to: wordDir.appendingPathComponent("footer1.xml"), atomically: true, encoding: .utf8)
        
        updateProgress(0.85, step: "Creating Word document...")
        
        // Create ZIP archive (DOCX) using ZIPFoundation
        let docxPath = tempDir.appendingPathComponent("report.docx")
        
        // Create the archive
        guard let archive = Archive(url: docxPath, accessMode: .create) else {
            throw NSError(domain: "CaseWordReportService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create DOCX archive"])
        }
        
        // Add files to archive (excluding the docx output and .DS_Store)
        let fileManager = FileManager.default
        if let enumerator = fileManager.enumerator(at: tempDir, includingPropertiesForKeys: [.isRegularFileKey], options: []) {
            while let fileURL = enumerator.nextObject() as? URL {
                let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if resourceValues?.isRegularFile == true {
                    let fileName = fileURL.lastPathComponent
                    // Skip output file and macOS metadata
                    if fileName == "report.docx" || fileName == ".DS_Store" {
                        continue
                    }
                    let relativePath = fileURL.path.replacingOccurrences(of: tempDir.path + "/", with: "")
                    try archive.addEntry(with: relativePath, fileURL: fileURL, compressionMethod: .deflate)
                }
            }
        }
        
        updateProgress(0.95, step: "Finalizing...")
        
        let data = try Data(contentsOf: docxPath)
        return data
    }
    
    private func updateProgress(_ progress: Double, step: String) {
        Task { @MainActor in
            self.generationProgress = progress
            self.currentStep = step
        }
    }
    
    // Helper to clean base64 string (remove data URL prefix if present)
    private func cleanBase64String(_ base64: String) -> String? {
        if base64.contains(",") {
            // Has data URL prefix like "data:image/png;base64,"
            return String(base64.split(separator: ",").last ?? "")
        }
        return base64
    }
    
    // Helper to download image data from Firebase Storage URL
    private func downloadImageData(from url: URL) async throws -> Data? {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("⚠️ Image download failed with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            return nil
        }
        
        // Verify it's actually image data
        if data.count < 100 {
            print("⚠️ Downloaded data too small to be an image: \(data.count) bytes")
            return nil
        }
        
        return data
    }
    
    // MARK: - Content Types XML
    
    private func generateContentTypes(hasImages: Bool = false) -> String {
        var imageDefault = ""
        if hasImages {
            imageDefault = """
                <Default Extension="png" ContentType="image/png"/>
                <Default Extension="jpeg" ContentType="image/jpeg"/>
                <Default Extension="jpg" ContentType="image/jpeg"/>
            """
        }
        
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            \(imageDefault)
            <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
            <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
            <Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>
            <Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>
        </Types>
        """
    }
    
    // MARK: - Relationships XML
    
    private func generateRels() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """
    }
    
    private func generateDocumentRels(imageFiles: [(name: String, data: Data, docIndex: Int, isSignature: Bool)] = []) -> String {
        var imageRels = ""
        // Images start at rId4 (rId1=styles, rId2=header, rId3=footer)
        for (index, imageFile) in imageFiles.enumerated() {
            let rId = index + 4  // rId4, rId5, etc.
            imageRels += """
                <Relationship Id="rId\(rId)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/\(imageFile.name)"/>
            
            """
        }
        
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
            <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>
            <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>
            \(imageRels)
        </Relationships>
        """
    }
    
    // MARK: - Styles XML
    
    private func generateStyles() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:docDefaults>
                <w:rPrDefault>
                    <w:rPr>
                        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>
                        <w:sz w:val="22"/>
                        <w:szCs w:val="22"/>
                        <w:color w:val="\(textColorHex)"/>
                    </w:rPr>
                </w:rPrDefault>
            </w:docDefaults>
            <w:style w:type="paragraph" w:styleId="Title">
                <w:name w:val="Title"/>
                <w:pPr>
                    <w:jc w:val="center"/>
                    <w:spacing w:after="200"/>
                </w:pPr>
                <w:rPr>
                    <w:b/>
                    <w:sz w:val="56"/>
                    <w:szCs w:val="56"/>
                    <w:color w:val="\(primaryColorHex)"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="Heading1">
                <w:name w:val="Heading 1"/>
                <w:pPr>
                    <w:spacing w:before="240" w:after="120"/>
                    <w:shd w:val="clear" w:color="auto" w:fill="\(primaryColorHex)"/>
                </w:pPr>
                <w:rPr>
                    <w:b/>
                    <w:sz w:val="28"/>
                    <w:szCs w:val="28"/>
                    <w:color w:val="FFFFFF"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="Heading2">
                <w:name w:val="Heading 2"/>
                <w:pPr>
                    <w:spacing w:before="200" w:after="80"/>
                    <w:pBdr>
                        <w:bottom w:val="single" w:sz="8" w:space="4" w:color="\(secondaryColorHex)"/>
                    </w:pBdr>
                </w:pPr>
                <w:rPr>
                    <w:b/>
                    <w:sz w:val="24"/>
                    <w:szCs w:val="24"/>
                    <w:color w:val="\(primaryColorHex)"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="Label">
                <w:name w:val="Label"/>
                <w:rPr>
                    <w:b/>
                    <w:sz w:val="18"/>
                    <w:szCs w:val="18"/>
                    <w:color w:val="\(subtleTextColorHex)"/>
                </w:rPr>
            </w:style>
            <w:style w:type="paragraph" w:styleId="ConfidentialBanner">
                <w:name w:val="Confidential Banner"/>
                <w:pPr>
                    <w:jc w:val="center"/>
                    <w:spacing w:before="100" w:after="100"/>
                </w:pPr>
                <w:rPr>
                    <w:b/>
                    <w:sz w:val="24"/>
                    <w:szCs w:val="24"/>
                    <w:color w:val="FFFFFF"/>
                </w:rPr>
            </w:style>
            <w:style w:type="table" w:styleId="InfoTable">
                <w:name w:val="Info Table"/>
                <w:tblPr>
                    <w:tblBorders>
                        <w:top w:val="single" w:sz="4" w:space="0" w:color="\(borderColorHex)"/>
                        <w:left w:val="single" w:sz="4" w:space="0" w:color="\(borderColorHex)"/>
                        <w:bottom w:val="single" w:sz="4" w:space="0" w:color="\(borderColorHex)"/>
                        <w:right w:val="single" w:sz="4" w:space="0" w:color="\(borderColorHex)"/>
                        <w:insideH w:val="single" w:sz="4" w:space="0" w:color="\(borderColorHex)"/>
                        <w:insideV w:val="single" w:sz="4" w:space="0" w:color="\(borderColorHex)"/>
                    </w:tblBorders>
                </w:tblPr>
            </w:style>
        </w:styles>
        """
    }
    
    // MARK: - Header XML
    
    private func generateHeaderXML(caseNumber: String, config: WordReportConfiguration) -> String {
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:p>
                <w:pPr>
                    <w:tabs>
                        <w:tab w:val="center" w:pos="4680"/>
                        <w:tab w:val="right" w:pos="9360"/>
                    </w:tabs>
                </w:pPr>
                <w:r>
                    <w:rPr>
                        <w:b/>
                        <w:sz w:val="16"/>
                        <w:color w:val="\(config.confidentialityLevel.colorHex)"/>
                    </w:rPr>
                    <w:t>\(escapeXML(config.confidentialityLevel.rawValue))</w:t>
                </w:r>
                <w:r>
                    <w:tab/>
                </w:r>
                <w:r>
                    <w:rPr>
                        <w:sz w:val="16"/>
                        <w:color w:val="\(subtleTextColorHex)"/>
                    </w:rPr>
                    <w:t>Case #\(escapeXML(caseNumber))</w:t>
                </w:r>
            </w:p>
            <w:p>
                <w:pPr>
                    <w:pBdr>
                        <w:bottom w:val="single" w:sz="4" w:space="1" w:color="\(borderColorHex)"/>
                    </w:pBdr>
                </w:pPr>
            </w:p>
        </w:hdr>
        """
    }
    
    // MARK: - Footer XML
    
    private func generateFooterXML(facilityName: String?) -> String {
        let timestamp = timestampFormatter.string(from: Date())
        
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:p>
                <w:pPr>
                    <w:pBdr>
                        <w:top w:val="single" w:sz="4" w:space="1" w:color="\(borderColorHex)"/>
                    </w:pBdr>
                    <w:tabs>
                        <w:tab w:val="right" w:pos="9360"/>
                    </w:tabs>
                </w:pPr>
                <w:r>
                    <w:rPr>
                        <w:sz w:val="16"/>
                        <w:color w:val="\(subtleTextColorHex)"/>
                    </w:rPr>
                    <w:t>Generated by DashMet Intelligence • \(escapeXML(timestamp))</w:t>
                </w:r>
                <w:r>
                    <w:tab/>
                </w:r>
                <w:r>
                    <w:rPr>
                        <w:sz w:val="16"/>
                        <w:color w:val="\(subtleTextColorHex)"/>
                    </w:rPr>
                    <w:t>Page </w:t>
                </w:r>
                <w:r>
                    <w:fldChar w:fldCharType="begin"/>
                </w:r>
                <w:r>
                    <w:instrText xml:space="preserve"> PAGE </w:instrText>
                </w:r>
                <w:r>
                    <w:fldChar w:fldCharType="end"/>
                </w:r>
            </w:p>
        </w:ftr>
        """
    }
    
    // MARK: - Document XML Generation
    
    private func generateDocumentXML(conflictCase: ConflictCase, config: WordReportConfiguration, imageFiles: [(name: String, data: Data, docIndex: Int, isSignature: Bool)] = []) -> String {
        var content = ""
        
        // Cover page
        content += generateCoverPage(conflictCase: conflictCase, config: config)
        
        // Page break after cover
        content += pageBreak()
        
        // Table of Contents
        content += generateTableOfContents(config: config, conflictCase: conflictCase)
        content += pageBreak()
        
        var sectionNumber = 1
        
        // Executive Summary
        if config.includeExecutiveSummary {
            content += generateSectionHeader("\(sectionNumber). EXECUTIVE SUMMARY")
            content += generateExecutiveSummary(conflictCase: conflictCase)
            content += pageBreak()
            sectionNumber += 1
        }
        
        // Case Details
        if config.includeCaseDetails {
            content += generateSectionHeader("\(sectionNumber). CASE DETAILS")
            content += generateCaseDetails(conflictCase: conflictCase)
            content += pageBreak()
            sectionNumber += 1
        }
        
        // Involved Parties
        if config.includeInvolvedParties {
            content += generateSectionHeader("\(sectionNumber). INVOLVED PARTIES")
            content += generateInvolvedParties(conflictCase: conflictCase)
            content += pageBreak()
            sectionNumber += 1
        }
        
        // Full Statements
        if config.includeFullStatements {
            content += generateSectionHeader("\(sectionNumber). COMPLAINT STATEMENTS")
            content += generateFullStatements(conflictCase: conflictCase, imageFiles: imageFiles)
            content += pageBreak()
            sectionNumber += 1
        }
        
        // Scanned Documents Summary with embedded images
        if config.includeScannedDocuments {
            content += generateSectionHeader("\(sectionNumber). SCANNED DOCUMENTS & EVIDENCE")
            content += generateScannedDocumentsSummary(conflictCase: conflictCase, imageFiles: imageFiles)
            content += pageBreak()
            sectionNumber += 1
        }
        
        // DashMet Intelligence Analysis
        if config.includeAIAnalysis, conflictCase.comparisonResult != nil {
            content += generateSectionHeader("\(sectionNumber). DASHMET INTELLIGENCE ANALYSIS RESULTS")
            content += generateAIAnalysis(conflictCase: conflictCase)
            content += pageBreak()
            sectionNumber += 1
        }
        
        // Policy Matches
        if config.includePolicyMatches, !conflictCase.policyMatches.isEmpty {
            content += generateSectionHeader("\(sectionNumber). POLICY ALIGNMENTS")
            content += generatePolicyMatches(conflictCase: conflictCase)
            content += pageBreak()
            sectionNumber += 1
        }
        
        // Recommendations
        if config.includeRecommendations, !conflictCase.recommendations.isEmpty {
            content += generateSectionHeader("\(sectionNumber). RECOMMENDED ACTIONS")
            content += generateRecommendations(conflictCase: conflictCase)
            content += pageBreak()
            sectionNumber += 1
        }
        
        // Selected Action
        if config.includeSelectedAction || config.includeGeneratedDocument {
            content += generateSectionHeader("\(sectionNumber). SELECTED ACTION & DOCUMENTATION")
            content += generateSelectedAction(conflictCase: conflictCase)
            content += pageBreak()
            sectionNumber += 1
        }
        
        // Supervisor Notes
        if let notes = conflictCase.supervisorNotes, !notes.isEmpty {
            content += generateSectionHeader("\(sectionNumber). SUPERVISOR NOTES & REVIEW COMMENTS")
            content += generateSupervisorNotes(notes: notes, decision: conflictCase.supervisorDecision)
            content += pageBreak()
            sectionNumber += 1
        }
        
        // Audit Trail
        if config.includeAuditTrail, !conflictCase.auditLog.isEmpty {
            content += generateSectionHeader("\(sectionNumber). COMPLETE AUDIT TRAIL")
            content += generateAuditTrail(conflictCase: conflictCase)
            content += pageBreak()
            sectionNumber += 1
        }
        
        // Signature Blocks
        if config.includeSignatureBlocks {
            content += generateSectionHeader("\(sectionNumber). CERTIFICATIONS & SIGNATURES")
            content += generateSignatureBlocks()
        }
        
        return wrapDocumentXML(content: content)
    }
    
    // MARK: - Cover Page
    
    private func generateCoverPage(conflictCase: ConflictCase, config: WordReportConfiguration) -> String {
        let facilityName = conflictCase.facilityName ?? ""
        let creatorName = conflictCase.creatorName ?? "System"
        let preparerName = config.preparedBy.isEmpty ? creatorName : config.preparedBy
        
        var xml = ""
        
        // Facility name at top
        if !facilityName.isEmpty {
            xml += """
            <w:p>
                <w:pPr>
                    <w:spacing w:before="200"/>
                </w:pPr>
                <w:r>
                    <w:rPr>
                        <w:sz w:val="24"/>
                        <w:color w:val="\(subtleTextColorHex)"/>
                    </w:rPr>
                    <w:t>\(escapeXML(facilityName.uppercased()))</w:t>
                </w:r>
            </w:p>
            """
        }
        
        // Main Title
        xml += """
        <w:p>
            <w:pPr>
                <w:pStyle w:val="Title"/>
                <w:spacing w:before="600"/>
            </w:pPr>
            <w:r>
                <w:rPr>
                    <w:b/>
                    <w:sz w:val="56"/>
                    <w:color w:val="\(primaryColorHex)"/>
                </w:rPr>
                <w:t>\(escapeXML(config.reportTitle.uppercased()))</w:t>
            </w:r>
        </w:p>
        """
        
        // Subtitle
        xml += """
        <w:p>
            <w:pPr>
                <w:jc w:val="center"/>
                <w:spacing w:after="400"/>
            </w:pPr>
            <w:r>
                <w:rPr>
                    <w:sz w:val="28"/>
                    <w:color w:val="\(subtleTextColorHex)"/>
                </w:rPr>
                <w:t>Official Investigation Documentation</w:t>
            </w:r>
        </w:p>
        """
        
        // Confidentiality Banner
        xml += """
        <w:p>
            <w:pPr>
                <w:pStyle w:val="ConfidentialBanner"/>
                <w:shd w:val="clear" w:color="auto" w:fill="\(config.confidentialityLevel.colorHex)"/>
                <w:spacing w:before="200" w:after="200"/>
            </w:pPr>
            <w:r>
                <w:rPr>
                    <w:b/>
                    <w:color w:val="FFFFFF"/>
                </w:rPr>
                <w:t>🔒 \(escapeXML(config.confidentialityLevel.rawValue))</w:t>
            </w:r>
        </w:p>
        """
        
        // Case Number Box
        xml += """
        <w:p>
            <w:pPr>
                <w:jc w:val="center"/>
                <w:pBdr>
                    <w:top w:val="single" w:sz="12" w:space="8" w:color="\(primaryColorHex)"/>
                    <w:left w:val="single" w:sz="12" w:space="8" w:color="\(primaryColorHex)"/>
                    <w:bottom w:val="single" w:sz="12" w:space="8" w:color="\(primaryColorHex)"/>
                    <w:right w:val="single" w:sz="12" w:space="8" w:color="\(primaryColorHex)"/>
                </w:pBdr>
                <w:shd w:val="clear" w:color="auto" w:fill="\(accentColorHex)"/>
                <w:spacing w:before="400" w:after="400"/>
            </w:pPr>
            <w:r>
                <w:rPr>
                    <w:b/>
                    <w:sz w:val="36"/>
                    <w:color w:val="\(primaryColorHex)"/>
                </w:rPr>
                <w:t>📋 Case Number: \(escapeXML(conflictCase.caseNumber))</w:t>
            </w:r>
        </w:p>
        """
        
        // Case Information Table
        xml += generateCoverInfoTable(conflictCase: conflictCase)
        
        // Prepared By Section
        xml += """
        <w:p>
            <w:pPr>
                <w:spacing w:before="800"/>
                <w:shd w:val="clear" w:color="auto" w:fill="\(accentColorHex)"/>
                <w:pBdr>
                    <w:top w:val="single" w:sz="4" w:space="4" w:color="\(borderColorHex)"/>
                    <w:left w:val="single" w:sz="4" w:space="4" w:color="\(borderColorHex)"/>
                    <w:bottom w:val="single" w:sz="4" w:space="4" w:color="\(borderColorHex)"/>
                    <w:right w:val="single" w:sz="4" w:space="4" w:color="\(borderColorHex)"/>
                </w:pBdr>
            </w:pPr>
        </w:p>
        """
        
        xml += labelValueParagraph("📝 PREPARED BY", preparerName)
        xml += labelValueParagraph("🕐 REPORT GENERATED", fullDateFormatter.string(from: Date()))
        
        if !config.preparedFor.isEmpty {
            xml += labelValueParagraph("📨 PREPARED FOR", config.preparedFor)
        }
        
        if !conflictCase.department.isEmpty {
            xml += labelValueParagraph("🏛️ DEPARTMENT", conflictCase.department)
        }
        
        return xml
    }
    
    private func generateCoverInfoTable(conflictCase: ConflictCase) -> String {
        let location = conflictCase.location.isEmpty ? (conflictCase.facilityName ?? "Not Specified") : conflictCase.location
        let shift = conflictCase.shift ?? "Not Specified"
        let creatorName = conflictCase.creatorName ?? "System"
        
        let rows: [(String, String, String, String)] = [
            ("📁 CASE TYPE", conflictCase.type.displayName, "📊 STATUS", conflictCase.status.displayName),
            ("📅 INCIDENT DATE", shortDateFormatter.string(from: conflictCase.incidentDate), "🏢 DEPARTMENT", conflictCase.department),
            ("📍 LOCATION", location, "⏰ SHIFT", shift),
            ("👤 CREATED BY", creatorName, "📆 CREATED", shortDateFormatter.string(from: conflictCase.createdAt)),
            ("🔄 LAST UPDATED", shortDateFormatter.string(from: conflictCase.updatedAt), "👥 PARTIES", "\(conflictCase.involvedEmployees.count) person(s)")
        ]
        
        var xml = """
        <w:tbl>
            <w:tblPr>
                <w:tblW w:w="9360" w:type="dxa"/>
                <w:jc w:val="center"/>
                <w:tblCellMar>
                    <w:top w:w="100" w:type="dxa"/>
                    <w:left w:w="140" w:type="dxa"/>
                    <w:bottom w:w="100" w:type="dxa"/>
                    <w:right w:w="140" w:type="dxa"/>
                </w:tblCellMar>
                <w:tblBorders>
                    <w:top w:val="single" w:sz="4" w:space="0" w:color="\(borderColorHex)"/>
                    <w:left w:val="single" w:sz="4" w:space="0" w:color="\(borderColorHex)"/>
                    <w:bottom w:val="single" w:sz="4" w:space="0" w:color="\(borderColorHex)"/>
                    <w:right w:val="single" w:sz="4" w:space="0" w:color="\(borderColorHex)"/>
                    <w:insideH w:val="single" w:sz="4" w:space="0" w:color="\(borderColorHex)"/>
                    <w:insideV w:val="single" w:sz="4" w:space="0" w:color="\(borderColorHex)"/>
                </w:tblBorders>
            </w:tblPr>
        """
        
        for row in rows {
            xml += """
            <w:tr>
                <w:tc>
                    <w:tcPr><w:tcW w:w="2340" w:type="dxa"/><w:shd w:val="clear" w:color="auto" w:fill="\(accentColorHex)"/><w:vAlign w:val="center"/></w:tcPr>
                    <w:p>
                        <w:pPr><w:spacing w:before="40" w:after="20"/></w:pPr>
                        <w:r><w:rPr><w:b/><w:sz w:val="18"/><w:color w:val="\(subtleTextColorHex)"/></w:rPr><w:t>\(escapeXML(row.0))</w:t></w:r>
                    </w:p>
                    <w:p>
                        <w:pPr><w:spacing w:before="20" w:after="40"/></w:pPr>
                        <w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t>\(escapeXML(row.1))</w:t></w:r>
                    </w:p>
                </w:tc>
                <w:tc>
                    <w:tcPr><w:tcW w:w="2340" w:type="dxa"/><w:shd w:val="clear" w:color="auto" w:fill="\(accentColorHex)"/><w:vAlign w:val="center"/></w:tcPr>
                    <w:p>
                        <w:pPr><w:spacing w:before="40" w:after="20"/></w:pPr>
                        <w:r><w:rPr><w:b/><w:sz w:val="18"/><w:color w:val="\(subtleTextColorHex)"/></w:rPr><w:t>\(escapeXML(row.2))</w:t></w:r>
                    </w:p>
                    <w:p>
                        <w:pPr><w:spacing w:before="20" w:after="40"/></w:pPr>
                        <w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t>\(escapeXML(row.3))</w:t></w:r>
                    </w:p>
                </w:tc>
            </w:tr>
            """
        }
        
        xml += "</w:tbl>"
        return xml
    }
    
    // MARK: - Section Generation Methods
    
    private func generateSectionHeader(_ title: String) -> String {
        return """
        <w:p>
            <w:pPr>
                <w:pStyle w:val="Heading1"/>
                <w:spacing w:before="240" w:after="120"/>
            </w:pPr>
            <w:r>
                <w:rPr><w:b/><w:color w:val="FFFFFF"/></w:rPr>
                <w:t>  \(escapeXML(title))</w:t>
            </w:r>
        </w:p>
        """
    }
    
    private func generateSubsectionHeader(_ title: String) -> String {
        return """
        <w:p>
            <w:pPr>
                <w:pStyle w:val="Heading2"/>
                <w:spacing w:before="240" w:after="120"/>
            </w:pPr>
            <w:r>
                <w:t>\(escapeXML(title))</w:t>
            </w:r>
        </w:p>
        """
    }
    
    private func generateTableOfContents(config: WordReportConfiguration, conflictCase: ConflictCase) -> String {
        var xml = generateSubsectionHeader("TABLE OF CONTENTS")
        var sectionNum = 1
        
        let sections: [(Bool, String)] = [
            (config.includeExecutiveSummary, "Executive Summary"),
            (config.includeCaseDetails, "Case Details"),
            (config.includeInvolvedParties, "Involved Parties"),
            (config.includeFullStatements, "Complaint Statements"),
            (config.includeScannedDocuments, "Scanned Documents & Evidence"),
            (config.includeAIAnalysis && conflictCase.comparisonResult != nil, "DashMet Intelligence Analysis Results"),
            (config.includePolicyMatches && !conflictCase.policyMatches.isEmpty, "Policy Alignments"),
            (config.includeRecommendations && !conflictCase.recommendations.isEmpty, "Recommended Actions"),
            (config.includeSelectedAction || config.includeGeneratedDocument, "Selected Action & Documentation"),
            (conflictCase.supervisorNotes != nil && !conflictCase.supervisorNotes!.isEmpty, "Supervisor Notes & Review Comments"),
            (config.includeAuditTrail && !conflictCase.auditLog.isEmpty, "Complete Audit Trail"),
            (config.includeSignatureBlocks, "Certifications & Signatures")
        ]
        
        for (include, title) in sections where include {
            xml += """
            <w:p>
                <w:pPr>
                    <w:tabs>
                        <w:tab w:val="right" w:leader="dot" w:pos="9360"/>
                    </w:tabs>
                </w:pPr>
                <w:r>
                    <w:t>\(sectionNum). \(escapeXML(title))</w:t>
                </w:r>
                <w:r>
                    <w:tab/>
                </w:r>
            </w:p>
            """
            sectionNum += 1
        }
        
        return xml
    }
    
    private func generateExecutiveSummary(conflictCase: ConflictCase) -> String {
        var xml = ""
        
        let complainants = conflictCase.involvedEmployees.filter { $0.isComplainant }
        let witnesses = conflictCase.witnesses
        let hasAnalysis = conflictCase.comparisonResult != nil
        let hasAction = conflictCase.selectedAction != nil
        
        let summaryText = """
        This report documents Case #\(conflictCase.caseNumber), a \(conflictCase.type.displayName.lowercased()) case reported on \(shortDateFormatter.string(from: conflictCase.incidentDate)). The case involves \(complainants.count) primary party(ies) and \(witnesses.count) witness(es) from the \(conflictCase.department) department.
        
        Current Status: \(conflictCase.status.displayName)
        \(hasAnalysis ? "DashMet Intelligence analysis has been completed for this case." : "DashMet Intelligence analysis pending.")
        \(hasAction ? "Selected Action: \(conflictCase.selectedAction!.displayName)" : "Final action pending supervisor decision.")
        """
        
        xml += paragraph(summaryText)
        
        // Quick stats table
        xml += generateSubsectionHeader("Quick Statistics")
        
        let stats: [(String, String)] = [
            ("Total Parties Involved", "\(conflictCase.involvedEmployees.count)"),
            ("Documents Collected", "\(conflictCase.documents.count)"),
            ("Policy Matches Found", "\(conflictCase.policyMatches.count)"),
            ("DashMet Recommendations", "\(conflictCase.recommendations.count)"),
            ("Audit Log Entries", "\(conflictCase.auditLog.count)")
        ]
        
        xml += generateSimpleTable(items: stats)
        
        return xml
    }
    
    private func generateCaseDetails(conflictCase: ConflictCase) -> String {
        var xml = ""
        
        let location = conflictCase.location.isEmpty ? (conflictCase.facilityName ?? "Not Specified") : conflictCase.location
        let shift = conflictCase.shift ?? "Not Specified"
        let creatorName = conflictCase.creatorName ?? "System"
        
        let details: [(String, String)] = [
            ("Case Number", conflictCase.caseNumber),
            ("Case Type", conflictCase.type.displayName),
            ("Current Status", conflictCase.status.displayName),
            ("Incident Date", shortDateFormatter.string(from: conflictCase.incidentDate)),
            ("Department", conflictCase.department),
            ("Location", location),
            ("Shift", shift),
            ("Created By", creatorName),
            ("Created At", fullDateFormatter.string(from: conflictCase.createdAt)),
            ("Last Updated", fullDateFormatter.string(from: conflictCase.updatedAt))
        ]
        
        xml += generateSimpleTable(items: details)
        
        if !conflictCase.description.isEmpty {
            xml += generateSubsectionHeader("Case Description")
            xml += paragraph(conflictCase.description)
        }
        
        return xml
    }
    
    private func generateInvolvedParties(conflictCase: ConflictCase) -> String {
        var xml = ""
        
        let complainants = conflictCase.involvedEmployees.filter { $0.isComplainant }
        let witnesses = conflictCase.witnesses
        
        xml += generateSubsectionHeader("Primary Parties (\(complainants.count))")
        
        for (index, person) in complainants.enumerated() {
            xml += generatePersonCard(person, index: index + 1, role: "Primary Party", conflictCase: conflictCase)
        }
        
        if !witnesses.isEmpty {
            xml += generateSubsectionHeader("Witnesses (\(witnesses.count))")
            
            for (index, person) in witnesses.enumerated() {
                xml += generatePersonCard(person, index: index + 1, role: "Witness", conflictCase: conflictCase)
            }
        }
        
        return xml
    }
    
    private func generatePersonCard(_ person: InvolvedEmployee, index: Int, role: String, conflictCase: ConflictCase) -> String {
        let roleColorHex = role == "Primary Party" ? "2980B9" : "27AE60"
        
        // Check for statement/signature - same logic as PDF
        var hasStatement = false
        var hasSignature = false
        
        if person.isComplainant {
            let complainants = conflictCase.involvedEmployees.filter { $0.isComplainant }
            if let idx = complainants.firstIndex(where: { $0.id == person.id }) {
                if idx == 0 {
                    if let docA = conflictCase.documents.first(where: { $0.type == .complaintA }) {
                        hasStatement = !docA.cleanedText.isEmpty || !docA.originalText.isEmpty || !docA.originalImageURLs.isEmpty
                        hasSignature = docA.signatureImageBase64 != nil && !docA.signatureImageBase64!.isEmpty
                    }
                } else if idx == 1 {
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
        
        let statementStatus = hasStatement ? "Yes ✓" : "No"
        let signatureStatus = hasSignature ? "Captured ✓" : "Not Captured"
        let statementColorHex = hasStatement ? "27AE60" : "C0392B"
        let signatureColorHex = hasSignature ? "27AE60" : "E67E22"
        
        return """
        <w:p>
            <w:pPr>
                <w:pBdr>
                    <w:left w:val="single" w:sz="24" w:space="4" w:color="\(roleColorHex)"/>
                    <w:top w:val="single" w:sz="4" w:space="4" w:color="\(borderColorHex)"/>
                    <w:bottom w:val="single" w:sz="4" w:space="4" w:color="\(borderColorHex)"/>
                    <w:right w:val="single" w:sz="4" w:space="4" w:color="\(borderColorHex)"/>
                </w:pBdr>
                <w:shd w:val="clear" w:color="auto" w:fill="FFFFFF"/>
                <w:spacing w:before="200" w:after="100"/>
            </w:pPr>
            <w:r>
                <w:rPr><w:b/><w:sz w:val="28"/></w:rPr>
                <w:t>\(escapeXML(person.name))</w:t>
            </w:r>
            <w:r>
                <w:t>  </w:t>
            </w:r>
            <w:r>
                <w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="\(roleColorHex)"/><w:shd w:val="clear" w:color="auto" w:fill="\(roleColorHex)20"/></w:rPr>
                <w:t> \(escapeXML(role)) #\(index) </w:t>
            </w:r>
        </w:p>
        <w:tbl>
            <w:tblPr>
                <w:tblW w:w="9360" w:type="dxa"/>
                <w:tblBorders>
                    <w:top w:val="nil"/>
                    <w:left w:val="single" w:sz="24" w:space="0" w:color="\(roleColorHex)"/>
                    <w:bottom w:val="single" w:sz="4" w:space="0" w:color="\(borderColorHex)"/>
                    <w:right w:val="single" w:sz="4" w:space="0" w:color="\(borderColorHex)"/>
                </w:tblBorders>
                <w:tblCellMar>
                    <w:top w:w="100" w:type="dxa"/>
                    <w:left w:w="160" w:type="dxa"/>
                    <w:bottom w:w="100" w:type="dxa"/>
                    <w:right w:w="160" w:type="dxa"/>
                </w:tblCellMar>
            </w:tblPr>
            <w:tr>
                <w:tc>
                    <w:tcPr><w:tcW w:w="4680" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>
                    <w:p><w:pPr><w:spacing w:before="60" w:after="60"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="\(subtleTextColorHex)"/></w:rPr><w:t>Employee ID:</w:t></w:r><w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t xml:space="preserve">  \(escapeXML(person.employeeId ?? "Not Provided"))</w:t></w:r></w:p>
                </w:tc>
                <w:tc>
                    <w:tcPr><w:tcW w:w="4680" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>
                    <w:p><w:pPr><w:spacing w:before="60" w:after="60"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="\(subtleTextColorHex)"/></w:rPr><w:t>Department:</w:t></w:r><w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t xml:space="preserve">  \(escapeXML(person.department))</w:t></w:r></w:p>
                </w:tc>
            </w:tr>
            <w:tr>
                <w:tc>
                    <w:tcPr><w:tcW w:w="4680" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>
                    <w:p><w:pPr><w:spacing w:before="60" w:after="60"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="\(subtleTextColorHex)"/></w:rPr><w:t>Job Title/Role:</w:t></w:r><w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t xml:space="preserve">  \(escapeXML(person.role.isEmpty ? "Not Specified" : person.role))</w:t></w:r></w:p>
                </w:tc>
                <w:tc>
                    <w:tcPr><w:tcW w:w="4680" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>
                    <w:p><w:pPr><w:spacing w:before="60" w:after="60"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="\(subtleTextColorHex)"/></w:rPr><w:t>Party Type:</w:t></w:r><w:r><w:rPr><w:sz w:val="22"/></w:rPr><w:t xml:space="preserve">  \(person.isComplainant ? "Complainant" : "Witness")</w:t></w:r></w:p>
                </w:tc>
            </w:tr>
            <w:tr>
                <w:tc>
                    <w:tcPr><w:tcW w:w="4680" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>
                    <w:p><w:pPr><w:spacing w:before="60" w:after="60"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="\(subtleTextColorHex)"/></w:rPr><w:t>Statement Submitted:</w:t></w:r><w:r><w:rPr><w:b/><w:sz w:val="22"/><w:color w:val="\(statementColorHex)"/></w:rPr><w:t xml:space="preserve">  \(statementStatus)</w:t></w:r></w:p>
                </w:tc>
                <w:tc>
                    <w:tcPr><w:tcW w:w="4680" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>
                    <w:p><w:pPr><w:spacing w:before="60" w:after="60"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="\(subtleTextColorHex)"/></w:rPr><w:t>Digital Signature:</w:t></w:r><w:r><w:rPr><w:b/><w:sz w:val="22"/><w:color w:val="\(signatureColorHex)"/></w:rPr><w:t xml:space="preserve">  \(signatureStatus)</w:t></w:r></w:p>
                </w:tc>
            </w:tr>
        </w:tbl>
        """
    }
    
    private func generateFullStatements(conflictCase: ConflictCase, imageFiles: [(name: String, data: Data, docIndex: Int, isSignature: Bool)] = []) -> String {
        var xml = ""
        
        if let docA = conflictCase.complaintDocumentA {
            let docIndex = conflictCase.documents.firstIndex(where: { $0.id == docA.id }) ?? -1
            xml += generateStatementDocument(docA, title: "COMPLAINANT A STATEMENT", party: conflictCase.complainantA, conflictCase: conflictCase, docIndex: docIndex, imageFiles: imageFiles)
        }
        
        if let docB = conflictCase.complaintDocumentB {
            let docIndex = conflictCase.documents.firstIndex(where: { $0.id == docB.id }) ?? -1
            xml += generateStatementDocument(docB, title: "COMPLAINANT B STATEMENT", party: conflictCase.complainantB, conflictCase: conflictCase, docIndex: docIndex, imageFiles: imageFiles)
        }
        
        for (index, statement) in conflictCase.witnessStatements.enumerated() {
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
            
            let docIndex = conflictCase.documents.firstIndex(where: { $0.id == statement.id }) ?? -1
            xml += generateStatementDocument(statement, title: "WITNESS STATEMENT #\(index + 1)", party: witness, conflictCase: conflictCase, docIndex: docIndex, imageFiles: imageFiles)
        }
        
        if conflictCase.documents.filter({ $0.type == .complaintA || $0.type == .complaintB || $0.type == .witnessStatement }).isEmpty {
            xml += paragraph("No complaint statements have been submitted for this case.")
        }
        
        return xml
    }
    
    private func generateStatementDocument(_ doc: CaseDocument, title: String, party: InvolvedEmployee?, conflictCase: ConflictCase, docIndex: Int = -1, imageFiles: [(name: String, data: Data, docIndex: Int, isSignature: Bool)] = []) -> String {
        var xml = ""
        
        // Use comprehensive name resolution - party name first, then helper lookup, then document-specific fallback
        // NEVER show "Anonymous" - use actual witness name from submittedBy or document type description
        let resolvedName = party?.name ?? resolveEmployeeName(for: doc, in: conflictCase)
        let displayName: String
        if let name = resolvedName {
            displayName = name
        } else {
            // Fallback based on document type - no "Anonymous"
            switch doc.type {
            case .complaintA:
                displayName = "Complainant A"
            case .complaintB:
                displayName = "Complainant B"
            case .witnessStatement:
                // Use submittedBy directly if available (even if it looks like an identifier, user wants actual name)
                displayName = doc.submittedBy ?? "Witness"
            default:
                displayName = "Submitter"
            }
        }
        
        xml += generateSubsectionHeader(title)
        
        xml += """
        <w:p>
            <w:pPr>
                <w:shd w:val="clear" w:color="auto" w:fill="\(accentColorHex)"/>
                <w:pBdr>
                    <w:top w:val="single" w:sz="8" w:space="4" w:color="\(secondaryColorHex)"/>
                    <w:left w:val="single" w:sz="8" w:space="4" w:color="\(secondaryColorHex)"/>
                    <w:bottom w:val="single" w:sz="8" w:space="4" w:color="\(secondaryColorHex)"/>
                    <w:right w:val="single" w:sz="8" w:space="4" w:color="\(secondaryColorHex)"/>
                </w:pBdr>
            </w:pPr>
            <w:r>
                <w:rPr><w:sz w:val="20"/><w:color w:val="\(subtleTextColorHex)"/></w:rPr>
                <w:t>Submitted by: \(escapeXML(displayName)) | Date: \(escapeXML(fullDateFormatter.string(from: doc.createdAt))) | Pages: \(doc.pageCount)</w:t>
            </w:r>
        </w:p>
        """
        
        // Document metadata
        let details: [(String, String)] = [
            ("Document Type", doc.type.displayName),
            ("Language Detected", doc.detectedLanguage ?? "English"),
            ("Handwritten", doc.isHandwritten == true ? "Yes" : "No")
        ]
        xml += generateSimpleTable(items: details)
        
        // Statement text - Use ORIGINAL text (not cleaned), plus translated text if available
        let originalStatement = doc.originalText
        let translatedStatement = doc.translatedText
        
        if originalStatement.isEmpty && (translatedStatement?.isEmpty ?? true) {
            xml += paragraph("[No text content available for this document]")
        } else {
            // Original Statement Section
            if !originalStatement.isEmpty {
                xml += """
                <w:p>
                    <w:pPr><w:pStyle w:val="Heading2"/></w:pPr>
                    <w:r><w:t>Original Statement</w:t></w:r>
                </w:p>
                """
                xml += paragraph(originalStatement)
            }
            
            // Translated Statement Section (if exists)
            if let translated = translatedStatement, !translated.isEmpty {
                xml += """
                <w:p>
                    <w:pPr><w:pStyle w:val="Heading2"/></w:pPr>
                    <w:r><w:t>Translated Statement</w:t></w:r>
                </w:p>
                """
                xml += paragraph(translated)
            }
        }
        
        // Signature section with embedded image
        if doc.signatureImageBase64 != nil {
            xml += """
            <w:p>
                <w:pPr><w:pStyle w:val="Heading2"/></w:pPr>
                <w:r><w:t>Digital Signature</w:t></w:r>
            </w:p>
            """
            
            // Try to find and embed the signature image
            if docIndex >= 0, let sigImageIndex = imageFiles.firstIndex(where: { $0.docIndex == docIndex && $0.isSignature }) {
                // rId is the position in the imageFiles array + 4 (since rId1-3 are styles, header, footer)
                let rId = sigImageIndex + 4
                let sigImage = imageFiles[sigImageIndex]
                xml += generateSignatureImage(rId: rId, imageName: sigImage.name, imageData: sigImage.data)
            } else {
                // Fallback: just show confirmation text
                xml += """
                <w:p>
                    <w:r>
                        <w:rPr><w:color w:val="27AE60"/><w:b/></w:rPr>
                        <w:t>✓ Digital signature captured</w:t>
                    </w:r>
                </w:p>
                """
            }
            
            if let sigTime = doc.employeeSignatureTimestamp {
                xml += paragraph("Signed: \(fullDateFormatter.string(from: sigTime))")
            }
        }
        
        return xml
    }
    
    // Generate embedded signature image (smaller size than scanned documents)
    private func generateSignatureImage(rId: Int, imageName: String, imageData: Data) -> String {
        // Signatures should be smaller - default to 3 inches wide, 1 inch tall
        var widthEMU: Int64 = 2743200  // 3 inches in EMUs
        var heightEMU: Int64 = 914400  // 1 inch in EMUs
        
        if let image = UIImage(data: imageData) {
            let widthInches = image.size.width / image.scale / 72.0
            let heightInches = image.size.height / image.scale / 72.0
            
            // Cap at 3 inches wide, maintain aspect ratio
            let maxWidthInches: CGFloat = 3.0
            let scaleFactor = min(1.0, maxWidthInches / widthInches)
            
            widthEMU = Int64(widthInches * scaleFactor * 914400)
            heightEMU = Int64(heightInches * scaleFactor * 914400)
        }
        
        let escapedName = escapeXML(imageName)
        let widthStr = String(widthEMU)
        let heightStr = String(heightEMU)
        let rIdStr = String(rId)
        
        var xml = "<w:p>"
        xml += "<w:pPr><w:spacing w:before=\"100\" w:after=\"100\"/></w:pPr>"
        xml += "<w:r><w:drawing>"
        xml += "<wp:inline xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\" distT=\"0\" distB=\"0\" distL=\"0\" distR=\"0\">"
        xml += "<wp:extent cx=\"\(widthStr)\" cy=\"\(heightStr)\"/>"
        xml += "<wp:effectExtent l=\"0\" t=\"0\" r=\"0\" b=\"0\"/>"
        xml += "<wp:docPr id=\"\(rIdStr)\" name=\"\(escapedName)\"/>"
        xml += "<wp:cNvGraphicFramePr><a:graphicFrameLocks xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" noChangeAspect=\"1\"/></wp:cNvGraphicFramePr>"
        xml += "<a:graphic xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">"
        xml += "<a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">"
        xml += "<pic:pic xmlns:pic=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">"
        xml += "<pic:nvPicPr><pic:cNvPr id=\"\(rIdStr)\" name=\"\(escapedName)\"/><pic:cNvPicPr/></pic:nvPicPr>"
        xml += "<pic:blipFill><a:blip r:embed=\"rId\(rIdStr)\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"/>"
        xml += "<a:stretch><a:fillRect/></a:stretch></pic:blipFill>"
        xml += "<pic:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"\(widthStr)\" cy=\"\(heightStr)\"/></a:xfrm>"
        xml += "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></pic:spPr>"
        xml += "</pic:pic></a:graphicData></a:graphic></wp:inline>"
        xml += "</w:drawing></w:r></w:p>"
        
        return xml
    }
    
    private func generateScannedDocumentsSummary(conflictCase: ConflictCase, imageFiles: [(name: String, data: Data, docIndex: Int, isSignature: Bool)] = []) -> String {
        var xml = ""
        
        if conflictCase.documents.isEmpty {
            return paragraph("No documents have been uploaded for this case.")
        }
        
        for (index, doc) in conflictCase.documents.enumerated() {
            let hasImage = doc.originalImageBase64 != nil || !doc.originalImageURLs.isEmpty
            let imageStatus = hasImage ? "Included ✓" : "No"
            
            xml += """
            <w:p>
                <w:pPr>
                    <w:pBdr>
                        <w:left w:val="single" w:sz="24" w:space="4" w:color="\(secondaryColorHex)"/>
                        <w:top w:val="single" w:sz="4" w:space="4" w:color="\(borderColorHex)"/>
                        <w:bottom w:val="single" w:sz="4" w:space="4" w:color="\(borderColorHex)"/>
                        <w:right w:val="single" w:sz="4" w:space="4" w:color="\(borderColorHex)"/>
                    </w:pBdr>
                    <w:spacing w:before="200"/>
                </w:pPr>
                <w:r>
                    <w:rPr><w:b/><w:sz w:val="24"/></w:rPr>
                    <w:t>Document #\(index + 1): \(escapeXML(doc.type.displayName))</w:t>
                </w:r>
            </w:p>
            """
            
            // Resolve submitter name using robust matching
            var submitterName: String? = resolveEmployeeName(for: doc, in: conflictCase)
            
            // If no name found via standard resolution, try robust witness matching for witness statements
            if submitterName == nil && doc.type == .witnessStatement {
                let witnesses = conflictCase.witnesses
                let witnessStatements = conflictCase.witnessStatements
                
                // Find which index this document is in the witness statements
                if let statementIndex = witnessStatements.firstIndex(where: { $0.id == doc.id }) {
                    var matchedWitness: InvolvedEmployee? = nil
                    
                    // Strategy 1: Match by employeeId (UUID match)
                    matchedWitness = witnesses.first { $0.id == doc.employeeId }
                    
                    // Strategy 2: Match by submittedBy name (case-insensitive)
                    if matchedWitness == nil, let submittedByName = doc.submittedBy, !looksLikeIdentifier(submittedByName) {
                        matchedWitness = witnesses.first { $0.name.lowercased() == submittedByName.lowercased() }
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
            
            // Build document details - ALWAYS include Submitted By
            var docDetails: [(String, String)] = [
                ("Submitted", fullDateFormatter.string(from: doc.createdAt)),
                ("Pages", "\(doc.pageCount)"),
                ("Scanned Image", imageStatus)
            ]
            
            // Determine final submitter name (never leave blank)
            let finalSubmitterName: String
            if let name = submitterName {
                finalSubmitterName = name
            } else {
                // Fallback based on document type
                switch doc.type {
                case .complaintA:
                    finalSubmitterName = conflictCase.complainantA?.name ?? "Complainant A"
                case .complaintB:
                    finalSubmitterName = conflictCase.complainantB?.name ?? "Complainant B"
                case .witnessStatement:
                    finalSubmitterName = doc.submittedBy ?? "Witness"
                default:
                    finalSubmitterName = "Submitter"
                }
            }
            
            docDetails.append(("Submitted By", finalSubmitterName))
            xml += generateSimpleTable(items: docDetails)
            
            // Add the actual scanned image if available (filter for non-signature images)
            if let imageFileIndex = imageFiles.firstIndex(where: { $0.docIndex == index && !$0.isSignature }) {
                let rId = imageFileIndex + 4  // rId4, rId5, etc. (rId1-3 are styles, header, footer)
                let imageFile = imageFiles[imageFileIndex]
                xml += generateEmbeddedImage(rId: rId, imageName: imageFile.name, imageData: imageFile.data)
            }
        }
        
        return xml
    }
    
    // Generate embedded image XML for Word document
    private func generateEmbeddedImage(rId: Int, imageName: String, imageData: Data) -> String {
        // Get image dimensions (default to reasonable size if can't determine)
        var widthEMU: Int64 = 5486400  // 6 inches in EMUs (914400 EMU per inch)
        var heightEMU: Int64 = 7315200 // 8 inches in EMUs
        
        if let image = UIImage(data: imageData) {
            let widthInches = image.size.width / image.scale / 72.0  // Points to inches
            let heightInches = image.size.height / image.scale / 72.0
            
            // Cap at 6 inches wide, maintain aspect ratio
            let maxWidthInches: CGFloat = 6.0
            let scaleFactor = min(1.0, maxWidthInches / widthInches)
            
            widthEMU = Int64(widthInches * scaleFactor * 914400)
            heightEMU = Int64(heightInches * scaleFactor * 914400)
        }
        
        let escapedName = escapeXML(imageName)
        let widthStr = String(widthEMU)
        let heightStr = String(heightEMU)
        let rIdStr = String(rId)
        
        var xml = "<w:p>"
        xml += "<w:pPr><w:spacing w:before=\"200\" w:after=\"200\"/><w:jc w:val=\"center\"/></w:pPr>"
        xml += "<w:r><w:drawing>"
        xml += "<wp:inline xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\" distT=\"0\" distB=\"0\" distL=\"0\" distR=\"0\">"
        xml += "<wp:extent cx=\"\(widthStr)\" cy=\"\(heightStr)\"/>"
        xml += "<wp:effectExtent l=\"0\" t=\"0\" r=\"0\" b=\"0\"/>"
        xml += "<wp:docPr id=\"\(rIdStr)\" name=\"\(escapedName)\"/>"
        xml += "<wp:cNvGraphicFramePr><a:graphicFrameLocks xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" noChangeAspect=\"1\"/></wp:cNvGraphicFramePr>"
        xml += "<a:graphic xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">"
        xml += "<a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">"
        xml += "<pic:pic xmlns:pic=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">"
        xml += "<pic:nvPicPr><pic:cNvPr id=\"\(rIdStr)\" name=\"\(escapedName)\"/><pic:cNvPicPr/></pic:nvPicPr>"
        xml += "<pic:blipFill><a:blip r:embed=\"rId\(rIdStr)\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"/>"
        xml += "<a:stretch><a:fillRect/></a:stretch></pic:blipFill>"
        xml += "<pic:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"\(widthStr)\" cy=\"\(heightStr)\"/></a:xfrm>"
        xml += "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></pic:spPr>"
        xml += "</pic:pic></a:graphicData></a:graphic></wp:inline>"
        xml += "</w:drawing></w:r></w:p>"
        
        // Caption
        xml += "<w:p><w:pPr><w:jc w:val=\"center\"/></w:pPr>"
        xml += "<w:r><w:rPr><w:i/><w:sz w:val=\"18\"/><w:color w:val=\"\(subtleTextColorHex)\"/></w:rPr>"
        xml += "<w:t>Scanned Document Image</w:t></w:r></w:p>"
        
        return xml
    }
    
    private func generateAIAnalysis(conflictCase: ConflictCase) -> String {
        guard let analysis = conflictCase.comparisonResult else {
            return paragraph("DashMet Intelligence analysis has not been performed for this case.")
        }
        
        var xml = ""
        
        xml += generateSubsectionHeader("Analysis Summary")
        
        // Calculate overall confidence based on agreement vs contradictions
        let totalPoints = analysis.agreementPoints.count + analysis.contradictions.count
        let confidenceScore = totalPoints > 0 ? (Double(analysis.agreementPoints.count) / Double(totalPoints)) : 0.5
        
        // Overall assessment
        xml += """
        <w:p>
            <w:pPr>
                <w:shd w:val="clear" w:color="auto" w:fill="\(accentColorHex)"/>
                <w:pBdr>
                    <w:top w:val="single" w:sz="8" w:space="8" w:color="\(primaryColorHex)"/>
                    <w:left w:val="single" w:sz="8" w:space="8" w:color="\(primaryColorHex)"/>
                    <w:bottom w:val="single" w:sz="8" w:space="8" w:color="\(primaryColorHex)"/>
                    <w:right w:val="single" w:sz="8" w:space="8" w:color="\(primaryColorHex)"/>
                </w:pBdr>
            </w:pPr>
            <w:r>
                <w:rPr><w:b/><w:sz w:val="28"/><w:color w:val="\(primaryColorHex)"/></w:rPr>
                <w:t>Statement Consistency: \(Int(confidenceScore * 100))%</w:t>
            </w:r>
        </w:p>
        """
        
        // Neutral Summary
        if !analysis.neutralSummary.isEmpty {
            xml += generateSubsectionHeader("Summary Analysis")
            xml += paragraph(analysis.neutralSummary)
        }
        
        // Agreement Points (Consistencies)
        if !analysis.agreementPoints.isEmpty {
            xml += generateSubsectionHeader("Agreement Points")
            for item in analysis.agreementPoints {
                xml += bulletPoint(item, colorHex: "27AE60")
            }
        }
        
        // Contradictions
        if !analysis.contradictions.isEmpty {
            xml += generateSubsectionHeader("Contradictions Identified")
            for item in analysis.contradictions {
                xml += bulletPoint(item, colorHex: "C0392B")
            }
        }
        
        // Timeline Differences
        if !analysis.timelineDifferences.isEmpty {
            xml += generateSubsectionHeader("Timeline Differences")
            for item in analysis.timelineDifferences {
                xml += bulletPoint(item, colorHex: "E67E22")
            }
        }
        
        return xml
    }
    
    private func generatePolicyMatches(conflictCase: ConflictCase) -> String {
        var xml = ""
        
        for (index, match) in conflictCase.policyMatches.enumerated() {
            xml += """
            <w:p>
                <w:pPr>
                    <w:pBdr>
                        <w:left w:val="single" w:sz="24" w:space="4" w:color="\(secondaryColorHex)"/>
                        <w:top w:val="single" w:sz="4" w:space="4" w:color="\(borderColorHex)"/>
                        <w:bottom w:val="single" w:sz="4" w:space="4" w:color="\(borderColorHex)"/>
                        <w:right w:val="single" w:sz="4" w:space="4" w:color="\(borderColorHex)"/>
                    </w:pBdr>
                    <w:spacing w:before="200"/>
                </w:pPr>
                <w:r>
                    <w:rPr><w:b/><w:sz w:val="24"/></w:rPr>
                    <w:t>Policy Match #\(index + 1)</w:t>
                </w:r>
            </w:p>
            """
            
            xml += paragraph("Section: \(match.sectionNumber) - \(match.sectionTitle)")
            xml += paragraph("Relevance: \(Int(match.matchConfidence * 100))%")
            
            if !match.relevanceExplanation.isEmpty {
                xml += generateSubsectionHeader("Relevance Explanation")
                xml += paragraph(match.relevanceExplanation)
            }
        }
        
        return xml
    }
    
    private func generateRecommendations(conflictCase: ConflictCase) -> String {
        var xml = ""
        
        for (index, rec) in conflictCase.recommendations.enumerated() {
            let actionColorHex: String
            switch rec.action {
            case .coaching: actionColorHex = "27AE60"
            case .counseling: actionColorHex = "F39C12"
            case .writtenWarning: actionColorHex = "E74C3C"
            case .escalateToHR: actionColorHex = "9B59B6"
            }
            
            xml += """
            <w:p>
                <w:pPr>
                    <w:pBdr>
                        <w:left w:val="single" w:sz="24" w:space="4" w:color="\(actionColorHex)"/>
                        <w:top w:val="single" w:sz="4" w:space="4" w:color="\(borderColorHex)"/>
                        <w:bottom w:val="single" w:sz="4" w:space="4" w:color="\(borderColorHex)"/>
                        <w:right w:val="single" w:sz="4" w:space="4" w:color="\(borderColorHex)"/>
                    </w:pBdr>
                    <w:shd w:val="clear" w:color="auto" w:fill="\(actionColorHex)15"/>
                    <w:spacing w:before="200"/>
                </w:pPr>
                <w:r>
                    <w:rPr><w:b/><w:sz w:val="28"/><w:color w:val="\(actionColorHex)"/></w:rPr>
                    <w:t>Recommendation #\(index + 1): \(escapeXML(rec.action.displayName))</w:t>
                </w:r>
            </w:p>
            """
            
            xml += paragraph("Confidence: \(Int(rec.confidence * 100))%")
            xml += paragraph(rec.reasoning)
            
            if !rec.riskAssessment.isEmpty {
                xml += paragraph("Risk Assessment: \(rec.riskAssessment)")
            }
            
            if !rec.suggestedNextSteps.isEmpty {
                xml += generateSubsectionHeader("Suggested Next Steps")
                for step in rec.suggestedNextSteps {
                    xml += bulletPoint(step)
                }
            }
        }
        
        return xml
    }
    
    private func generateSelectedAction(conflictCase: ConflictCase) -> String {
        var xml = ""
        
        if let action = conflictCase.selectedAction {
            let actionColorHex: String
            switch action {
            case .coaching: actionColorHex = "27AE60"
            case .counseling: actionColorHex = "F39C12"
            case .writtenWarning: actionColorHex = "E74C3C"
            case .escalateToHR: actionColorHex = "9B59B6"
            }
            
            xml += """
            <w:p>
                <w:pPr>
                    <w:pBdr>
                        <w:top w:val="single" w:sz="16" w:space="8" w:color="\(actionColorHex)"/>
                        <w:left w:val="single" w:sz="16" w:space="8" w:color="\(actionColorHex)"/>
                        <w:bottom w:val="single" w:sz="16" w:space="8" w:color="\(actionColorHex)"/>
                        <w:right w:val="single" w:sz="16" w:space="8" w:color="\(actionColorHex)"/>
                    </w:pBdr>
                    <w:shd w:val="clear" w:color="auto" w:fill="\(actionColorHex)15"/>
                </w:pPr>
                <w:r>
                    <w:rPr><w:b/><w:sz w:val="36"/><w:color w:val="\(actionColorHex)"/></w:rPr>
                    <w:t>FINAL DECISION: \(escapeXML(action.displayName.uppercased()))</w:t>
                </w:r>
            </w:p>
            """
            
            xml += paragraph(action.description)
            xml += paragraph("Risk Level: \(action.riskLevel)")
        }
        
        // Generated Document
        if let genDoc = conflictCase.generatedDocument {
            xml += generateSubsectionHeader("Generated Document")
            xml += paragraph("Title: \(genDoc.title)")
            xml += paragraph("Type: \(genDoc.actionType.displayName)")
            xml += paragraph("Generated: \(fullDateFormatter.string(from: genDoc.createdAt))")
            xml += paragraph("Status: \(genDoc.isApproved ? "APPROVED" : "PENDING APPROVAL")")
            
            xml += generateSubsectionHeader("Document Content")
            xml += paragraph(genDoc.content)
        }
        
        return xml
    }
    
    private func generateSupervisorNotes(notes: String, decision: String?) -> String {
        var xml = ""
        
        xml += """
        <w:p>
            <w:pPr>
                <w:pBdr>
                    <w:top w:val="single" w:sz="8" w:space="8" w:color="\(primaryColorHex)"/>
                    <w:left w:val="single" w:sz="8" w:space="8" w:color="\(primaryColorHex)"/>
                    <w:bottom w:val="single" w:sz="8" w:space="8" w:color="\(primaryColorHex)"/>
                    <w:right w:val="single" w:sz="8" w:space="8" w:color="\(primaryColorHex)"/>
                </w:pBdr>
                <w:shd w:val="clear" w:color="auto" w:fill="EDF3FA"/>
            </w:pPr>
            <w:r>
                <w:rPr><w:b/><w:sz w:val="24"/><w:color w:val="\(primaryColorHex)"/></w:rPr>
                <w:t>📝 SUPERVISOR NOTES</w:t>
            </w:r>
        </w:p>
        """
        
        xml += paragraph(notes)
        
        if let decision = decision, !decision.isEmpty {
            xml += """
            <w:p>
                <w:pPr>
                    <w:pBdr>
                        <w:top w:val="single" w:sz="8" w:space="8" w:color="27AE60"/>
                        <w:left w:val="single" w:sz="8" w:space="8" w:color="27AE60"/>
                        <w:bottom w:val="single" w:sz="8" w:space="8" w:color="27AE60"/>
                        <w:right w:val="single" w:sz="8" w:space="8" w:color="27AE60"/>
                    </w:pBdr>
                    <w:shd w:val="clear" w:color="auto" w:fill="F3FAF5"/>
                    <w:spacing w:before="200"/>
                </w:pPr>
                <w:r>
                    <w:rPr><w:b/><w:sz w:val="24"/><w:color w:val="27AE60"/></w:rPr>
                    <w:t>⚖️ DECISION RATIONALE</w:t>
                </w:r>
            </w:p>
            """
            xml += paragraph(decision)
        }
        
        return xml
    }
    
    private func generateAuditTrail(conflictCase: ConflictCase) -> String {
        var xml = ""
        
        xml += paragraph("This section documents all actions taken on this case, providing a complete chronological record for compliance and review purposes.")
        
        for entry in conflictCase.auditLog {
            xml += """
            <w:p>
                <w:pPr>
                    <w:pBdr>
                        <w:left w:val="single" w:sz="8" w:space="4" w:color="\(secondaryColorHex)"/>
                    </w:pBdr>
                    <w:shd w:val="clear" w:color="auto" w:fill="\(accentColorHex)"/>
                    <w:spacing w:before="100"/>
                </w:pPr>
                <w:r>
                    <w:rPr><w:b/><w:sz w:val="20"/></w:rPr>
                    <w:t>\(escapeXML(entry.action))</w:t>
                </w:r>
            </w:p>
            <w:p>
                <w:pPr>
                    <w:pBdr>
                        <w:left w:val="single" w:sz="8" w:space="4" w:color="\(secondaryColorHex)"/>
                    </w:pBdr>
                </w:pPr>
                <w:r>
                    <w:rPr><w:sz w:val="18"/><w:color w:val="\(subtleTextColorHex)"/></w:rPr>
                    <w:t>\(escapeXML(timestampFormatter.string(from: entry.timestamp))) | \(escapeXML(entry.userName))</w:t>
                </w:r>
            </w:p>
            """
            
            if !entry.details.isEmpty {
                xml += paragraph(entry.details)
            }
        }
        
        return xml
    }
    
    private func generateSignatureBlocks() -> String {
        var xml = ""
        
        xml += paragraph("The undersigned certify that this report accurately represents the findings and documentation of the case investigation.")
        
        let signatureBlocks = [
            ("Prepared By", "Investigator/Case Handler"),
            ("Reviewed By", "Supervisor/Manager"),
            ("Approved By", "HR Representative/Director")
        ]
        
        for (title, role) in signatureBlocks {
            xml += """
            <w:p>
                <w:pPr><w:spacing w:before="400"/></w:pPr>
                <w:r>
                    <w:rPr><w:b/><w:sz w:val="22"/><w:color w:val="\(primaryColorHex)"/></w:rPr>
                    <w:t>\(escapeXML(title))</w:t>
                </w:r>
            </w:p>
            <w:p>
                <w:r>
                    <w:rPr><w:sz w:val="18"/><w:color w:val="\(subtleTextColorHex)"/></w:rPr>
                    <w:t>\(escapeXML(role))</w:t>
                </w:r>
            </w:p>
            <w:p>
                <w:pPr>
                    <w:pBdr>
                        <w:bottom w:val="single" w:sz="4" w:space="4" w:color="\(textColorHex)"/>
                    </w:pBdr>
                    <w:spacing w:before="400"/>
                </w:pPr>
            </w:p>
            <w:p>
                <w:pPr>
                    <w:tabs>
                        <w:tab w:val="left" w:pos="4680"/>
                    </w:tabs>
                </w:pPr>
                <w:r>
                    <w:rPr><w:sz w:val="18"/><w:color w:val="\(subtleTextColorHex)"/></w:rPr>
                    <w:t>Signature</w:t>
                </w:r>
                <w:r>
                    <w:tab/>
                </w:r>
                <w:r>
                    <w:rPr><w:sz w:val="18"/><w:color w:val="\(subtleTextColorHex)"/></w:rPr>
                    <w:t>Date</w:t>
                </w:r>
            </w:p>
            """
        }
        
        return xml
    }
    
    // MARK: - Helper Methods
    
    private func wrapDocumentXML(content: String) -> String {
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
                    xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
            <w:body>
                \(content)
                <w:sectPr>
                    <w:headerReference w:type="default" r:id="rId2"/>
                    <w:footerReference w:type="default" r:id="rId3"/>
                    <w:pgSz w:w="12240" w:h="15840"/>
                    <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720"/>
                </w:sectPr>
            </w:body>
        </w:document>
        """
    }
    
    private func pageBreak() -> String {
        return """
        <w:p>
            <w:r>
                <w:br w:type="page"/>
            </w:r>
        </w:p>
        """
    }
    
    private func paragraph(_ text: String) -> String {
        return """
        <w:p>
            <w:pPr>
                <w:spacing w:before="60" w:after="120" w:line="276" w:lineRule="auto"/>
            </w:pPr>
            <w:r>
                <w:rPr><w:sz w:val="22"/></w:rPr>
                <w:t>\(escapeXML(text))</w:t>
            </w:r>
        </w:p>
        """
    }
    
    private func labelValueParagraph(_ label: String, _ value: String) -> String {
        return """
        <w:p>
            <w:pPr>
                <w:spacing w:after="60"/>
            </w:pPr>
            <w:r>
                <w:rPr><w:b/><w:sz w:val="18"/><w:color w:val="\(primaryColorHex)"/></w:rPr>
                <w:t>\(escapeXML(label))</w:t>
            </w:r>
        </w:p>
        <w:p>
            <w:pPr>
                <w:spacing w:after="120"/>
            </w:pPr>
            <w:r>
                <w:t>\(escapeXML(value))</w:t>
            </w:r>
        </w:p>
        """
    }
    
    private func bulletPoint(_ text: String, colorHex: String = "262633") -> String {
        return """
        <w:p>
            <w:pPr>
                <w:numPr>
                    <w:ilvl w:val="0"/>
                    <w:numId w:val="1"/>
                </w:numPr>
                <w:spacing w:after="60"/>
            </w:pPr>
            <w:r>
                <w:rPr><w:color w:val="\(colorHex)"/></w:rPr>
                <w:t>• \(escapeXML(text))</w:t>
            </w:r>
        </w:p>
        """
    }
    
    private func generateSimpleTable(items: [(String, String)]) -> String {
        var xml = """
        <w:tbl>
            <w:tblPr>
                <w:tblW w:w="9360" w:type="dxa"/>
                <w:tblCellMar>
                    <w:top w:w="80" w:type="dxa"/>
                    <w:left w:w="120" w:type="dxa"/>
                    <w:bottom w:w="80" w:type="dxa"/>
                    <w:right w:w="120" w:type="dxa"/>
                </w:tblCellMar>
                <w:tblBorders>
                    <w:top w:val="single" w:sz="4" w:space="0" w:color="\(borderColorHex)"/>
                    <w:left w:val="single" w:sz="4" w:space="0" w:color="\(borderColorHex)"/>
                    <w:bottom w:val="single" w:sz="4" w:space="0" w:color="\(borderColorHex)"/>
                    <w:right w:val="single" w:sz="4" w:space="0" w:color="\(borderColorHex)"/>
                    <w:insideH w:val="single" w:sz="4" w:space="0" w:color="\(borderColorHex)"/>
                    <w:insideV w:val="single" w:sz="4" w:space="0" w:color="\(borderColorHex)"/>
                </w:tblBorders>
            </w:tblPr>
        """
        
        for (index, item) in items.enumerated() {
            let fill = index % 2 == 0 ? accentColorHex : "FFFFFF"
            xml += """
            <w:tr>
                <w:tc>
                    <w:tcPr>
                        <w:tcW w:w="3120" w:type="dxa"/>
                        <w:shd w:val="clear" w:color="auto" w:fill="\(fill)"/>
                        <w:vAlign w:val="center"/>
                    </w:tcPr>
                    <w:p>
                        <w:pPr><w:spacing w:before="40" w:after="40"/></w:pPr>
                        <w:r>
                            <w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="\(subtleTextColorHex)"/></w:rPr>
                            <w:t>\(escapeXML(item.0))</w:t>
                        </w:r>
                    </w:p>
                </w:tc>
                <w:tc>
                    <w:tcPr>
                        <w:tcW w:w="6240" w:type="dxa"/>
                        <w:shd w:val="clear" w:color="auto" w:fill="\(fill)"/>
                        <w:vAlign w:val="center"/>
                    </w:tcPr>
                    <w:p>
                        <w:pPr><w:spacing w:before="40" w:after="40"/></w:pPr>
                        <w:r>
                            <w:rPr><w:sz w:val="20"/></w:rPr>
                            <w:t>\(escapeXML(item.1))</w:t>
                        </w:r>
                    </w:p>
                </w:tc>
            </w:tr>
            """
        }
        
        xml += "</w:tbl>"
        // Add spacing after table
        xml += "<w:p><w:pPr><w:spacing w:after=\"200\"/></w:pPr></w:p>"
        return xml
    }
    
    private func escapeXML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
