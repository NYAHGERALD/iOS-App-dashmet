//
//  CaseFinalizationView.swift
//  MeetingIntelligence
//
//  Phase 10: Case Finalization
//  Allows supervisor to finalize case, export documents, and optionally send to HR
//

import SwiftUI
import PDFKit

// MARK: - Finalization Option
enum FinalizationOption: String, CaseIterable {
    case closeCase = "Close Case"
    case sendToHR = "Send to HR"
    case exportPackage = "Export Package"
    
    var icon: String {
        switch self {
        case .closeCase: return "checkmark.circle.fill"
        case .sendToHR: return "person.2.fill"
        case .exportPackage: return "square.and.arrow.up.fill"
        }
    }
    
    var description: String {
        switch self {
        case .closeCase: return "Finalize and lock the case record"
        case .sendToHR: return "Send complete package to HR for review"
        case .exportPackage: return "Download PDF package with all documents"
        }
    }
    
    var color: Color {
        switch self {
        case .closeCase: return .green
        case .sendToHR: return .blue
        case .exportPackage: return .orange
        }
    }
}

// MARK: - Case Finalization View
struct CaseFinalizationView: View {
    let conflictCase: ConflictCase
    let generatedDocument: GeneratedDocumentResult?
    let onFinalize: () -> Void
    let onSendToHR: () -> Void
    let onExport: () -> Void
    let onBack: () -> Void
    
    @State private var selectedOption: FinalizationOption? = nil
    @State private var showConfirmation = false
    @State private var supervisorNotes = ""
    @State private var hrRecipient = ""
    @State private var urgencyLevel: UrgencyLevel = .standard
    @State private var includeAllDocuments = true
    @State private var includeAuditTrail = true
    @State private var isProcessing = false
    @State private var showShareSheet = false
    @State private var pdfData: Data?
    
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
                        
                        // Supervisor Notes
                        supervisorNotesSection
                        
                        // Action Button
                        actionButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Finalize Case")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        onBack()
                    }
                }
            }
            .alert("Confirm Finalization", isPresented: $showConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Finalize", role: .destructive) {
                    executeFinalization()
                }
            } message: {
                Text(confirmationMessage)
            }
            .sheet(isPresented: $showShareSheet) {
                if let data = pdfData {
                    ShareSheet(items: [data])
                }
            }
        }
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
            
            Text("Phase 10: Case Finalization")
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
            
            ForEach(FinalizationOption.allCases, id: \.self) { option in
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
            case .sendToHR:
                sendToHROptions
            case .exportPackage:
                exportOptions
            }
        }
    }
    
    // MARK: - Close Case Options
    private var closeCaseOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("This action will lock the case record")
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 8) {
                toggleOption(
                    title: "Include audit trail",
                    isOn: $includeAuditTrail,
                    description: "Preserve complete history of all actions"
                )
                
                toggleOption(
                    title: "Include all documents",
                    isOn: $includeAllDocuments,
                    description: "Archive all case documents"
                )
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Send to HR Options
    private var sendToHROptions: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Recipient
            VStack(alignment: .leading, spacing: 8) {
                Text("HR Recipient")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textSecondary)
                
                TextField("Enter email or name", text: $hrRecipient)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(innerCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Urgency Level
            VStack(alignment: .leading, spacing: 8) {
                Text("Urgency Level")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textSecondary)
                
                HStack(spacing: 8) {
                    ForEach(UrgencyLevel.allCases, id: \.self) { level in
                        Button {
                            urgencyLevel = level
                        } label: {
                            Text(level.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(urgencyLevel == level ? .white : level.color)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(urgencyLevel == level ? level.color : level.color.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            // Include Options
            VStack(alignment: .leading, spacing: 8) {
                toggleOption(
                    title: "Include all documents",
                    isOn: $includeAllDocuments,
                    description: "Attach all case documents"
                )
                
                toggleOption(
                    title: "Include audit trail",
                    isOn: $includeAuditTrail,
                    description: "Include action history"
                )
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Export Options
    private var exportOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export will include:")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(textSecondary)
            
            VStack(spacing: 8) {
                exportIncludeItem("Case summary", icon: "doc.text")
                exportIncludeItem("Generated document", icon: "doc.fill")
                
                if includeAllDocuments {
                    exportIncludeItem("All attached documents", icon: "doc.on.doc")
                }
                
                if includeAuditTrail {
                    exportIncludeItem("Complete audit trail", icon: "clock.arrow.circlepath")
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                toggleOption(
                    title: "Include all documents",
                    isOn: $includeAllDocuments,
                    description: "Add scanned complaints and evidence"
                )
                
                toggleOption(
                    title: "Include audit trail",
                    isOn: $includeAuditTrail,
                    description: "Add timestamped action log"
                )
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
                if isProcessing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: selectedOption?.icon ?? "checkmark.circle.fill")
                    Text(actionButtonTitle)
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(selectedOption?.color ?? .gray)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(selectedOption == nil || isProcessing || (selectedOption == .sendToHR && hrRecipient.isEmpty))
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
    
    private func exportIncludeItem(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(textPrimary)
            Spacer()
            Image(systemName: "checkmark")
                .foregroundColor(.green)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Computed Properties
    private var actionButtonTitle: String {
        switch selectedOption {
        case .closeCase: return "Finalize & Close Case"
        case .sendToHR: return "Send to HR"
        case .exportPackage: return "Export PDF Package"
        case .none: return "Select an Option"
        }
    }
    
    private var confirmationMessage: String {
        switch selectedOption {
        case .closeCase:
            return "This will permanently close and lock the case record. This action cannot be undone."
        case .sendToHR:
            return "The complete case package will be sent to \(hrRecipient). Continue?"
        case .exportPackage:
            return "A PDF package containing all selected documents will be generated."
        case .none:
            return ""
        }
    }
    
    // MARK: - Actions
    private func executeFinalization() {
        isProcessing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isProcessing = false
            
            switch selectedOption {
            case .closeCase:
                onFinalize()
            case .sendToHR:
                onSendToHR()
            case .exportPackage:
                generateAndSharePDF()
            case .none:
                break
            }
        }
    }
    
    private func generateAndSharePDF() {
        // Generate PDF data
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ]
            
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.darkGray
            ]
            
            // Title
            let title = "Case Finalization Package"
            title.draw(at: CGPoint(x: 50, y: 50), withAttributes: titleAttributes)
            
            // Case Info
            var yPosition: CGFloat = 100
            let info = """
            Case ID: \(conflictCase.caseNumber)
            Type: \(conflictCase.type.displayName)
            Status: \(conflictCase.status.displayName)
            Created: \(formatDate(conflictCase.createdAt))
            Finalized: \(formatDate(Date()))
            
            Documents: \(conflictCase.documents.count)
            Parties Involved: \(conflictCase.involvedEmployees.count)
            
            Supervisor Notes:
            \(supervisorNotes.isEmpty ? "None" : supervisorNotes)
            """
            
            info.draw(
                in: CGRect(x: 50, y: yPosition, width: 512, height: 600),
                withAttributes: textAttributes
            )
        }
        
        self.pdfData = data
        showShareSheet = true
        onExport()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Urgency Level
enum UrgencyLevel: String, CaseIterable {
    case low = "Low"
    case standard = "Standard"
    case high = "High"
    case critical = "Critical"
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .standard: return .blue
        case .high: return .orange
        case .critical: return .red
        }
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
        onSendToHR: {},
        onExport: {},
        onBack: {}
    )
}
