//
//  CaseFinalizationView.swift
//  MeetingIntelligence
//
//  Enterprise-Grade Case Finalization
//  Professional case closure, HR escalation, and document export
//

import SwiftUI
import PDFKit
import Combine
import QuickLook
import UniformTypeIdentifiers
import FirebaseAuth

// MARK: - Finalization Option
enum FinalizationOption: String, CaseIterable, Identifiable {
    case closeCase = "Close Case"
    case exportPackage = "Export Package"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .closeCase: return "checkmark.circle.fill"
        case .exportPackage: return "square.and.arrow.up.fill"
        }
    }
    
    var description: String {
        switch self {
        case .closeCase: return "Finalize and lock the case record"
        case .exportPackage: return "Download PDF package with all documents"
        }
    }
    
    var color: Color {
        switch self {
        case .closeCase: return .green
        case .exportPackage: return .orange
        }
    }
}

// MARK: - Active Sheet Type
enum ExportSheetType: Identifiable {
    case exportSuccess
    case quickLook
    case documentPicker
    
    var id: String {
        switch self {
        case .exportSuccess: return "exportSuccess"
        case .quickLook: return "quickLook"
        case .documentPicker: return "documentPicker"
        }
    }
}

// MARK: - Package Export Format
enum PackageExportFormat: String, CaseIterable, Identifiable {
    case pdf = "pdf"
    case docx = "docx"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .pdf: return "PDF Document"
        case .docx: return "Word Document"
        }
    }
    
    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .docx: return "doc.richtext"
        }
    }
    
    var fileExtension: String { rawValue }
    
    var description: String {
        switch self {
        case .pdf: return "Standard PDF format"
        case .docx: return "Editable Word format"
        }
    }
}

// MARK: - Case Finalization View
struct CaseFinalizationView: View {
    let conflictCase: ConflictCase
    let generatedDocument: GeneratedDocumentResult?
    let onFinalize: () -> Void
    let onExport: () -> Void
    let onBack: () -> Void
    
    @StateObject private var finalizationService = CaseFinalizationService.shared
    @StateObject private var wordReportService = CaseWordReportService.shared
    
    @State private var selectedOption: FinalizationOption? = nil
    @State private var isGeneratingWord = false
    @State private var showConfirmation = false
    @State private var supervisorNotes = ""
    
    // Close Case Options
    @State private var selectedClosureReason: CaseClosureReason = .resolved
    @State private var customClosureReason = ""
    @State private var closureSummary = ""
    @State private var acknowledgeCaseLock = false
    
    // Export Options
    @State private var exportOptions = ExportOptions.full
    @State private var includeAllDocuments = true
    @State private var includeAuditTrail = true
    @State private var includeStatements = true
    @State private var includeAIAnalysis = true
    @State private var includePolicyMatches = true
    @State private var selectedExportFormat: PackageExportFormat = .pdf
    @State private var docxData: Data?
    
    // UI State
    @State private var activeSheet: ExportSheetType?
    @State private var pdfData: Data?
    @State private var pdfURL: URL?
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var showSaveSuccessAlert = false
    @State private var savedFilePath: String = ""
    @State private var finalizationResult: FinalizationResult?
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var textTertiary: Color {
        colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    private var innerCardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.gray.opacity(0.08)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if finalizationService.isProcessing {
                    processingOverlay
                } else if isGeneratingWord {
                    wordGenerationOverlay
                } else {
                    mainContent
                }
            }
            .navigationTitle("Finalize Case")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        onBack()
                    }
                    .disabled(finalizationService.isProcessing || isGeneratingWord)
                }
            }
            .alert("Confirm Action", isPresented: $showConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button(confirmActionText, role: selectedOption == .closeCase ? .destructive : .none) {
                    executeFinalization()
                }
            } message: {
                Text(confirmationMessage)
            }
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK") {
                    if selectedOption == .closeCase {
                        onFinalize()
                    }
                }
            } message: {
                Text(successMessage)
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(finalizationResult?.errorMessage ?? "An unexpected error occurred")
            }
            .sheet(item: $activeSheet) { sheetType in
                switch sheetType {
                case .exportSuccess:
                    exportSuccessSheet
                case .quickLook:
                    if let url = pdfURL {
                        QuickLookPreview(url: url)
                    }
                case .documentPicker:
                    if let url = pdfURL {
                        DocumentExporter(fileURL: url) { success in
                            if success {
                                showSaveSuccessAlert = true
                                savedFilePath = "Exported successfully"
                            }
                        }
                    }
                }
            }
            .alert("PDF Saved", isPresented: $showSaveSuccessAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("PDF saved to: \(savedFilePath)")
            }
        }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                // Case Summary
                caseSummaryCard
                
                // Document Status
                if generatedDocument != nil {
                    documentStatusCard
                }
                
                // Finalization Options
                finalizationOptionsSection
                
                // Selected Option Details
                if let option = selectedOption {
                    optionDetailsSection(option)
                }
                
                // Supervisor Notes (for all options)
                supervisorNotesSection
                
                // Action Button
                actionButton
            }
            .padding()
        }
    }
    
    // MARK: - Processing Overlay
    private var processingOverlay: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: finalizationService.progress)
                    .stroke(selectedOption?.color ?? .blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: finalizationService.progress)
                
                Text("\(Int(finalizationService.progress * 100))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(textPrimary)
            }
            
            VStack(spacing: 8) {
                Text("Processing")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Text(finalizationService.currentStep)
                    .font(.system(size: 14))
                    .foregroundColor(textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.1), radius: 20, y: 10)
    }
    
    // MARK: - Word Generation Overlay
    private var wordGenerationOverlay: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: wordReportService.generationProgress)
                    .stroke(
                        LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: wordReportService.generationProgress)
                
                Text("\(Int(wordReportService.generationProgress * 100))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(textPrimary)
            }
            
            VStack(spacing: 8) {
                Text("Generating Word Document")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Text(wordReportService.currentStep)
                    .font(.system(size: 14))
                    .foregroundColor(textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.1), radius: 20, y: 10)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "flag.checkered")
                    .font(.system(size: 28))
                    .foregroundColor(.green)
            }
            
            Text("Case Finalization")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(textPrimary)
            
            Text("Review and complete the case workflow")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Case Summary Card
    private var caseSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.blue)
                Text("Case Summary")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textPrimary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                summaryRow(label: "Case ID", value: conflictCase.caseNumber)
                summaryRow(label: "Type", value: conflictCase.type.displayName)
                summaryRow(label: "Status", value: conflictCase.status.displayName)
                summaryRow(label: "Created", value: formatDate(conflictCase.createdAt))
                summaryRow(label: "Documents", value: "\(conflictCase.documents.count)")
                summaryRow(label: "Parties", value: "\(conflictCase.involvedEmployees.count)")
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Document Status Card
    private var documentStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                Text("Generated Document")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textPrimary)
                Spacer()
                
                Text("Ready")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .clipShape(Capsule())
            }
            
            if let doc = generatedDocument {
                Text("Type: \(doc.actionType.displayName)")
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
                
                Text("Generated: \(formatDate(doc.generatedAt))")
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Finalization Options Section
    private var finalizationOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FINALIZATION OPTIONS")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(textTertiary)
            
            ForEach(FinalizationOption.allCases) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedOption = option
                    }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(option.color.opacity(0.15))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: option.icon)
                                .font(.system(size: 20))
                                .foregroundColor(option.color)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.rawValue)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(textPrimary)
                            
                            Text(option.description)
                                .font(.system(size: 12))
                                .foregroundColor(textSecondary)
                        }
                        
                        Spacer()
                        
                        if selectedOption == option {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(option.color)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(textTertiary)
                        }
                    }
                    .padding()
                    .background(selectedOption == option ? option.color.opacity(0.1) : cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedOption == option ? option.color : Color.clear, lineWidth: 2)
                    )
                }
            }
        }
    }
    
    // MARK: - Option Details Section
    @ViewBuilder
    private func optionDetailsSection(_ option: FinalizationOption) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONFIGURATION")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(textTertiary)
            
            switch option {
            case .closeCase:
                closeCaseOptions
            case .exportPackage:
                exportOptionsSection
            }
        }
    }
    
    // MARK: - Close Case Options
    private var closeCaseOptions: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Warning Banner
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Case Record Lock")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(textPrimary)
                    Text("This action will permanently lock the case record")
                        .font(.system(size: 11))
                        .foregroundColor(textSecondary)
                }
                Spacer()
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Closure Reason
            VStack(alignment: .leading, spacing: 10) {
                Text("Closure Reason")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textSecondary)
                
                ForEach(CaseClosureReason.allCases) { reason in
                    Button {
                        selectedClosureReason = reason
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selectedClosureReason == reason ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(selectedClosureReason == reason ? .green : textTertiary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reason.displayName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(textPrimary)
                                Text(reason.description)
                                    .font(.system(size: 11))
                                    .foregroundColor(textTertiary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                if selectedClosureReason == .other {
                    TextField("Specify reason...", text: $customClosureReason)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(innerCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            Divider()
            
            // Closure Summary
            VStack(alignment: .leading, spacing: 8) {
                Text("Closure Summary (Optional)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textSecondary)
                
                TextEditor(text: $closureSummary)
                    .frame(height: 80)
                    .padding(8)
                    .background(innerCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text("Provide final notes summarizing the case outcome")
                    .font(.system(size: 11))
                    .foregroundColor(textTertiary)
            }
            
            Divider()
            
            // Archive Options
            VStack(alignment: .leading, spacing: 8) {
                toggleOption(
                    title: "Include complete audit trail",
                    isOn: $includeAuditTrail,
                    description: "Preserve timestamped history of all actions"
                )
                
                toggleOption(
                    title: "Archive all documents",
                    isOn: $includeAllDocuments,
                    description: "Store all case documents in archive"
                )
            }
            
            Divider()
            
            // Acknowledgment
            Button {
                acknowledgeCaseLock.toggle()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: acknowledgeCaseLock ? "checkmark.square.fill" : "square")
                        .foregroundColor(acknowledgeCaseLock ? .green : textTertiary)
                    
                    Text("I understand this action is permanent and cannot be undone")
                        .font(.system(size: 12))
                        .foregroundColor(textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Export Options Section
    private var exportOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Export Preview
            VStack(alignment: .leading, spacing: 10) {
                Text("Package Contents")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textSecondary)
                
                VStack(spacing: 8) {
                    exportIncludeItem("Executive Summary", icon: "doc.text", included: true)
                    exportIncludeItem("Case Details & Timeline", icon: "clock", included: true)
                    exportIncludeItem("Involved Parties", icon: "person.2", included: true)
                    exportIncludeItem("Generated Document", icon: "doc.fill", included: generatedDocument != nil)
                    exportIncludeItem("Scanned Documents", icon: "doc.on.doc", included: includeAllDocuments)
                    exportIncludeItem("AI Analysis Report", icon: "brain", included: includeAIAnalysis)
                    exportIncludeItem("Policy Matches", icon: "book.closed", included: includePolicyMatches)
                    exportIncludeItem("Complete Audit Trail", icon: "clock.arrow.circlepath", included: includeAuditTrail)
                    exportIncludeItem("Signature Blocks", icon: "signature", included: true)
                }
            }
            
            Divider()
            
            // Export Format Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Export Format")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textSecondary)
                
                HStack(spacing: 12) {
                    ForEach(PackageExportFormat.allCases) { format in
                        Button {
                            selectedExportFormat = format
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: format.icon)
                                    .font(.system(size: 14))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(format.displayName)
                                        .font(.system(size: 13, weight: .medium))
                                    Text(format.description)
                                        .font(.system(size: 10))
                                        .foregroundColor(selectedExportFormat == format ? .white.opacity(0.8) : textTertiary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(selectedExportFormat == format ? Color.orange : Color.gray.opacity(0.1))
                            .foregroundColor(selectedExportFormat == format ? .white : textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            
            Divider()
            
            // Configuration
            VStack(alignment: .leading, spacing: 8) {
                Text("Include in Export")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textSecondary)
                
                toggleOption(
                    title: "All scanned documents",
                    isOn: $includeAllDocuments,
                    description: "Complaints, statements, and evidence"
                )
                
                toggleOption(
                    title: "AI analysis results",
                    isOn: $includeAIAnalysis,
                    description: "Comparison and recommendation reports"
                )
                
                toggleOption(
                    title: "Policy match details",
                    isOn: $includePolicyMatches,
                    description: "Matched workplace policies"
                )
                
                toggleOption(
                    title: "Complete audit trail",
                    isOn: $includeAuditTrail,
                    description: "Timestamped history of all actions"
                )
            }
            
            // Estimated Size
            HStack {
                Image(systemName: "doc.zipper")
                    .foregroundColor(.orange)
                Text("Estimated package size: ~\(estimatedPackagePages) pages")
                    .font(.system(size: 12))
                    .foregroundColor(textSecondary)
                Spacer()
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Save to Files fallback (shown after export)
            if pdfData != nil || docxData != nil {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Alternative Save Option")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(textSecondary)
                    
                    Button {
                        savePDFToDocuments()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.badge.plus")
                            Text("Save to App Documents")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    Text("Use this if the share sheet doesn't work properly")
                        .font(.system(size: 11))
                        .foregroundColor(textTertiary)
                }
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Supervisor Notes Section
    private var supervisorNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUPERVISOR NOTES (Optional)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(textTertiary)
            
            TextEditor(text: $supervisorNotes)
                .frame(height: 100)
                .padding(8)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Text("Add any final notes or observations about this case")
                .font(.system(size: 11))
                .foregroundColor(textTertiary)
        }
    }
    
    // MARK: - Action Button
    private var actionButton: some View {
        Button {
            showConfirmation = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selectedOption?.icon ?? "checkmark.circle.fill")
                Text(actionButtonTitle)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isActionEnabled ? (selectedOption?.color ?? .gray) : Color.gray.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!isActionEnabled)
    }
    
    // MARK: - Helper Views
    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(textPrimary)
        }
    }
    
    private func toggleOption(title: String, isOn: Binding<Bool>, description: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textPrimary)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(textTertiary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
    }
    
    private func exportIncludeItem(_ title: String, icon: String, included: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(included ? .blue : .gray)
                .frame(width: 22)
            
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(included ? textPrimary : textTertiary)
            
            Spacer()
            
            Image(systemName: included ? "checkmark.circle.fill" : "minus.circle")
                .foregroundColor(included ? .green : .gray.opacity(0.5))
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Computed Properties
    
    private var isActionEnabled: Bool {
        guard let option = selectedOption else { return false }
        
        switch option {
        case .closeCase:
            return acknowledgeCaseLock && (selectedClosureReason != .other || !customClosureReason.isEmpty)
        case .exportPackage:
            return true
        }
    }
    
    private var actionButtonTitle: String {
        switch selectedOption {
        case .closeCase: return "Finalize & Close Case"
        case .exportPackage: return "Generate & Export Package"
        case .none: return "Select an Option"
        }
    }
    
    private var confirmActionText: String {
        switch selectedOption {
        case .closeCase: return "Close Case"
        case .exportPackage: return "Export"
        case .none: return "Confirm"
        }
    }
    
    private var confirmationMessage: String {
        switch selectedOption {
        case .closeCase:
            return "This will permanently close and lock the case record with reason: \"\(selectedClosureReason.displayName)\". This action cannot be undone."
        case .exportPackage:
            return "A comprehensive PDF package (~\(estimatedPackagePages) pages) will be generated with all selected content."
        case .none:
            return ""
        }
    }
    
    private var successMessage: String {
        switch selectedOption {
        case .closeCase:
            return "Case \(conflictCase.caseNumber) has been successfully closed and locked."
        case .exportPackage:
            return "PDF package generated successfully."
        case .none:
            return ""
        }
    }
    
    private var estimatedPackagePages: Int {
        var pages = 5 // Base: cover, TOC, summary, details
        if includeAllDocuments { pages += conflictCase.documents.count * 2 }
        if includeAuditTrail { pages += 2 }
        if includeAIAnalysis { pages += 3 }
        if includePolicyMatches { pages += 2 }
        if generatedDocument != nil { pages += 3 }
        return pages
    }
    
    // MARK: - Actions
    
    private func executeFinalization() {
        guard let option = selectedOption else { return }
        
        Task {
            switch option {
            case .closeCase:
                await executeCloseCase()
            case .exportPackage:
                await executeExportPackage()
            }
        }
    }
    
    private func executeCloseCase() async {
        let closureReasonText = selectedClosureReason == .other ? customClosureReason : selectedClosureReason.rawValue
        
        // Get current user ID
        guard let userId = FirebaseAuthService.shared.currentUser?.uid else {
            await MainActor.run {
                finalizationResult = .failure(
                    action: .closeCase,
                    caseId: conflictCase.backendId ?? conflictCase.id.uuidString,
                    caseNumber: conflictCase.caseNumber,
                    error: "Unable to identify current user. Please log in again."
                )
                showErrorAlert = true
            }
            return
        }
        
        let result = await finalizationService.closeCase(
            conflictCase: conflictCase,
            closureReason: closureReasonText,
            closureSummary: closureSummary.isEmpty ? nil : closureSummary,
            supervisorNotes: supervisorNotes.isEmpty ? nil : supervisorNotes,
            closedBy: userId,
            includeAuditTrail: includeAuditTrail,
            includeAllDocuments: includeAllDocuments
        )
        
        await MainActor.run {
            finalizationResult = result
            if result.success {
                showSuccessAlert = true
            } else {
                showErrorAlert = true
            }
        }
    }
    
    private func executeExportPackage() async {
        var options = ExportOptions.full
        options.includeAuditTrail = includeAuditTrail
        options.includeAllDocuments = includeAllDocuments
        options.includeStatements = includeStatements
        options.includeAIAnalysis = includeAIAnalysis
        options.includePolicyMatches = includePolicyMatches
        
        if selectedExportFormat == .docx {
            // Generate Word Document
            await MainActor.run {
                isGeneratingWord = true
            }
            
            var wordConfig = WordReportConfiguration.full
            wordConfig.includeAuditTrail = includeAuditTrail
            wordConfig.includeScannedDocuments = includeAllDocuments
            wordConfig.includeFullStatements = includeStatements
            wordConfig.includeAIAnalysis = includeAIAnalysis
            wordConfig.includePolicyMatches = includePolicyMatches
            
            let wordResult = await CaseWordReportService.shared.generateReport(
                for: conflictCase,
                configuration: wordConfig
            )
            
            await MainActor.run {
                isGeneratingWord = false
                
                if wordResult.success, let data = wordResult.docxData {
                    self.docxData = data
                    
                    if let documentsURL = saveDocumentToDocumentsAndGetURL(data, format: .docx) {
                        self.pdfURL = documentsURL
                        activeSheet = .exportSuccess
                    } else if let tempURL = saveDocumentToTempFile(data, format: .docx) {
                        self.pdfURL = tempURL
                        activeSheet = .exportSuccess
                    } else {
                        showSaveSuccessAlert = true
                        savedFilePath = "Word document generated (internal storage)"
                        onExport()
                    }
                    
                    finalizationResult = .success(
                        action: .exportPackage,
                        caseId: conflictCase.backendId ?? conflictCase.id.uuidString,
                        caseNumber: conflictCase.caseNumber,
                        details: FinalizationDetails(
                            closureReason: nil,
                            hrRecipients: nil,
                            urgencyLevel: nil,
                            exportedDocumentIds: nil,
                            pdfPageCount: nil,
                            pdfFileSize: Int64(data.count),
                            supervisorNotes: supervisorNotes.isEmpty ? nil : supervisorNotes,
                            includeAuditTrail: includeAuditTrail,
                            includeAllDocuments: includeAllDocuments
                        )
                    )
                } else {
                    finalizationResult = .failure(
                        action: .exportPackage,
                        caseId: conflictCase.backendId ?? conflictCase.id.uuidString,
                        caseNumber: conflictCase.caseNumber,
                        error: wordResult.errorMessage ?? "Failed to generate Word document"
                    )
                    showErrorAlert = true
                }
            }
        } else {
            // Generate PDF (existing logic)
            let (result, data) = await finalizationService.exportPackage(
                conflictCase: conflictCase,
                generatedDocument: generatedDocument,
                exportOptions: options
            )
            
            await MainActor.run {
                finalizationResult = result
                if result.success, let pdfData = data {
                    self.pdfData = pdfData
                    
                    // Save to Documents folder (persistent location)
                    if let documentsURL = saveDocumentToDocumentsAndGetURL(pdfData, format: .pdf) {
                        self.pdfURL = documentsURL
                        activeSheet = .exportSuccess
                        // Don't call onExport() here - let user interact with sheet first
                    } else {
                        // Fallback to temp file
                        if let tempURL = saveDocumentToTempFile(pdfData, format: .pdf) {
                            self.pdfURL = tempURL
                            activeSheet = .exportSuccess
                            // Don't call onExport() here - let user interact with sheet first
                        } else {
                            showSaveSuccessAlert = true
                            savedFilePath = "PDF generated (internal storage)"
                            onExport()
                        }
                    }
                } else {
                    showErrorAlert = true
                }
            }
        }
    }
    
    private func saveDocumentToDocumentsAndGetURL(_ data: Data, format: PackageExportFormat) -> URL? {
        let fileName = "CasePackage_\(conflictCase.caseNumber)_\(formatFileDate(Date())).\(format.fileExtension)"
        
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let fileURL = documentsDir.appendingPathComponent(fileName)
        
        do {
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            try data.write(to: fileURL)
            savedFilePath = fileName
            print("Document saved to: \(fileURL.path)")
            return fileURL
        } catch {
            print("Failed to save document to Documents: \(error)")
            return nil
        }
    }
    
    private func saveDocumentToTempFile(_ data: Data, format: PackageExportFormat) -> URL? {
        let fileName = "CasePackage_\(conflictCase.caseNumber)_\(formatFileDate(Date())).\(format.fileExtension)"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to save document to temp file: \(error)")
            return nil
        }
    }
    
    private func savePDFToDocumentsInternal(_ data: Data) {
        let fileName = "CasePackage_\(conflictCase.caseNumber)_\(formatFileDate(Date())).pdf"
        
        if let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsDir.appendingPathComponent(fileName)
            
            do {
                try data.write(to: fileURL)
                savedFilePath = fileName
            } catch {
                print("Failed to save PDF to Documents: \(error)")
            }
        }
    }
    
    private func savePDFToDocuments() {
        let data: Data?
        let format = selectedExportFormat
        
        if selectedExportFormat == .docx {
            data = docxData
        } else {
            data = pdfData
        }
        
        guard let exportData = data else { return }
        
        let fileName = "CasePackage_\(conflictCase.caseNumber)_\(formatFileDate(Date())).\(format.fileExtension)"
        
        if let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsDir.appendingPathComponent(fileName)
            
            do {
                try exportData.write(to: fileURL)
                savedFilePath = fileURL.lastPathComponent
                showSaveSuccessAlert = true
            } catch {
                finalizationResult = .failure(
                    action: .exportPackage,
                    caseId: conflictCase.backendId ?? conflictCase.id.uuidString,
                    caseNumber: conflictCase.caseNumber,
                    error: "Failed to save document: \(error.localizedDescription)"
                )
                showErrorAlert = true
            }
        }
    }
    
    // MARK: - Export Success Sheet
    private var exportSuccessSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Success Icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                }
                .padding(.top, 20)
                
                // Title
                VStack(spacing: 8) {
                    Text("\(selectedExportFormat.displayName) Generated Successfully")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(textPrimary)
                    
                    Text("Case Package: \(conflictCase.caseNumber)")
                        .font(.system(size: 14))
                        .foregroundColor(textSecondary)
                }
                
                // File Info
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: selectedExportFormat.icon)
                            .foregroundColor(.orange)
                        Text(savedFilePath)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(textPrimary)
                        Spacer()
                    }
                    
                    if let data = selectedExportFormat == .docx ? docxData : pdfData {
                        HStack {
                            Image(systemName: "internaldrive")
                                .foregroundColor(.blue)
                            Text("Size: \(formatFileSize(Int64(data.count)))")
                                .font(.system(size: 13))
                                .foregroundColor(textSecondary)
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Action Buttons
                VStack(spacing: 12) {
                    // Preview Button
                    Button {
                        if let url = pdfURL {
                            PDFPresentationHelper.presentQuickLookFromRoot(for: url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "eye.fill")
                            Text("Preview \(selectedExportFormat == .docx ? "Document" : "PDF")")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Share Button (most reliable)
                    Button {
                        if let url = pdfURL {
                            PDFPresentationHelper.shareFileFromRoot(url: url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share / Save to Files")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Open Files App
                    Button {
                        if let filesURL = URL(string: "shareddocuments://") {
                            UIApplication.shared.open(filesURL)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "folder")
                            Text("Open Files App")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Done Button
                    Button {
                        activeSheet = nil
                    } label: {
                        Text("Done")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                
                // Note
                VStack(spacing: 4) {
                    Text("PDF saved to: Meeting Intelligence → Documents")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textSecondary)
                    Text("Use 'Share' to save to any location or send via email/AirDrop")
                        .font(.system(size: 11))
                        .foregroundColor(textTertiary)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        activeSheet = nil
                    }
                }
            }
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatFileDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Quick Look Preview
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        
        init(url: URL) {
            self.url = url
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return url as QLPreviewItem
        }
    }
}

// MARK: - Document Exporter
struct DocumentExporter: UIViewControllerRepresentable {
    let fileURL: URL
    let onCompletion: (Bool) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onCompletion: (Bool) -> Void
        
        init(onCompletion: @escaping (Bool) -> Void) {
            self.onCompletion = onCompletion
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onCompletion(true)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCompletion(false)
        }
    }
}

// MARK: - UIKit Presentation Helpers
class PDFPresentationHelper {
    static func presentQuickLook(for url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }
        
        // Find the topmost presented view controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        let previewController = QLPreviewController()
        let dataSource = QuickLookDataSource(url: url)
        previewController.dataSource = dataSource
        
        // Store reference to prevent deallocation
        objc_setAssociatedObject(previewController, "dataSource", dataSource, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        topVC.present(previewController, animated: true)
    }
    
    static func shareFile(url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }
        
        // Find the topmost presented view controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // For iPad: configure popover
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        topVC.present(activityVC, animated: true)
    }
    
    // MARK: - Present from Root (dismisses all sheets first)
    
    static func presentQuickLookFromRoot(for url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }
        
        // Dismiss all presented view controllers first
        rootVC.dismiss(animated: true) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let previewController = QLPreviewController()
                let dataSource = QuickLookDataSource(url: url)
                previewController.dataSource = dataSource
                
                // Store reference to prevent deallocation
                objc_setAssociatedObject(previewController, "dataSource", dataSource, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                
                rootVC.present(previewController, animated: true)
            }
        }
    }
    
    static func shareFileFromRoot(url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }
        
        // Dismiss all presented view controllers first
        rootVC.dismiss(animated: true) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                
                // For iPad: configure popover
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = rootVC.view
                    popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                
                rootVC.present(activityVC, animated: true)
            }
        }
    }
    
    static func presentDocumentPicker(for url: URL, completion: @escaping (Bool) -> Void) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            completion(false)
            return
        }
        
        // Find the topmost presented view controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        let delegate = DocumentPickerDelegate(completion: completion)
        picker.delegate = delegate
        
        // Store reference to prevent deallocation
        objc_setAssociatedObject(picker, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        topVC.present(picker, animated: true)
    }
}

class QuickLookDataSource: NSObject, QLPreviewControllerDataSource {
    let url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        url as QLPreviewItem
    }
}

class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    let completion: (Bool) -> Void
    
    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        completion(true)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion(false)
    }
}

// MARK: - Preview
#Preview {
    CaseFinalizationView(
        conflictCase: ConflictCase(
            caseNumber: "CR-20260211-001",
            type: .conflict,
            incidentDate: Date(),
            location: "Main Office",
            department: "Operations"
        ),
        generatedDocument: nil,
        onFinalize: {},
        onExport: {},
        onBack: {}
    )
}
