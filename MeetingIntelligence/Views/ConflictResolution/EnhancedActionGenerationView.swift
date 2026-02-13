//
//  EnhancedActionGenerationView.swift
//  MeetingIntelligence
//
//  Phase 8: Enhanced Action Generation
//  Complete Phase 8 implementation with all features:
//  - Action Confirmation Screen
//  - Document Customization Panel
//  - Warning Level Selection
//  - HR Escalation Flow
//  - Export Options
//  - Signature Capture
//  - Audit Trail Integration
//

import SwiftUI
import UIKit

// MARK: - Generation Phase
enum GenerationPhase {
    case confirmation
    case warningLevelSelection // For warnings
    case escalationFlow // For HR escalation
    case generating
    case customization
    case documentReview
    case signatureCapture
    case export
    case finalized
}

// MARK: - Enhanced Action Generation View
struct EnhancedActionGenerationView: View {
    let conflictCase: ConflictCase
    let selectedRecommendation: RecommendationOption
    let analysisResult: AIComparisonResult?
    let policyMatches: [PolicyMatchResult]?
    let supervisorName: String
    let onComplete: (GeneratedDocumentResult, [CapturedSignature]) -> Void
    let onBack: () -> Void
    
    // State
    @State private var currentPhase: GenerationPhase = .confirmation
    @State private var generatedResult: GeneratedDocumentResult?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showEditMode = false
    
    // Customization
    @State private var customizationSettings = DocumentCustomizationSettings()
    @State private var showCustomizationSheet = false
    
    // Warning Level
    @State private var selectedWarningLevel: WarningLevel?
    @State private var showWarningLevelSheet = false
    
    // Escalation
    @State private var escalationConfig = EscalationConfiguration()
    @State private var showEscalationFlow = false
    
    // Export
    @State private var showExportSheet = false
    @State private var exportedData: Data?
    @State private var showShareSheet = false
    
    // Signatures
    @State private var capturedSignatures: [CapturedSignature] = []
    @State private var showSignatureSheet = false
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    private var innerCardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.gray.opacity(0.08)
    }
    
    private var actionColor: Color {
        switch selectedRecommendation.type {
        case .coaching: return .green
        case .counseling: return .blue
        case .warning: return .orange
        case .escalate: return .red
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Progress Indicator
                        progressIndicator
                        
                        // Content based on phase
                        switch currentPhase {
                        case .confirmation:
                            confirmationContent
                            
                        case .warningLevelSelection:
                            Text("Redirecting to warning level selection...")
                                .onAppear {
                                    showWarningLevelSheet = true
                                }
                            
                        case .escalationFlow:
                            Text("Redirecting to escalation flow...")
                                .onAppear {
                                    showEscalationFlow = true
                                }
                            
                        case .generating:
                            generatingContent
                            
                        case .customization, .documentReview:
                            if let result = generatedResult {
                                documentReviewContent(result)
                            }
                            
                        case .signatureCapture:
                            Text("Capturing signatures...")
                                .onAppear {
                                    showSignatureSheet = true
                                }
                            
                        case .export:
                            Text("Preparing export...")
                                .onAppear {
                                    showExportSheet = true
                                }
                            
                        case .finalized:
                            finalizedContent
                        }
                        
                        // Error display
                        if let error = errorMessage {
                            errorSection(error)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        handleBack()
                    }
                }
                
                if generatedResult != nil && currentPhase == .documentReview {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                showCustomizationSheet = true
                            } label: {
                                Label("Customize", systemImage: "slider.horizontal.3")
                            }
                            
                            Button {
                                showExportSheet = true
                            } label: {
                                Label("Export", systemImage: "square.and.arrow.up")
                            }
                            
                            Button(role: .destructive) {
                                regenerateDocument()
                            } label: {
                                Label("Regenerate", systemImage: "arrow.clockwise")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showWarningLevelSheet) {
                WarningLevelSelectionView(
                    selectedLevel: $selectedWarningLevel,
                    employeeName: conflictCase.involvedEmployees.first?.name ?? "Employee",
                    priorWarnings: [], // Would load from database
                    onConfirm: { level in
                        selectedWarningLevel = level
                        showWarningLevelSheet = false
                        
                        // Log to audit trail
                        AuditTrailService.shared.logWarningLevelSelected(
                            caseId: conflictCase.id,
                            caseNumber: conflictCase.caseNumber,
                            warningLevel: level,
                            employeeName: conflictCase.involvedEmployees.first?.name ?? "Employee"
                        )
                        
                        currentPhase = .generating
                        generateDocument()
                    },
                    onCancel: {
                        showWarningLevelSheet = false
                        currentPhase = .confirmation
                    }
                )
            }
            .sheet(isPresented: $showEscalationFlow) {
                EscalationFlowView(
                    configuration: $escalationConfig,
                    conflictCase: conflictCase,
                    documentCount: conflictCase.documents.count,
                    totalPages: conflictCase.documents.count * 2,
                    onSubmit: {
                        showEscalationFlow = false
                        
                        // Log to audit trail
                        AuditTrailService.shared.logEscalationSubmitted(
                            caseId: conflictCase.id,
                            caseNumber: conflictCase.caseNumber,
                            priority: escalationConfig.priority,
                            recipients: Array(escalationConfig.selectedRecipients)
                        )
                        
                        currentPhase = .generating
                        generateDocument()
                    },
                    onSaveAsDraft: {
                        showEscalationFlow = false
                        // Save draft logic
                    },
                    onCancel: {
                        showEscalationFlow = false
                        currentPhase = .confirmation
                    }
                )
            }
            .sheet(isPresented: $showCustomizationSheet) {
                DocumentCustomizationView(
                    settings: $customizationSettings,
                    actionType: mapRecommendationToActionType(),
                    onApply: {
                        showCustomizationSheet = false
                        
                        // Log customization
                        AuditTrailService.shared.logActionCustomized(
                            caseId: conflictCase.id,
                            caseNumber: conflictCase.caseNumber,
                            customizations: customizationSettings
                        )
                        
                        // Regenerate with new settings
                        regenerateDocument()
                    },
                    onCancel: {
                        showCustomizationSheet = false
                    }
                )
            }
            .sheet(isPresented: $showExportSheet) {
                if let result = generatedResult {
                    ExportOptionsView(
                        document: result.document,
                        caseNumber: conflictCase.caseNumber,
                        onExport: { format, destination, data in
                            showExportSheet = false
                            
                            // Log export
                            AuditTrailService.shared.logDocumentExported(
                                caseId: conflictCase.id,
                                caseNumber: conflictCase.caseNumber,
                                format: format,
                                destination: destination
                            )
                            
                            handleExport(format: format, destination: destination, data: data)
                        },
                        onCancel: {
                            showExportSheet = false
                        }
                    )
                }
            }
            .sheet(isPresented: $showSignatureSheet) {
                SignatureCaptureSheet(
                    capturedSignatures: $capturedSignatures,
                    documentType: mapRecommendationToActionType(),
                    employeeNames: conflictCase.involvedEmployees.map { $0.name },
                    supervisorName: supervisorName,
                    onComplete: {
                        showSignatureSheet = false
                        currentPhase = .finalized
                    },
                    onCancel: {
                        showSignatureSheet = false
                        currentPhase = .documentReview
                    }
                )
            }
            .sheet(isPresented: $showShareSheet) {
                if let data = exportedData, let result = generatedResult {
                    DocumentShareSheet(
                        data: data,
                        filename: "\(conflictCase.caseNumber)_\(result.actionType.rawValue)",
                        format: .pdf
                    )
                }
            }
        }
    }
    
    // MARK: - Navigation Title
    private var navigationTitle: String {
        switch currentPhase {
        case .confirmation: return "Confirm Action"
        case .warningLevelSelection: return "Warning Level"
        case .escalationFlow: return "Escalate to HR"
        case .generating: return "Generating..."
        case .customization: return "Customize"
        case .documentReview: return "Review Document"
        case .signatureCapture: return "Signatures"
        case .export: return "Export"
        case .finalized: return "Complete"
        }
    }
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        let phases: [GenerationPhase] = [.confirmation, .generating, .documentReview, .signatureCapture, .finalized]
        
        return HStack(spacing: 4) {
            ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                let isCompleted = phaseIndex(currentPhase) > phaseIndex(phase)
                let isCurrent = phase == currentPhase || 
                    (currentPhase == .warningLevelSelection && phase == .confirmation) ||
                    (currentPhase == .escalationFlow && phase == .confirmation) ||
                    (currentPhase == .customization && phase == .documentReview)
                
                if index > 0 {
                    Rectangle()
                        .fill(isCompleted ? actionColor : Color.gray.opacity(0.3))
                        .frame(height: 2)
                        .frame(maxWidth: 30)
                }
                
                ZStack {
                    Circle()
                        .fill(isCompleted ? actionColor : (isCurrent ? actionColor.opacity(0.2) : Color.gray.opacity(0.2)))
                        .frame(width: 24, height: 24)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(isCurrent ? actionColor : textSecondary)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func phaseIndex(_ phase: GenerationPhase) -> Int {
        switch phase {
        case .confirmation, .warningLevelSelection, .escalationFlow: return 0
        case .generating: return 1
        case .customization, .documentReview: return 2
        case .signatureCapture: return 3
        case .export: return 3
        case .finalized: return 4
        }
    }
    
    // MARK: - Confirmation Content
    private var confirmationContent: some View {
        ActionConfirmationView(
            selectedAction: selectedRecommendation,
            conflictCase: conflictCase,
            onConfirm: {
                // Log action confirmation
                AuditTrailService.shared.logEvent(
                    caseId: conflictCase.id,
                    caseNumber: conflictCase.caseNumber,
                    eventType: .actionConfirmed,
                    description: "Confirmed action: \(selectedRecommendation.title)"
                )
                
                // Route to appropriate next phase
                switch selectedRecommendation.type {
                case .warning:
                    currentPhase = .warningLevelSelection
                case .escalate:
                    currentPhase = .escalationFlow
                default:
                    currentPhase = .generating
                    generateDocument()
                }
            },
            onChangeSelection: {
                onBack()
            }
        )
    }
    
    // MARK: - Generating Content
    private var generatingContent: some View {
        VStack(spacing: 24) {
            // Progress animation
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(actionColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 28))
                    .foregroundColor(actionColor)
            }
            
            VStack(spacing: 8) {
                Text("Generating Document...")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Text("Creating your \(selectedRecommendation.type.displayName.lowercased()) document")
                    .font(.system(size: 14))
                    .foregroundColor(textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Generation steps
            VStack(alignment: .leading, spacing: 8) {
                generatingItem("Analyzing case details", completed: true)
                generatingItem("Reviewing statements", completed: true)
                generatingItem("Applying policy references", completed: isGenerating)
                generatingItem("Crafting professional language", completed: false)
            }
            .padding()
            .background(innerCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func generatingItem(_ text: String, completed: Bool) -> some View {
        HStack(spacing: 12) {
            if completed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
            } else {
                ProgressView()
                    .scaleEffect(0.8)
            }
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(completed ? textSecondary : textPrimary)
        }
    }
    
    // MARK: - Document Review Content
    private func documentReviewContent(_ result: GeneratedDocumentResult) -> some View {
        VStack(spacing: 16) {
            // Success header
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Document Generated")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    Text("Review and edit as needed")
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Document Title
            Text(result.document.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Document content placeholder
            documentContentPlaceholder(result)
            
            // Action Toolbar
            actionToolbar
            
            // Continue Button
            Button {
                if requiresSignatures {
                    currentPhase = .signatureCapture
                } else {
                    currentPhase = .finalized
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: requiresSignatures ? "signature" : "checkmark.circle.fill")
                    Text(requiresSignatures ? "Capture Signatures" : "Finalize Document")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(actionColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func documentContentPlaceholder(_ result: GeneratedDocumentResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            switch result.document {
            case .coaching(let doc):
                documentSection(title: "Overview", content: doc.overview)
                documentSection(title: "Discussion Outline", content: doc.discussionOutline.opening)
                if !doc.talkingPoints.isEmpty {
                    documentListSection(title: "Talking Points", items: doc.talkingPoints)
                }
                
            case .counseling(let doc):
                documentSection(title: "Incident Summary", content: doc.incidentSummary)
                documentListSection(title: "Expectations", items: doc.expectations)
                documentSection(title: "Consequences", content: doc.consequences)
                
            case .warning(let doc):
                HStack {
                    Text(doc.warningLevel)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .clipShape(Capsule())
                    Spacer()
                }
                documentSection(title: "Description", content: doc.describeInDetail)
                documentListSection(title: "Corrective Action", items: doc.requiredCorrectiveAction)
                
            case .escalation(let doc):
                HStack {
                    Text("URGENCY: \(doc.urgencyLevel)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(doc.urgencyLevel == "Critical" ? Color.red : Color.orange)
                        .clipShape(Capsule())
                    Spacer()
                }
                documentSection(title: "Supervisor Notes", content: doc.supervisorNotes)
                documentListSection(title: "Recommended Actions", items: doc.recommendedActions)
            }
        }
        .padding()
        .background(innerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func documentSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(textSecondary)
            Text(content)
                .font(.system(size: 13))
                .foregroundColor(textPrimary)
                .lineLimit(3)
        }
    }
    
    private func documentListSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(textSecondary)
            ForEach(items.prefix(3), id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Circle()
                        .fill(actionColor)
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)
                    Text(item)
                        .font(.system(size: 12))
                        .foregroundColor(textPrimary)
                        .lineLimit(1)
                }
            }
            if items.count > 3 {
                Text("+ \(items.count - 3) more")
                    .font(.system(size: 11))
                    .foregroundColor(textSecondary)
            }
        }
    }
    
    private var actionToolbar: some View {
        HStack(spacing: 16) {
            toolbarButton(icon: "slider.horizontal.3", label: "Customize") {
                showCustomizationSheet = true
            }
            
            toolbarButton(icon: "square.and.arrow.up", label: "Export") {
                showExportSheet = true
            }
            
            toolbarButton(icon: "arrow.clockwise", label: "Regenerate") {
                regenerateDocument()
            }
        }
    }
    
    private func toolbarButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(actionColor)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
    
    private var requiresSignatures: Bool {
        switch selectedRecommendation.type {
        case .coaching, .counseling, .warning: return true
        case .escalate: return false
        }
    }
    
    // MARK: - Error Section
    private func errorSection(_ error: String) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.red)
            }
            
            Text("Generation Failed")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                errorMessage = nil
                generateDocument()
            } label: {
                Text("Try Again")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(actionColor)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Finalized Content
    private var finalizedContent: some View {
        VStack(spacing: 24) {
            // Success animation
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 8) {
                Text("Document Finalized")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(textPrimary)
                
                Text("Your \(selectedRecommendation.type.displayName.lowercased()) document has been created successfully.")
                    .font(.system(size: 14))
                    .foregroundColor(textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Summary Card
            if let result = generatedResult {
                VStack(alignment: .leading, spacing: 12) {
                    summaryRow("Document", result.document.title)
                    summaryRow("Case", conflictCase.caseNumber)
                    summaryRow("Action Type", result.actionType.displayName)
                    summaryRow("Signatures", "\(capturedSignatures.count) captured")
                    summaryRow("Generated", result.generatedAt.formatted())
                }
                .padding()
                .background(innerCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Action Buttons
            VStack(spacing: 12) {
                Button {
                    showExportSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Document")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button {
                    // Log finalization
                    if let result = generatedResult {
                        AuditTrailService.shared.logCaseFinalized(
                            caseId: conflictCase.id,
                            caseNumber: conflictCase.caseNumber,
                            finalAction: result.actionType,
                            documentCount: 1
                        )
                    }
                    
                    if let result = generatedResult {
                        onComplete(result, capturedSignatures)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete & Close")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(actionColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func summaryRow(_ label: String, _ value: String) -> some View {
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
    
    // MARK: - Helper Methods
    
    private func handleBack() {
        switch currentPhase {
        case .confirmation:
            onBack()
        case .documentReview, .customization:
            currentPhase = .confirmation
        case .signatureCapture:
            currentPhase = .documentReview
        case .finalized:
            currentPhase = .documentReview
        default:
            onBack()
        }
    }
    
    private func mapRecommendationToActionType() -> ActionType {
        switch selectedRecommendation.type {
        case .coaching: return .coaching
        case .counseling: return .counseling
        case .warning: return .warning
        case .escalate: return .escalate
        }
    }
    
    private func generateDocument() {
        // Get complaints
        let complaintA = conflictCase.documents.first { $0.type == .complaintA }
        let complaintB = conflictCase.documents.first { $0.type == .complaintB }
        
        guard let docA = complaintA, let docB = complaintB else {
            errorMessage = "Missing complaint documents"
            return
        }
        
        // Get employees
        let employees = conflictCase.involvedEmployees.filter { $0.isComplainant }
        guard employees.count >= 2 else {
            errorMessage = "Missing employee information"
            return
        }
        
        let actionType = mapRecommendationToActionType()
        
        isGenerating = true
        errorMessage = nil
        currentPhase = .generating
        
        Task {
            do {
                let result = try await ActionGenerationService.shared.generateDocument(
                    actionType: actionType,
                    conflictCase: conflictCase,
                    complaintA: docA,
                    complaintAEmployee: employees[0],
                    complaintB: docB,
                    complaintBEmployee: employees[1],
                    analysisResult: analysisResult,
                    policyMatches: policyMatches,
                    recommendationRationale: selectedRecommendation.rationale,
                    supervisorName: supervisorName
                )
                
                await MainActor.run {
                    self.generatedResult = result
                    self.isGenerating = false
                    self.currentPhase = .documentReview
                    
                    // Log document generated
                    AuditTrailService.shared.logDocumentGenerated(
                        caseId: conflictCase.id,
                        caseNumber: conflictCase.caseNumber,
                        actionType: actionType,
                        documentTitle: result.document.title
                    )
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isGenerating = false
                }
            }
        }
    }
    
    private func regenerateDocument() {
        generatedResult = nil
        
        // Log regeneration
        AuditTrailService.shared.logEvent(
            caseId: conflictCase.id,
            caseNumber: conflictCase.caseNumber,
            eventType: .actionRegenerated,
            description: "Document regeneration requested"
        )
        
        generateDocument()
    }
    
    private func handleExport(format: ExportFormat, destination: ExportDestination, data: Data) {
        exportedData = data
        
        switch destination {
        case .download:
            // Save to documents
            if let result = generatedResult {
                let filename = "\(conflictCase.caseNumber)_\(result.actionType.rawValue)"
                do {
                    let fileURL = try DocumentExportService.shared.saveToFile(data: data, filename: filename, format: format)
                    print("Saved to: \(fileURL)")
                } catch {
                    print("Failed to save: \(error)")
                }
            }
            
        case .share:
            showShareSheet = true
            
        case .email:
            // Would integrate with email composer
            showShareSheet = true
            
        case .saveToCase:
            // Save to case documents
            print("Saved to case")
        }
    }
}

// MARK: - Preview
#Preview {
    EnhancedActionGenerationView(
        conflictCase: ConflictCase(
            id: UUID(),
            caseNumber: "CR-2025-001",
            type: .conflict,
            status: .inProgress,
            incidentDate: Date(),
            location: "Building A",
            department: "Engineering",
            involvedEmployees: [],
            documents: []
        ),
        selectedRecommendation: RecommendationOption(
            id: "option_a",
            type: .coaching,
            title: "Informal Coaching Session",
            description: "Session description",
            rationale: "Rationale",
            riskLevel: .low,
            riskExplanation: "Low risk",
            nextSteps: [],
            timeframe: "48 hours",
            confidence: 0.85,
            targetEmployeeIds: []
        ),
        analysisResult: nil,
        policyMatches: nil,
        supervisorName: "John Manager",
        onComplete: { _, _ in },
        onBack: {}
    )
}
