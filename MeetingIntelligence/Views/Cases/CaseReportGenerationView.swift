//
//  CaseReportGenerationView.swift
//  MeetingIntelligence
//
//  Enterprise-grade Case Report Generation Interface
//  Professional UI for configuring and generating comprehensive case reports
//

import SwiftUI
import PDFKit

struct CaseReportGenerationView: View {
    
    // MARK: - Environment & State
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var reportService = CaseReportService.shared
    
    let conflictCase: ConflictCase
    
    // MARK: - Report Configuration State
    
    @State private var reportConfiguration = ReportConfiguration.full
    @State private var preparedBy: String = ""
    @State private var preparedFor: String = ""
    
    // MARK: - UI State
    
    @State private var isGenerating = false
    @State private var generatedPDF: Data?
    @State private var generatedDocx: Data?
    @State private var showPreview = false
    @State private var showShareSheet = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var generationResult: ReportGenerationResult?
    @State private var wordGenerationResult: WordReportGenerationResult?
    @State private var selectedTemplate: ReportTemplate = .comprehensive
    @State private var selectedFormat: ReportExportFormat = .pdf
    
    // Format selection
    enum ReportExportFormat: String, CaseIterable, Identifiable {
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
        
        var description: String {
            switch self {
            case .pdf: return "Best for viewing and printing"
            case .docx: return "Editable in Microsoft Word"
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        caseInfoCard
                        formatSelector
                        templateSelector
                        reportOptionsSection
                        metadataSection
                        generateButton
                        
                        if let result = generationResult, result.success {
                            successSection(result: result)
                        }
                        
                        if let result = wordGenerationResult, result.success {
                            wordSuccessSection(result: result)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Generate Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showPreview) {
                if let pdfData = generatedPDF {
                    PDFPreviewView(pdfData: pdfData, caseNumber: conflictCase.caseNumber)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if selectedFormat == .pdf, let pdfData = generatedPDF {
                    ReportShareSheet(items: [pdfData], fileName: "Case_\(conflictCase.caseNumber)_Report.pdf")
                } else if selectedFormat == .docx, let docxData = generatedDocx {
                    ReportShareSheet(items: [docxData], fileName: "Case_\(conflictCase.caseNumber)_Report.docx")
                }
            }
            .alert("Report Generation Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if isGenerating {
                    generationOverlay
                }
            }
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.systemGray6).opacity(0.5)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Case Investigation Report")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Generate a comprehensive report for this case")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 10)
    }
    
    // MARK: - Case Info Card
    
    private var caseInfoCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Case Number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(conflictCase.caseNumber)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                ReportStatusBadge(status: conflictCase.status)
            }
            
            Divider()
            
            HStack {
                InfoPill(icon: "folder.fill", text: conflictCase.type.displayName, color: conflictCase.type.color)
                Spacer()
                InfoPill(icon: "building.2.fill", text: conflictCase.department, color: .gray)
            }
            
            HStack {
                InfoPill(icon: "calendar", text: formatDate(conflictCase.incidentDate), color: .orange)
                Spacer()
                InfoPill(icon: "person.2.fill", text: "\(conflictCase.involvedEmployees.count) parties", color: .purple)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - Format Selector
    
    private var formatSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.badge.gearshape")
                    .foregroundColor(.purple)
                Text("Export Format")
                    .font(.headline)
            }
            
            HStack(spacing: 12) {
                ForEach(ReportExportFormat.allCases) { format in
                    formatOptionCard(format)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func formatOptionCard(_ format: ReportExportFormat) -> some View {
        let isSelected = selectedFormat == format
        
        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedFormat = format
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.purple.opacity(0.15) : Color(.tertiarySystemBackground))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: format.icon)
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? .purple : .secondary)
                }
                
                Text(format.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSelected ? .purple : .primary)
                
                Text(format.description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.purple.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.purple : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Template Selector
    
    private var templateSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.on.doc.fill")
                    .foregroundColor(.blue)
                Text("Report Template")
                    .font(.headline)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ReportTemplate.allCases, id: \.self) { template in
                        TemplateCard(
                            template: template,
                            isSelected: selectedTemplate == template,
                            action: {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedTemplate = template
                                    applyTemplate(template)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Report Options Section
    
    private var reportOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundColor(.green)
                Text("Include in Report")
                    .font(.headline)
                
                Spacer()
                
                Button(action: selectAll) {
                    Text("Select All")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            
            VStack(spacing: 12) {
                ReportOptionToggle(
                    title: "Executive Summary",
                    subtitle: "High-level case overview and key findings",
                    icon: "doc.text.magnifyingglass",
                    isOn: $reportConfiguration.includeExecutiveSummary
                )
                
                ReportOptionToggle(
                    title: "Case Details",
                    subtitle: "Full case information, dates, and location",
                    icon: "info.circle.fill",
                    isOn: $reportConfiguration.includeCaseDetails
                )
                
                ReportOptionToggle(
                    title: "Involved Parties",
                    subtitle: "All employees involved in the case",
                    icon: "person.2.fill",
                    isOn: $reportConfiguration.includeInvolvedParties
                )
                
                ReportOptionToggle(
                    title: "Document Summary",
                    subtitle: "List of all uploaded documents",
                    icon: "doc.fill",
                    isOn: $reportConfiguration.includeDocumentSummary
                )
                
                ReportOptionToggle(
                    title: "AI Analysis",
                    subtitle: "AI-generated comparison and insights",
                    icon: "brain.head.profile",
                    isOn: $reportConfiguration.includeAIAnalysis,
                    disabled: conflictCase.comparisonResult == nil
                )
                
                ReportOptionToggle(
                    title: "Policy Matches",
                    subtitle: "Relevant policy sections identified",
                    icon: "text.book.closed.fill",
                    isOn: $reportConfiguration.includePolicyMatches,
                    disabled: conflictCase.policyMatches.isEmpty
                )
                
                ReportOptionToggle(
                    title: "Recommendations",
                    subtitle: "AI-generated action recommendations",
                    icon: "lightbulb.fill",
                    isOn: $reportConfiguration.includeRecommendations,
                    disabled: conflictCase.recommendations.isEmpty
                )
                
                ReportOptionToggle(
                    title: "Selected Action",
                    subtitle: "Final action and resolution details",
                    icon: "checkmark.seal.fill",
                    isOn: $reportConfiguration.includeSelectedAction,
                    disabled: conflictCase.selectedAction == nil
                )
                
                ReportOptionToggle(
                    title: "Audit Trail",
                    subtitle: "Complete history of case actions",
                    icon: "clock.arrow.circlepath",
                    isOn: $reportConfiguration.includeAuditTrail,
                    disabled: conflictCase.auditLog.isEmpty
                )
                
                ReportOptionToggle(
                    title: "Signature Blocks",
                    subtitle: "Sign-off sections for approvals",
                    icon: "signature",
                    isOn: $reportConfiguration.includeSignatureBlocks
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Metadata Section
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(.orange)
                Text("Report Metadata")
                    .font(.headline)
            }
            
            // Confidentiality Level
            VStack(alignment: .leading, spacing: 8) {
                Text("Confidentiality Level")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Confidentiality", selection: $reportConfiguration.confidentialityLevel) {
                    ForEach(ReportConfidentialityLevel.allCases, id: \.self) { level in
                        HStack {
                            Circle()
                                .fill(Color(level.color))
                                .frame(width: 8, height: 8)
                            Text(level.rawValue)
                        }
                        .tag(level)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color(reportConfiguration.confidentialityLevel.color))
            }
            
            Divider()
            
            // Prepared By
            VStack(alignment: .leading, spacing: 8) {
                Text("Prepared By")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Your name or title", text: $preparedBy)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: preparedBy) { _, newValue in
                        reportConfiguration.preparedBy = newValue
                    }
            }
            
            // Prepared For
            VStack(alignment: .leading, spacing: 8) {
                Text("Prepared For")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Recipient name or department", text: $preparedFor)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: preparedFor) { _, newValue in
                        reportConfiguration.preparedFor = newValue
                    }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Generate Button
    
    private var generateButton: some View {
        Button(action: generateReport) {
            HStack(spacing: 12) {
                Image(systemName: "doc.badge.plus")
                    .font(.title3)
                Text("Generate Report")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.blue, .indigo],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .disabled(isGenerating)
    }
    
    // MARK: - Success Section
    
    private func successSection(result: ReportGenerationResult) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Report Generated Successfully")
                        .font(.headline)
                        .foregroundColor(.green)
                    Text("\(result.pageCount) pages • Generated \(formatTime(result.generatedAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button(action: { showPreview = true }) {
                    Label("Preview", systemImage: "eye.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                
                Button(action: { showShareSheet = true }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func wordSuccessSection(result: WordReportGenerationResult) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Word Document Generated Successfully")
                        .font(.headline)
                        .foregroundColor(.green)
                    Text("Generated \(formatTime(result.generatedAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "doc.richtext")
                    .font(.title2)
                    .foregroundColor(.purple)
            }
            
            HStack(spacing: 12) {
                Button(action: { showShareSheet = true }) {
                    Label("Share / Save", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
            
            Text("Open in Microsoft Word or compatible apps to view and edit")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.purple.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Generation Overlay
    
    private var generationOverlay: some View {
        let progress = selectedFormat == .pdf ? reportService.generationProgress : CaseWordReportService.shared.generationProgress
        let step = selectedFormat == .pdf ? reportService.currentStep : CaseWordReportService.shared.currentStep
        let colors: [Color] = selectedFormat == .pdf ? [.blue, .cyan] : [.purple, .pink]
        
        return ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progress)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 8) {
                    Text("Generating \(selectedFormat == .pdf ? "PDF" : "Word Document")")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(step)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
            )
        }
    }
    
    // MARK: - Actions
    
    private func generateReport() {
        isGenerating = true
        generatedPDF = nil
        generatedDocx = nil
        generationResult = nil
        wordGenerationResult = nil
        
        Task {
            if selectedFormat == .pdf {
                let result = await reportService.generateReport(
                    for: conflictCase,
                    configuration: reportConfiguration
                )
                
                await MainActor.run {
                    isGenerating = false
                    
                    if result.success {
                        generatedPDF = result.pdfData
                        generationResult = result
                    } else {
                        errorMessage = result.errorMessage ?? "Unknown error occurred"
                        showError = true
                    }
                }
            } else {
                // Word document generation
                let wordConfig = convertToWordConfig(reportConfiguration)
                let result = await CaseWordReportService.shared.generateReport(
                    for: conflictCase,
                    configuration: wordConfig
                )
                
                await MainActor.run {
                    isGenerating = false
                    
                    if result.success {
                        generatedDocx = result.docxData
                        wordGenerationResult = result
                    } else {
                        errorMessage = result.errorMessage ?? "Unknown error occurred"
                        showError = true
                    }
                }
            }
        }
    }
    
    private func convertToWordConfig(_ pdfConfig: ReportConfiguration) -> WordReportConfiguration {
        var wordConfig = WordReportConfiguration()
        wordConfig.includeExecutiveSummary = pdfConfig.includeExecutiveSummary
        wordConfig.includeCaseDetails = pdfConfig.includeCaseDetails
        wordConfig.includeInvolvedParties = pdfConfig.includeInvolvedParties
        wordConfig.includeDocumentSummary = pdfConfig.includeDocumentSummary
        wordConfig.includeFullStatements = pdfConfig.includeFullStatements
        wordConfig.includeScannedDocuments = pdfConfig.includeScannedDocuments
        wordConfig.includeAIAnalysis = pdfConfig.includeAIAnalysis
        wordConfig.includePolicyMatches = pdfConfig.includePolicyMatches
        wordConfig.includeRecommendations = pdfConfig.includeRecommendations
        wordConfig.includeSelectedAction = pdfConfig.includeSelectedAction
        wordConfig.includeGeneratedDocument = pdfConfig.includeGeneratedDocument
        wordConfig.includeAuditTrail = pdfConfig.includeAuditTrail
        wordConfig.includeSignatureBlocks = pdfConfig.includeSignatureBlocks
        wordConfig.reportTitle = pdfConfig.reportTitle
        wordConfig.preparedBy = pdfConfig.preparedBy
        wordConfig.preparedFor = pdfConfig.preparedFor
        
        // Map confidentiality level
        switch pdfConfig.confidentialityLevel {
        case .confidential: wordConfig.confidentialityLevel = .confidential
        case .restricted: wordConfig.confidentialityLevel = .restricted
        case .internalOnly: wordConfig.confidentialityLevel = .internalOnly
        case .hrOnly: wordConfig.confidentialityLevel = .hrOnly
        }
        
        return wordConfig
    }
    
    private func selectAll() {
        withAnimation {
            reportConfiguration.includeExecutiveSummary = true
            reportConfiguration.includeCaseDetails = true
            reportConfiguration.includeInvolvedParties = true
            reportConfiguration.includeDocumentSummary = true
            reportConfiguration.includeAIAnalysis = conflictCase.comparisonResult != nil
            reportConfiguration.includePolicyMatches = !conflictCase.policyMatches.isEmpty
            reportConfiguration.includeRecommendations = !conflictCase.recommendations.isEmpty
            reportConfiguration.includeSelectedAction = conflictCase.selectedAction != nil
            reportConfiguration.includeAuditTrail = !conflictCase.auditLog.isEmpty
            reportConfiguration.includeSignatureBlocks = true
        }
    }
    
    private func applyTemplate(_ template: ReportTemplate) {
        switch template {
        case .comprehensive:
            reportConfiguration = .full
        case .executive:
            reportConfiguration = .executive
        case .summary:
            reportConfiguration = .summary
        case .hrReview:
            reportConfiguration = ReportConfiguration.full
            reportConfiguration.confidentialityLevel = .hrOnly
            reportConfiguration.reportTitle = "HR Case Review Report"
        case .legal:
            reportConfiguration = ReportConfiguration.full
            reportConfiguration.confidentialityLevel = .restricted
            reportConfiguration.reportTitle = "Legal Case Documentation"
            reportConfiguration.includeGeneratedDocument = true
        }
        // Preserve user-entered metadata
        reportConfiguration.preparedBy = preparedBy
        reportConfiguration.preparedFor = preparedFor
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Report Template

enum ReportTemplate: String, CaseIterable {
    case comprehensive = "Comprehensive"
    case executive = "Executive"
    case summary = "Summary"
    case hrReview = "HR Review"
    case legal = "Legal"
    
    var icon: String {
        switch self {
        case .comprehensive: return "doc.text.fill"
        case .executive: return "person.crop.rectangle.stack.fill"
        case .summary: return "list.bullet.rectangle.portrait.fill"
        case .hrReview: return "person.crop.circle.badge.checkmark"
        case .legal: return "scale.3d"
        }
    }
    
    var description: String {
        switch self {
        case .comprehensive: return "Full detailed report"
        case .executive: return "High-level overview"
        case .summary: return "Condensed key points"
        case .hrReview: return "HR-focused review"
        case .legal: return "Legal documentation"
        }
    }
    
    var color: Color {
        switch self {
        case .comprehensive: return .blue
        case .executive: return .purple
        case .summary: return .green
        case .hrReview: return .orange
        case .legal: return .red
        }
    }
}

// MARK: - Supporting Views

private struct ReportStatusBadge: View {
    let status: CaseStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(status.color.opacity(0.15))
            .foregroundColor(status.color)
            .clipShape(Capsule())
    }
}

private struct InfoPill: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

private struct TemplateCard: View {
    let template: ReportTemplate
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(template.color.opacity(isSelected ? 0.2 : 0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: template.icon)
                        .font(.system(size: 18))
                        .foregroundColor(template.color)
                }
                
                VStack(spacing: 2) {
                    Text(template.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? template.color : .primary)
                    
                    Text(template.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 100)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? template.color.opacity(0.1) : Color(.tertiarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? template.color : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ReportOptionToggle: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    var disabled: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isOn ? Color.blue.opacity(0.15) : Color(.tertiarySystemFill))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isOn ? .blue : .gray)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(disabled ? .secondary : .primary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if disabled {
                Text("N/A")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            } else {
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(.blue)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemBackground))
        )
        .opacity(disabled ? 0.6 : 1.0)
    }
}

// MARK: - PDF Preview View

private struct PDFPreviewView: View {
    let pdfData: Data
    let caseNumber: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationStack {
            PDFKitView(data: pdfData)
                .navigationTitle("Report Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { showShareSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                .sheet(isPresented: $showShareSheet) {
                    ReportShareSheet(items: [pdfData], fileName: "Case_\(caseNumber)_Report.pdf")
                }
        }
    }
}

private struct PDFKitView: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(data: data)
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document == nil {
            uiView.document = PDFDocument(data: data)
        }
    }
}

// MARK: - Share Sheet

private struct ReportShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let fileName: String
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Create a temporary file with proper name
        var activityItems: [Any] = []
        
        for item in items {
            if let data = item as? Data {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try? data.write(to: tempURL)
                activityItems.append(tempURL)
            } else {
                activityItems.append(item)
            }
        }
        
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    CaseReportGenerationView(
        conflictCase: ConflictCase(
            caseNumber: "CR-2024-0001",
            type: .conflict,
            status: .inProgress,
            description: "Sample workplace conflict for preview purposes.",
            incidentDate: Date(),
            location: "Assembly, Die Cut Line 2, Pack-Off",
            department: "Engineering",
            involvedEmployees: [
                InvolvedEmployee(name: "John Smith", role: "Engineer", department: "Engineering", employeeId: "EMP001", isComplainant: true),
                InvolvedEmployee(name: "Jane Doe", role: "Manager", department: "Engineering", employeeId: "EMP002", isComplainant: true)
            ],
            documents: [],
            comparisonResult: nil,
            policyMatches: [],
            recommendations: [],
            selectedAction: nil,
            generatedDocument: nil,
            auditLog: [],
            createdBy: "Admin",
            createdAt: Date(),
            updatedAt: Date()
        )
    )
}
