//
//  CaseDetailView.swift
//  MeetingIntelligence
//
//  View for detailed case information and workflow management
//  Updated: Feb 2026
//

import SwiftUI
import AVFoundation

struct CaseDetailView: View {
    @StateObject private var manager = ConflictResolutionManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    let caseId: UUID
    
    init(caseId: UUID) {
        self.caseId = caseId
    }
    
    @State private var selectedTab = 0
    @State private var showAddDocument = false
    @State private var showGenerateReport = false
    @State private var showDeleteConfirmation = false
    @State private var expandedDocuments: Set<UUID> = []
    @State private var selectedEmployeeForEdit: InvolvedEmployee? = nil
    @State private var showEditEmployeeSheet = false
    @State private var showAddEmployeeSheet = false
    
    // AI Analysis State
    @State private var isAnalyzing = false
    @State private var analysisError: String? = nil
    @State private var showAnalysisErrorAlert = false
    @State private var showFullAnalysisView = false
    @State private var reanalysisVersion: Int = 0           // Triggers child view resets
    @State private var shouldAutoRunPolicyMatch = false     // Auto-run policy after re-analysis
    @State private var shouldAutoRunDecisionSupport = false // Auto-run decision support after policy
    
    // Phase 5: Evidence Expansion State
    @State private var selectedWitnessForStatement: InvolvedEmployee? = nil
    @State private var showWitnessStatementScanner = false
    
    // Phase 6: Policy Alignment State
    @State private var showPolicyPicker = false
    @State private var policyMatchResults: [PolicyMatchResult] = []
    
    // Phase 7: Decision Support State
    @State private var selectedRecommendation: RecommendationOption? = nil
    
    // Phase 8: Action Generation State
    @State private var showActionGeneration = false
    @State private var generatedDocument: GeneratedDocumentResult? = nil
    
    // Phase 9: Supervisor Review State
    @State private var showSupervisorReview = false
    
    // Phase 10: Finalization State
    @State private var showFinalization = false
    
    // Adaptive colors
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
    
    private var cardBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }
    
    private var conflictCase: ConflictCase? {
        manager.cases.first { $0.id == caseId }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                if let caseItem = conflictCase {
                    GeometryReader { geometry in
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(spacing: 20) {
                                // Case Header
                                caseHeaderSection(caseItem)
                                
                                // Status Progress
                                statusProgressSection(caseItem)
                                
                                // Tab Selector
                                tabSelector
                                
                                // Tab Content
                                tabContent(caseItem)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 16)
                            .frame(width: geometry.size.width)
                        }
                    }
                } else {
                    caseNotFoundView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Cases")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(AppColors.primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if conflictCase != nil {
                            Button {
                                showAddDocument = true
                            } label: {
                                Label("Add Document", systemImage: "doc.badge.plus")
                            }
                            
                            Button {
                                showGenerateReport = true
                            } label: {
                                Label("Generate Report", systemImage: "doc.text")
                            }
                            
                            Divider()
                            
                            if let caseItem = conflictCase, caseItem.status != .closed {
                                Button {
                                    Task {
                                        await manager.finalizeCase(caseItem)
                                    }
                                } label: {
                                    Label("Close Case", systemImage: "checkmark.circle")
                                }
                            }
                            
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete Case", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                            .foregroundColor(textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showAddDocument) {
                if let caseItem = conflictCase {
                    DocumentUploadSheet(conflictCase: caseItem)
                }
            }
            .sheet(isPresented: $showEditEmployeeSheet) {
                if let employee = selectedEmployeeForEdit, let caseItem = conflictCase {
                    EmployeeEditSheet(
                        employee: employee,
                        caseId: caseItem.id,
                        onSave: { updatedEmployee in
                            updateEmployee(updatedEmployee, in: caseItem)
                        }
                    )
                }
            }
            .sheet(isPresented: $showAddEmployeeSheet) {
                if let caseItem = conflictCase {
                    AddEmployeeSheet(
                        caseId: caseItem.id,
                        onAdd: { newEmployee in
                            addEmployee(newEmployee, to: caseItem)
                        }
                    )
                }
            }
            .alert("Delete Case", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let caseItem = conflictCase {
                        Task {
                            await manager.deleteCase(caseItem)
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete this case? This action cannot be undone.")
            }
            .alert("Analysis Error", isPresented: $showAnalysisErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(analysisError ?? "An unknown error occurred while analyzing the case.")
            }
            .sheet(isPresented: $showFullAnalysisView) {
                if let caseItem = conflictCase, let comparison = caseItem.comparisonResult {
                    NavigationStack {
                        CaseAnalysisView(analysisResult: comparison)
                            .navigationTitle("System Analysis")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Done") {
                                        showFullAnalysisView = false
                                    }
                                }
                            }
                    }
                }
            }
            .fullScreenCover(isPresented: $showWitnessStatementScanner) {
                if let caseItem = conflictCase, let witness = selectedWitnessForStatement {
                    DocumentScannerEntryView(
                        conflictCase: caseItem,
                        documentType: .witnessStatement,
                        preselectedEmployee: witness
                    )
                }
            }
            .onAppear {
                // Restore generated document from case if available
                if let caseItem = conflictCase, let savedDoc = caseItem.generatedDocument {
                    restoreGeneratedDocument(from: caseItem, savedDoc: savedDoc)
                }
            }
        }
    }
    
    // MARK: - Restore Generated Document
    private func restoreGeneratedDocument(from caseItem: ConflictCase, savedDoc: GeneratedActionDocument) {
        // Restore selected recommendation if available
        if let action = caseItem.selectedAction {
            selectedRecommendation = RecommendationOption(
                id: "restored",
                type: {
                    switch action {
                    case .coaching: return .coaching
                    case .counseling: return .counseling
                    case .writtenWarning: return .warning
                    case .escalateToHR: return .escalate
                    }
                }(),
                title: action.displayName,
                description: action.description,
                rationale: "Restored from saved case",
                riskLevel: {
                    switch action.riskLevel {
                    case "Low": return .low
                    case "Medium": return .moderate
                    case "High": return .high
                    default: return .moderate
                    }
                }(),
                riskExplanation: "",
                nextSteps: [],
                timeframe: "",
                confidence: 0.8
            )
        }
        
        // We can't fully restore GeneratedDocumentResult from GeneratedActionDocument
        // as it loses the detailed document structure. The user will need to regenerate
        // for full preview, but the data is preserved in the database.
    }
    
    // MARK: - Case Header Section
    private func caseHeaderSection(_ caseItem: ConflictCase) -> some View {
        VStack(spacing: 16) {
            // Case Type Icon
            ZStack {
                Circle()
                    .fill(caseItem.type.color.opacity(0.15))
                    .frame(width: 64, height: 64)
                
                Image(systemName: caseItem.type.icon)
                    .font(.system(size: 28))
                    .foregroundColor(caseItem.type.color)
            }
            
            // Case Number & Title
            VStack(spacing: 6) {
                Text(caseItem.caseNumber)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(cardBackground)
                    .clipShape(Capsule())
                
                Text(caseItem.type.displayName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(textPrimary)
            }
            
            // Meta Info
            HStack(spacing: 16) {
                metaItem(icon: "calendar", value: caseItem.incidentDate.formatted(date: .abbreviated, time: .omitted))
                metaItem(icon: "mappin", value: caseItem.location)
                metaItem(icon: "building.2", value: caseItem.department)
            }
            
            // Status Badge
            HStack(spacing: 8) {
                Image(systemName: caseItem.status.icon)
                    .font(.system(size: 12))
                Text(caseItem.status.displayName)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(caseItem.status.color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(caseItem.status.color.opacity(0.15))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardBorder, lineWidth: 1)
        )
    }
    
    private func metaItem(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(textTertiary)
            Text(value)
                .font(.system(size: 12))
                .foregroundColor(textSecondary)
        }
    }
    
    // MARK: - Status Progress Section
    private func statusProgressSection(_ caseItem: ConflictCase) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CASE PROGRESS")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(textTertiary)
            
            HStack(spacing: 2) {
                ForEach(CaseStatus.allCases, id: \.self) { status in
                    if status != CaseStatus.allCases.first {
                        Rectangle()
                            .fill(statusLineColor(for: status, current: caseItem.status))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                    
                    VStack(spacing: 4) {
                        Circle()
                            .fill(statusDotColor(for: status, current: caseItem.status))
                            .frame(width: 10, height: 10)
                        
                        Text(shortStatusName(status))
                            .font(.system(size: 8))
                            .foregroundColor(status == caseItem.status ? status.color : textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(minWidth: 0)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private func shortStatusName(_ status: CaseStatus) -> String {
        switch status {
        case .draft: return "Draft"
        case .inProgress: return "Progress"
        case .pendingReview: return "Review"
        case .awaitingAction: return "Action"
        case .closed: return "Closed"
        case .escalated: return "Escal."
        }
    }
    
    private func statusDotColor(for status: CaseStatus, current: CaseStatus) -> Color {
        let statusOrder = CaseStatus.allCases
        guard let statusIndex = statusOrder.firstIndex(of: status),
              let currentIndex = statusOrder.firstIndex(of: current) else {
            return textTertiary
        }
        
        if statusIndex <= currentIndex {
            return status.color
        }
        return textTertiary.opacity(0.3)
    }
    
    private func statusLineColor(for status: CaseStatus, current: CaseStatus) -> Color {
        let statusOrder = CaseStatus.allCases
        guard let statusIndex = statusOrder.firstIndex(of: status),
              let currentIndex = statusOrder.firstIndex(of: current) else {
            return textTertiary.opacity(0.3)
        }
        
        if statusIndex <= currentIndex {
            return AppColors.success
        }
        return textTertiary.opacity(0.3)
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 2) {
            ForEach(["Overview", "Documents", "Analysis", "Timeline"], id: \.self) { tab in
                let index = ["Overview", "Documents", "Analysis", "Timeline"].firstIndex(of: tab) ?? 0
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
                } label: {
                    Text(tab)
                        .font(.system(size: 12, weight: selectedTab == index ? .semibold : .medium))
                        .foregroundColor(selectedTab == index ? .white : textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(selectedTab == index ? AppColors.primary : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - Tab Content
    @ViewBuilder
    private func tabContent(_ caseItem: ConflictCase) -> some View {
        switch selectedTab {
        case 0:
            overviewTab(caseItem)
        case 1:
            documentsTab(caseItem)
        case 2:
            analysisTab(caseItem)
        case 3:
            timelineTab(caseItem)
        default:
            EmptyView()
        }
    }
    
    // MARK: - Overview Tab
    private func overviewTab(_ caseItem: ConflictCase) -> some View {
        VStack(spacing: 20) {
            // Involved Employees
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("INVOLVED PARTIES")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textTertiary)
                    
                    Spacer()
                    
                    Button {
                        showAddEmployeeSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                            Text("Add")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(AppColors.primary)
                    }
                }
                
                if caseItem.involvedEmployees.isEmpty {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 36))
                            .foregroundColor(textTertiary)
                        
                        Text("No Involved Parties")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(textSecondary)
                        
                        Text("Add complainants and witnesses to this case")
                            .font(.system(size: 13))
                            .foregroundColor(textTertiary)
                            .multilineTextAlignment(.center)
                        
                        Button {
                            showAddEmployeeSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "person.badge.plus")
                                Text("Add Person")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(AppColors.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                } else {
                    // Complainants
                    let complainants = caseItem.involvedEmployees.filter { $0.isComplainant }
                    if !complainants.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Complainants")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppColors.warning)
                            
                            ForEach(complainants) { employee in
                                CaseEmployeeCard(
                                    employee: employee,
                                    colorScheme: colorScheme,
                                    onTap: {
                                        selectedEmployeeForEdit = employee
                                        showEditEmployeeSheet = true
                                    },
                                    onDelete: {
                                        deleteEmployee(employee, from: caseItem)
                                    }
                                )
                            }
                        }
                    }
                    
                    // Witnesses
                    let witnesses = caseItem.witnesses
                    if !witnesses.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Witnesses")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppColors.info)
                            
                            ForEach(witnesses) { employee in
                                CaseEmployeeCard(
                                    employee: employee,
                                    colorScheme: colorScheme,
                                    onTap: {
                                        selectedEmployeeForEdit = employee
                                        showEditEmployeeSheet = true
                                    },
                                    onDelete: {
                                        deleteEmployee(employee, from: caseItem)
                                    }
                                )
                            }
                        }
                    }
                }
            }
            
            // AI Recommendation (if available)
            if let recommendation = caseItem.recommendations.first {
                aiRecommendationCard(recommendation)
            }
            
            // Quick Stats
            quickStatsSection(caseItem)
            
            // Workflow Progress Card
            workflowProgressCard(caseItem)
        }
    }
    
    // MARK: - Workflow Progress Card
    private func workflowProgressCard(_ caseItem: ConflictCase) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.primary)
                
                Text("Next Steps")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Spacer()
            }
            
            switch caseItem.status {
            case .draft, .inProgress:
                // Need analysis
                if caseItem.documents.count < 2 {
                    nextStepRow(
                        icon: "doc.text.fill",
                        title: "Add Complaint Documents",
                        description: "Scan at least 2 complaint documents to enable AI analysis",
                        action: { showAddDocument = true }
                    )
                } else if caseItem.comparisonResult == nil {
                    nextStepRow(
                        icon: "brain",
                        title: "Run AI Analysis",
                        description: "Go to Analysis tab to compare statements",
                        action: { selectedTab = 2 }
                    )
                } else {
                    nextStepRow(
                        icon: "checkmark.circle.fill",
                        title: "Continue to Decision",
                        description: "Review analysis and select recommended action",
                        action: { selectedTab = 2 }
                    )
                }
                
            case .pendingReview:
                // Need to select action in Analysis tab
                nextStepRow(
                    icon: "hand.point.right.fill",
                    title: "Select Action",
                    description: "Go to Analysis tab and choose a recommendation to proceed",
                    action: { selectedTab = 2 }
                )
                
            case .awaitingAction:
                // Document generated, need review or finalization
                if let _ = generatedDocument {
                    nextStepRow(
                        icon: "doc.text.magnifyingglass",
                        title: "Review & Approve Document",
                        description: "Complete supervisor review before finalization",
                        action: {
                            if let doc = generatedDocument, let rec = selectedRecommendation, let comparison = caseItem.comparisonResult {
                                showSupervisorReview = true
                            }
                        }
                    )
                } else {
                    nextStepRow(
                        icon: "doc.badge.gearshape.fill",
                        title: "Generate Document",
                        description: "Go to Analysis tab to generate action document",
                        action: { selectedTab = 2 }
                    )
                }
                
            case .closed:
                completedStatusRow()
                
            case .escalated:
                escalatedStatusRow()
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private func nextStepRow(icon: String, title: String, description: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textTertiary)
            }
        }
    }
    
    private func completedStatusRow() -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Case Closed")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Text("This case has been finalized and locked")
                    .font(.system(size: 12))
                    .foregroundColor(textSecondary)
            }
            
            Spacer()
        }
    }
    
    private func escalatedStatusRow() -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Escalated to HR")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Text("This case has been sent to HR for review")
                    .font(.system(size: 12))
                    .foregroundColor(textSecondary)
            }
            
            Spacer()
        }
    }
    
    private func aiRecommendationCard(_ recommendation: AIRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "brain")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.primary)
                
                Text("System Recommendation")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Spacer()
                
                Text("\(Int(recommendation.confidence * 100))% confidence")
                    .font(.system(size: 12))
                    .foregroundColor(textSecondary)
            }
            
            Text(recommendation.action.displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(recommendation.action.color)
            
            Text(recommendation.reasoning)
                .font(.system(size: 13))
                .foregroundColor(textSecondary)
                .lineLimit(3)
        }
        .padding(16)
        .background(AppColors.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private func quickStatsSection(_ caseItem: ConflictCase) -> some View {
        HStack(spacing: 12) {
            CaseQuickStatCard(
                icon: "doc.text",
                value: "\(caseItem.documents.count)",
                label: "Documents",
                color: AppColors.info,
                colorScheme: colorScheme
            )
            
            CaseQuickStatCard(
                icon: "person.2",
                value: "\(caseItem.involvedEmployees.count)",
                label: "People",
                color: AppColors.warning,
                colorScheme: colorScheme
            )
            
            CaseQuickStatCard(
                icon: "clock",
                value: "\(daysSinceCreation(caseItem))d",
                label: "Open",
                color: AppColors.success,
                colorScheme: colorScheme
            )
        }
    }
    
    private func daysSinceCreation(_ caseItem: ConflictCase) -> Int {
        Calendar.current.dateComponents([.day], from: caseItem.createdAt, to: Date()).day ?? 0
    }
    
    // MARK: - Documents Tab
    private func documentsTab(_ caseItem: ConflictCase) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("CASE DOCUMENTS")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(textTertiary)
                
                Spacer()
                
                Button {
                    showAddDocument = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Add")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            
            if caseItem.documents.isEmpty {
                emptyDocumentsState
            } else {
                ForEach(caseItem.documents) { document in
                    CaseDocumentCard(
                        document: document,
                        isExpanded: expandedDocuments.contains(document.id),
                        colorScheme: colorScheme,
                        onToggle: {
                            if expandedDocuments.contains(document.id) {
                                expandedDocuments.remove(document.id)
                            } else {
                                expandedDocuments.insert(document.id)
                            }
                        },
                        onDelete: {
                            Task {
                                await manager.deleteDocument(from: caseItem.id, documentId: document.id)
                            }
                        }
                    )
                }
            }
        }
    }
    
    private var emptyDocumentsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(textTertiary)
            
            Text("No Documents Yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Text("Upload complaint statements and witness accounts to enable System analysis")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                showAddDocument = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                    Text("Add Document")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(AppColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - Analysis Tab
    private func analysisTab(_ caseItem: ConflictCase) -> some View {
        ZStack {
            VStack(alignment: .leading, spacing: 16) {
                if let comparison = caseItem.comparisonResult {
                    // Show analysis summary with button to view full analysis
                    analysisReadyView(comparison)
                    
                    // Phase 5: Evidence Expansion
                    EvidenceExpansionView(
                        conflictCase: caseItem,
                        onAddWitness: {
                            showAddEmployeeSheet = true
                        },
                        onScanWitnessStatement: { witness in
                            selectedWitnessForStatement = witness
                            showWitnessStatementScanner = true
                        },
                        onAddPriorHistory: {
                            showAddDocument = true
                        },
                        onReAnalyze: {
                            runAIAnalysis(for: caseItem)
                        },
                        onSkip: {
                            // Continue to policy alignment
                        }
                    )
                    
                    // Phase 6: Policy Alignment
                    PolicyAlignmentView(
                        conflictCase: caseItem,
                        policy: manager.activePolicy,
                        analysisResult: comparison,
                        autoRun: $shouldAutoRunPolicyMatch,
                        onPolicyMatched: { results in
                            policyMatchResults = results
                            // Auto-trigger decision support after policy matching completes
                            shouldAutoRunDecisionSupport = true
                        },
                        onRunPolicyMatch: {
                            // Policy matching is handled internally by the view
                        },
                        onSkip: {
                            // Continue to decision support
                        }
                    )
                    .id("policy-\(reanalysisVersion)")
                    
                    // Phase 7: Decision Support
                    DecisionSupportView(
                        conflictCase: caseItem,
                        analysisResult: comparison,
                        policyMatches: policyMatchResults.isEmpty ? nil : policyMatchResults,
                        autoRun: $shouldAutoRunDecisionSupport,
                        onSelectRecommendation: { recommendation in
                            selectedRecommendation = recommendation
                            // Update status to awaiting action when recommendation is selected
                            Task {
                                await manager.updateCaseStatus(caseItem.id, to: .awaitingAction)
                            }
                            // Move to action generation phase
                            showActionGeneration = true
                        },
                        onSkip: {
                            selectedTab = 3 // Timeline tab
                        }
                    )
                    .id("decision-\(reanalysisVersion)")
                    
                    // Phase 8: Action Generation (shown after recommendation selected)
                    if let recommendation = selectedRecommendation {
                        actionGenerationSection(caseItem: caseItem, comparison: comparison, recommendation: recommendation)
                    }
                } else {
                    pendingAnalysisView(caseItem)
                }
            }
            .frame(maxWidth: .infinity)
            .opacity(isAnalyzing && caseItem.comparisonResult != nil ? 0.5 : 1.0)
            .disabled(isAnalyzing)
            
            // Re-Analysis Loading Overlay
            if isAnalyzing && caseItem.comparisonResult != nil {
                ReanalysisLoadingOverlay()
            }
        }
    }
    
    // MARK: - Phase 8: Action Generation Section
    private func actionGenerationSection(caseItem: ConflictCase, comparison: AIComparisonResult, recommendation: RecommendationOption) -> some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(recommendation.type.color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 22))
                        .foregroundColor(recommendation.type.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Phase 8: Action Generation")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    Text("Generate \(recommendation.type.displayName.lowercased()) document")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                }
                
                Spacer()
            }
            
            // Selected Action Display
            VStack(alignment: .leading, spacing: 8) {
                Text("Selected Action")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textTertiary)
                
                HStack(spacing: 8) {
                    Image(systemName: recommendation.type.icon)
                        .foregroundColor(recommendation.type.color)
                    
                    Text(recommendation.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textPrimary)
                    
                    Spacer()
                    
                    Button {
                        selectedRecommendation = nil
                        generatedDocument = nil
                    } label: {
                        Text("Change")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding()
            .background(recommendation.type.color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Status based on generated document
            if let document = generatedDocument {
                // Document generated - show success state
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Document Generated")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(textPrimary)
                    }
                    
                    Button {
                        showActionGeneration = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("View Full Document")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(recommendation.type.color)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    Button {
                        // Continue to Phase 9: Supervisor Review
                        showSupervisorReview = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Continue to Review")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(recommendation.type.color)
                    }
                }
            } else {
                // No document yet - show generate button
                Button {
                    showActionGeneration = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Generate Document")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(recommendation.type.color)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showActionGeneration) {
            NavigationView {
                ActionGenerationView(
                    conflictCase: caseItem,
                    selectedRecommendation: recommendation,
                    analysisResult: comparison,
                    policyMatches: policyMatchResults.isEmpty ? nil : policyMatchResults,
                    onDocumentGenerated: { result in
                        generatedDocument = result
                        showActionGeneration = false
                        
                        // Save generated document to case for database persistence
                        var updatedCase = caseItem
                        updatedCase.generatedDocument = result.toGeneratedActionDocument()
                        updatedCase.selectedAction = {
                            switch result.actionType {
                            case .coaching: return .coaching
                            case .counseling: return .counseling
                            case .warning: return .writtenWarning
                            case .escalate: return .escalateToHR
                            }
                        }()
                        manager.updateCaseSync(updatedCase)
                    },
                    onBack: {
                        showActionGeneration = false
                    }
                )
            }
        }
        .sheet(isPresented: $showSupervisorReview) {
            if let document = generatedDocument {
                SupervisorReviewView(
                    conflictCase: caseItem,
                    generatedResult: document,
                    onApprove: { updatedResult, edits in
                        // Handle approval - update case status and proceed to finalization
                        generatedDocument = updatedResult
                        showSupervisorReview = false
                        
                        // Update case with approved document
                        var updatedCase = caseItem
                        var approvedDoc = updatedResult.toGeneratedActionDocument()
                        approvedDoc.isApproved = true
                        approvedDoc.approvedAt = Date()
                        updatedCase.generatedDocument = approvedDoc
                        
                        Task {
                            await manager.updateCase(updatedCase)
                            await manager.updateCaseStatus(caseItem.id, to: .awaitingAction)
                        }
                        showFinalization = true
                    },
                    onRequestChanges: { comments in
                        // Handle request changes - keep in review state
                        showSupervisorReview = false
                    },
                    onReject: { reason in
                        // Handle rejection - reset document and clear from case
                        generatedDocument = nil
                        selectedRecommendation = nil
                        showSupervisorReview = false
                        
                        var updatedCase = caseItem
                        updatedCase.generatedDocument = nil
                        updatedCase.selectedAction = nil
                        manager.updateCaseSync(updatedCase)
                    },
                    onBack: {
                        showSupervisorReview = false
                    }
                )
            }
        }
        .sheet(isPresented: $showFinalization) {
            CaseFinalizationView(
                conflictCase: caseItem,
                generatedDocument: generatedDocument,
                onFinalize: {
                    // Finalize and close the case
                    Task {
                        await manager.finalizeCase(caseItem)
                    }
                    showFinalization = false
                },
                onSendToHR: {
                    // Update status to escalated and close
                    Task {
                        await manager.updateCaseStatus(caseItem.id, to: .escalated)
                    }
                    showFinalization = false
                },
                onExport: {
                    // Export handled in view, just close
                    showFinalization = false
                },
                onBack: {
                    showFinalization = false
                }
            )
        }
    }
    
    private func analysisReadyView(_ comparison: AIComparisonResult) -> some View {
        VStack(spacing: 16) {
            // Summary Header
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.success)
                
                Text("Analysis Complete")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Text("Generated \(formattedDate(comparison.generatedAt))")
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
            }
            
            // Quick Stats
            HStack(spacing: 8) {
                quickStatBadge(count: comparison.agreementPoints.count, label: "Agreements", color: .green)
                quickStatBadge(count: comparison.contradictions.count, label: "Contradictions", color: .red)
                quickStatBadge(count: comparison.missingDetails.count, label: "Unclear", color: .orange)
            }
            .frame(maxWidth: .infinity)
            
            // View Full Analysis Button
            Button {
                showFullAnalysisView = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("View Full Analysis")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Summary Preview
            if !comparison.neutralSummary.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary Preview")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textTertiary)
                    
                    Text(comparison.neutralSummary)
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                        .lineLimit(4)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private func quickStatBadge(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func comparisonResultView(_ comparison: AIComparisonResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Agreement Points
            if !comparison.agreementPoints.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.success)
                        Text("Agreement Points")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(textPrimary)
                    }
                    
                    ForEach(comparison.agreementPoints, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(AppColors.success)
                            Text(item)
                                .font(.system(size: 13))
                                .foregroundColor(textSecondary)
                        }
                    }
                }
                .padding(14)
                .background(AppColors.success.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Contradictions
            if !comparison.contradictions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppColors.error)
                        Text("Contradictions Found")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(textPrimary)
                    }
                    
                    ForEach(comparison.contradictions, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(AppColors.error)
                            Text(item)
                                .font(.system(size: 13))
                                .foregroundColor(textSecondary)
                        }
                    }
                }
                .padding(14)
                .background(AppColors.error.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Neutral Summary
            if !comparison.neutralSummary.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Neutral Summary")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    Text(comparison.neutralSummary)
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                }
                .padding(14)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private func pendingAnalysisView(_ caseItem: ConflictCase) -> some View {
        VStack(spacing: 20) {
            if isAnalyzing {
                // Loading State
                AnalysisLoadingView()
            } else {
                Image(systemName: "cpu")
                    .font(.system(size: 44))
                    .foregroundColor(textTertiary)
                
                Text("Analysis Pending")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                let documentsNeeded = requiredDocumentsCount(caseItem)
                if documentsNeeded > 0 {
                    Text("Upload \(documentsNeeded) more document(s) to enable System comparison")
                        .font(.system(size: 14))
                        .foregroundColor(textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Button {
                        runAIAnalysis(for: caseItem)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("Run System Analysis")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(AppColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private func requiredDocumentsCount(_ caseItem: ConflictCase) -> Int {
        // Need at least 2 complaint documents for comparison
        let complaintDocs = caseItem.documents.filter { $0.type == .complaintA || $0.type == .complaintB }.count
        return max(0, 2 - complaintDocs)
    }
    
    // MARK: - Timeline Tab
    private func timelineTab(_ caseItem: ConflictCase) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AUDIT TRAIL")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(textTertiary)
            
            if caseItem.auditLog.isEmpty {
                emptyTimelineState
            } else {
                ForEach(caseItem.auditLog) { entry in
                    CaseTimelineEntryView(entry: entry, colorScheme: colorScheme)
                }
            }
        }
    }
    
    private var emptyTimelineState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32))
                .foregroundColor(textTertiary)
            
            Text("No activity recorded yet")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - Case Not Found View
    private var caseNotFoundView: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.folder")
                .font(.system(size: 48))
                .foregroundColor(textTertiary)
            
            Text("Case Not Found")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Text("The case you're looking for doesn't exist or has been deleted.")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                dismiss()
            } label: {
                Text("Go Back")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func updateEmployee(_ updatedEmployee: InvolvedEmployee, in caseItem: ConflictCase) {
        var updatedCase = caseItem
        if let index = updatedCase.involvedEmployees.firstIndex(where: { $0.id == updatedEmployee.id }) {
            updatedCase.involvedEmployees[index] = updatedEmployee
            manager.updateCaseSync(updatedCase)
        }
    }
    
    private func deleteEmployee(_ employee: InvolvedEmployee, from caseItem: ConflictCase) {
        var updatedCase = caseItem
        
        // Determine employee's role and delete associated documents
        if employee.isComplainant {
            // Check if this is complainantA (first) or complainantB (second)
            let complainants = caseItem.involvedEmployees.filter { $0.isComplainant }
            if let firstComplainant = complainants.first, firstComplainant.id == employee.id {
                // Deleting complainantA - remove Complaint A documents
                updatedCase.documents.removeAll { $0.type == .complaintA }
            } else {
                // Deleting complainantB - remove Complaint B documents
                updatedCase.documents.removeAll { $0.type == .complaintB }
            }
        } else {
            // Deleting a witness - remove their witness statements
            updatedCase.documents.removeAll { $0.type == .witnessStatement && $0.employeeId == employee.id }
        }
        
        // Remove the employee
        updatedCase.involvedEmployees.removeAll { $0.id == employee.id }
        manager.updateCaseSync(updatedCase)
    }
    
    private func addEmployee(_ employee: InvolvedEmployee, to caseItem: ConflictCase) {
        var updatedCase = caseItem
        updatedCase.involvedEmployees.append(employee)
        manager.updateCaseSync(updatedCase)
    }
    
    // MARK: - AI Analysis
    
    private func runAIAnalysis(for caseItem: ConflictCase) {
        // Get complaint documents
        guard let complaintADoc = caseItem.documents.first(where: { $0.type == .complaintA }),
              let complaintBDoc = caseItem.documents.first(where: { $0.type == .complaintB }) else {
            analysisError = "Both complaints must be uploaded to run analysis"
            showAnalysisErrorAlert = true
            return
        }
        
        // Verify both have extracted text
        guard !complaintADoc.cleanedText.isEmpty || !complaintADoc.originalText.isEmpty,
              !complaintBDoc.cleanedText.isEmpty || !complaintBDoc.originalText.isEmpty else {
            analysisError = "Both complaints must have extracted text to run analysis"
            showAnalysisErrorAlert = true
            return
        }
        
        // Get employee (complainants) for the complaints
        let complainants = caseItem.involvedEmployees.filter { $0.isComplainant }
        guard complainants.count >= 2 else {
            analysisError = "Two complainants are required for analysis"
            showAnalysisErrorAlert = true
            return
        }
        
        let complainantA = complainants[0]
        let complainantB = complainants[1]
        
        // Get witness statements
        let witnessStatements: [WitnessStatementInput] = caseItem.documents
            .filter { $0.type == .witnessStatement && (!$0.cleanedText.isEmpty || !$0.originalText.isEmpty) }
            .compactMap { doc in
                if let employeeId = doc.employeeId,
                   let witness = caseItem.involvedEmployees.first(where: { $0.id == employeeId }) {
                    let text = doc.cleanedText.isEmpty ? doc.originalText : doc.cleanedText
                    return WitnessStatementInput(witnessName: witness.name, text: text)
                }
                return nil
            }
        
        // Get prior history documents
        let priorHistoryDocs: [PriorHistoryInput] = caseItem.documents
            .filter { $0.type == .priorRecord || $0.type == .counselingRecord || $0.type == .warningDocument }
            .compactMap { doc in
                let text = doc.cleanedText.isEmpty ? (doc.translatedText ?? doc.originalText) : doc.cleanedText
                guard !text.isEmpty else { return nil }
                
                let typeString: String
                switch doc.type {
                case .priorRecord:
                    typeString = "prior_complaint"
                case .counselingRecord:
                    typeString = "counseling_record"
                case .warningDocument:
                    typeString = "warning_document"
                default:
                    typeString = "other"
                }
                
                return PriorHistoryInput(
                    type: typeString,
                    documentDate: doc.createdAt.formatted(date: .abbreviated, time: .omitted),
                    summary: text,
                    employeeName: doc.submittedBy
                )
            }
        
        // Build case details
        let caseDetails = CaseComparisonDetails(
            incidentDate: caseItem.incidentDate.formatted(date: .abbreviated, time: .omitted),
            location: caseItem.location,
            department: caseItem.department
        )
        
        isAnalyzing = true
        // Reset downstream views for re-analysis
        policyMatchResults = []
        selectedRecommendation = nil
        reanalysisVersion += 1
        
        Task {
            do {
                let result = try await ConflictAnalysisService.shared.compareComplaints(
                    complaintA: complaintADoc,
                    complaintAEmployee: complainantA,
                    complaintB: complaintBDoc,
                    complaintBEmployee: complainantB,
                    caseDetails: caseDetails,
                    witnessStatements: witnessStatements,
                    priorHistory: priorHistoryDocs
                )
                
                await MainActor.run {
                    var updatedCase = caseItem
                    updatedCase.comparisonResult = result
                    updatedCase.status = .pendingReview
                    // Clear old policy matches from case too
                    updatedCase.policyMatches = []
                    manager.updateCaseSync(updatedCase)
                    isAnalyzing = false
                    
                    // Set flags to auto-run downstream analyses
                    shouldAutoRunPolicyMatch = true
                    shouldAutoRunDecisionSupport = true
                    
                    // After analysis completes, automatically show the results
                    showFullAnalysisView = true
                }
            } catch let error as ConflictAnalysisError {
                await MainActor.run {
                    isAnalyzing = false
                    analysisError = error.localizedDescription
                    showAnalysisErrorAlert = true
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                    analysisError = error.localizedDescription
                    showAnalysisErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Add Employee Sheet

struct AddEmployeeSheet: View {
    let caseId: UUID
    let onAdd: (InvolvedEmployee) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var departmentService = DepartmentService.shared
    
    @State private var name = ""
    @State private var role = ""
    @State private var department = ""
    @State private var employeeId = ""
    @State private var isComplainant = true
    
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
    
    private var inputBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !employeeId.trimmingCharacters(in: .whitespaces).isEmpty &&
        !role.trimmingCharacters(in: .whitespaces).isEmpty &&
        !department.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Avatar Preview
                        ZStack {
                            Circle()
                                .fill(isComplainant ? AppColors.warning.opacity(0.15) : AppColors.info.opacity(0.15))
                                .frame(width: 80, height: 80)
                            
                            if name.isEmpty {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(isComplainant ? AppColors.warning : AppColors.info)
                            } else {
                                Text(name.prefix(1).uppercased())
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundColor(isComplainant ? AppColors.warning : AppColors.info)
                            }
                        }
                        
                        // Role Type Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ROLE TYPE")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(textSecondary)
                            
                            HStack(spacing: 12) {
                                roleTypeButton(title: "Complainant", isSelected: isComplainant) {
                                    isComplainant = true
                                }
                                
                                roleTypeButton(title: "Witness", isSelected: !isComplainant) {
                                    isComplainant = false
                                }
                            }
                        }
                        
                        // Form Fields
                        VStack(spacing: 16) {
                            // Name (Required)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 4) {
                                    Text("NAME")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(textSecondary)
                                    Text("*")
                                        .foregroundColor(.red)
                                }
                                
                                TextField("Full name", text: $name)
                                    .font(.system(size: 16))
                                    .foregroundColor(textPrimary)
                                    .padding(12)
                                    .background(inputBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            
                            // Employee ID / File Number (Required)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 4) {
                                    Text("EMPLOYEE ID / FILE NUMBER")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(textSecondary)
                                    Text("*")
                                        .foregroundColor(.red)
                                }
                                
                                TextField("e.g., EMP-12345", text: $employeeId)
                                    .font(.system(size: 16))
                                    .foregroundColor(textPrimary)
                                    .padding(12)
                                    .background(inputBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            
                            // Role/Position and Department side by side
                            HStack(spacing: 12) {
                                // Role/Position (Required)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 4) {
                                        Text("ROLE/POSITION")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(textSecondary)
                                        Text("*")
                                            .foregroundColor(.red)
                                    }
                                    
                                    TextField("e.g., Manager", text: $role)
                                        .font(.system(size: 16))
                                        .foregroundColor(textPrimary)
                                        .padding(12)
                                        .background(inputBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                
                                // Department (Required - Dropdown)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 4) {
                                        Text("DEPARTMENT")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(textSecondary)
                                        Text("*")
                                            .foregroundColor(.red)
                                    }
                                    
                                    if departmentService.isLoading {
                                        HStack {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                            Text("Loading...")
                                                .font(.system(size: 14))
                                                .foregroundColor(textTertiary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(inputBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    } else {
                                        Menu {
                                            ForEach(departmentService.departments) { dept in
                                                Button(dept.name) {
                                                    department = dept.name
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Text(department.isEmpty ? "Select" : department)
                                                    .font(.system(size: 16))
                                                    .foregroundColor(department.isEmpty ? textTertiary : textPrimary)
                                                Spacer()
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(textTertiary)
                                            }
                                            .padding(12)
                                            .background(inputBackground)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let newEmployee = InvolvedEmployee(
                            name: name,
                            role: role,
                            department: department,
                            employeeId: employeeId,
                            isComplainant: isComplainant
                        )
                        onAdd(newEmployee)
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isFormValid ? AppColors.primary : AppColors.primary.opacity(0.5))
                    .disabled(!isFormValid)
                }
            }
            .onAppear {
                Task {
                    await departmentService.fetchDepartments()
                }
            }
        }
    }
    
    private func roleTypeButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? (title == "Complainant" ? AppColors.warning : AppColors.info) : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    private func formField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(textSecondary)
            
            TextField(placeholder, text: text)
                .font(.system(size: 16))
                .foregroundColor(textPrimary)
                .padding(12)
                .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Employee Edit Sheet

struct EmployeeEditSheet: View {
    let employee: InvolvedEmployee
    let caseId: UUID
    let onSave: (InvolvedEmployee) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var departmentService = DepartmentService.shared
    
    @State private var name: String
    @State private var role: String
    @State private var department: String
    @State private var employeeId: String
    
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
    
    private var inputBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !employeeId.trimmingCharacters(in: .whitespaces).isEmpty &&
        !role.trimmingCharacters(in: .whitespaces).isEmpty &&
        !department.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    init(employee: InvolvedEmployee, caseId: UUID, onSave: @escaping (InvolvedEmployee) -> Void) {
        self.employee = employee
        self.caseId = caseId
        self.onSave = onSave
        _name = State(initialValue: employee.name)
        _role = State(initialValue: employee.role)
        _department = State(initialValue: employee.department)
        _employeeId = State(initialValue: employee.employeeId ?? "")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(employee.isComplainant ? AppColors.warning.opacity(0.15) : AppColors.info.opacity(0.15))
                                .frame(width: 80, height: 80)
                            
                            Text(name.prefix(1).uppercased())
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(employee.isComplainant ? AppColors.warning : AppColors.info)
                        }
                        
                        // Role Badge
                        Text(employee.isComplainant ? "Complainant" : "Witness")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(employee.isComplainant ? AppColors.warning : AppColors.info)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background((employee.isComplainant ? AppColors.warning : AppColors.info).opacity(0.15))
                            .clipShape(Capsule())
                        
                        // Form Fields
                        VStack(spacing: 16) {
                            // Name (Required) - First
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 4) {
                                    Text("NAME")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(textSecondary)
                                    Text("*")
                                        .foregroundColor(.red)
                                }
                                
                                TextField("Full name", text: $name)
                                    .font(.system(size: 16))
                                    .foregroundColor(textPrimary)
                                    .padding(12)
                                    .background(inputBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            
                            // Employee ID / File Number (Required)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 4) {
                                    Text("EMPLOYEE ID / FILE NUMBER")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(textSecondary)
                                    Text("*")
                                        .foregroundColor(.red)
                                }
                                
                                TextField("e.g., EMP-12345", text: $employeeId)
                                    .font(.system(size: 16))
                                    .foregroundColor(textPrimary)
                                    .padding(12)
                                    .background(inputBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            
                            // Role/Position and Department side by side
                            HStack(spacing: 12) {
                                // Role/Position (Required)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 4) {
                                        Text("ROLE/POSITION")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(textSecondary)
                                        Text("*")
                                            .foregroundColor(.red)
                                    }
                                    
                                    TextField("e.g., Manager", text: $role)
                                        .font(.system(size: 16))
                                        .foregroundColor(textPrimary)
                                        .padding(12)
                                        .background(inputBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                
                                // Department (Required - Dropdown)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 4) {
                                        Text("DEPARTMENT")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(textSecondary)
                                        Text("*")
                                            .foregroundColor(.red)
                                    }
                                    
                                    if departmentService.isLoading {
                                        HStack {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                            Text("Loading...")
                                                .font(.system(size: 14))
                                                .foregroundColor(textTertiary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(inputBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    } else {
                                        Menu {
                                            ForEach(departmentService.departments) { dept in
                                                Button(dept.name) {
                                                    department = dept.name
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Text(department.isEmpty ? "Select" : department)
                                                    .font(.system(size: 16))
                                                    .foregroundColor(department.isEmpty ? textTertiary : textPrimary)
                                                Spacer()
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(textTertiary)
                                            }
                                            .padding(12)
                                            .background(inputBackground)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let updatedEmployee = InvolvedEmployee(
                            id: employee.id,
                            name: name,
                            role: role,
                            department: department,
                            employeeId: employeeId,
                            isComplainant: employee.isComplainant
                        )
                        onSave(updatedEmployee)
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isFormValid ? AppColors.primary : AppColors.primary.opacity(0.5))
                    .disabled(!isFormValid)
                }
            }
            .onAppear {
                Task {
                    await departmentService.fetchDepartments()
                }
            }
        }
    }
    
    private func editFormField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(textSecondary)
            
            TextField(placeholder, text: text)
                .font(.system(size: 16))
                .foregroundColor(textPrimary)
                .padding(12)
                .background(inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Supporting Views

struct CaseEmployeeCard: View {
    let employee: InvolvedEmployee
    let colorScheme: ColorScheme
    var onTap: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    
    @State private var showDeleteConfirmation = false
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
    }
    
    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(employee.isComplainant ? AppColors.warning.opacity(0.15) : AppColors.info.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Text(employee.name.prefix(1).uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(employee.isComplainant ? AppColors.warning : AppColors.info)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(employee.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textPrimary)
                    
                    if !employee.role.isEmpty {
                        Text("\(employee.role) • \(employee.department)")
                            .font(.system(size: 12))
                            .foregroundColor(textSecondary)
                    }
                }
                
                Spacer()
                
                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textSecondary)
                }
            }
            .padding(10)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if onDelete != nil {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete \(employee.isComplainant ? "Complainant" : "Witness")", systemImage: "trash")
                }
            }
        }
        .alert("Delete \(employee.isComplainant ? "Complainant" : "Witness")", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Are you sure you want to remove \(employee.name) from this case?")
        }
    }
}

struct CaseQuickStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    let colorScheme: ColorScheme
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(textPrimary)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CaseDocumentCard: View {
    let document: CaseDocument
    let isExpanded: Bool
    let colorScheme: ColorScheme
    let onToggle: () -> Void
    var onDelete: (() -> Void)? = nil
    
    @State private var showDocumentReview = false
    @State private var showDeleteConfirmation = false
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    private var hasTranslation: Bool {
        if let translated = document.translatedText, !translated.isEmpty,
           document.detectedLanguage?.lowercased() != "english" {
            return true
        }
        return false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Image(systemName: document.type.icon)
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.primary)
                        .frame(width: 40, height: 40)
                        .background(AppColors.primary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(document.type.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(textPrimary)
                        
                        HStack(spacing: 8) {
                            Text(document.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12))
                                .foregroundColor(textSecondary)
                            
                            if let language = document.detectedLanguage, language.lowercased() != "english" {
                                Text("• \(language)")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textSecondary)
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Divider()
                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                
                VStack(alignment: .leading, spacing: 16) {
                    // Document Text Preview
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("DOCUMENT TEXT")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(textSecondary)
                            
                            Spacer()
                            
                            Button("Show More") {
                                showDocumentReview = true
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppColors.primary)
                            .buttonStyle(.borderless)
                        }
                        
                        Text(String(document.cleanedText.prefix(200)) + (document.cleanedText.count > 200 ? "..." : ""))
                            .font(.system(size: 13))
                            .foregroundColor(textSecondary)
                            .lineLimit(4)
                    }
                    
                    // Delete Button
                    if onDelete != nil {
                        Divider()
                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                Text("Delete Document")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                        .padding(.top, 4)
                    }
                }
                .padding(14)
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .sheet(isPresented: $showDocumentReview) {
            DocumentReviewSheet(document: document)
        }
        .alert("Delete Document", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Are you sure you want to delete this \(document.type.displayName)? This action cannot be undone.")
        }
    }
}

// MARK: - Document Review Sheet
struct DocumentReviewSheet: View {
    let document: CaseDocument
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedTab = 0
    
    // TTS State
    @State private var isReading = false
    @State private var isLoadingAudio = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var currentWordIndex = 0
    @State private var words: [String] = []
    @State private var highlightTimer: Timer?
    @State private var showTranslationOffer = false  // Popup to offer English translation
    @State private var isReadingTranslation = false  // Whether we're reading the translation
    @State private var introWordCount: Int = 0  // Words in intro speech (for delayed highlighting)
    @State private var introDelayTimer: Timer?  // Timer to delay highlighting until after intro
    
    private let ttsService = TextToSpeechService.shared
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var hasTranslation: Bool {
        if let translated = document.translatedText, !translated.isEmpty,
           document.detectedLanguage?.lowercased() != "english" {
            return true
        }
        return false
    }
    
    /// Check if document is in a non-English language
    private var isNonEnglishDocument: Bool {
        guard let language = document.detectedLanguage?.lowercased() else { return false }
        return !language.contains("english") && language != "en"
    }
    
    /// Get the language code for TTS based on detected language
    private var documentLanguageCode: String {
        guard let language = document.detectedLanguage?.lowercased() else { return "en-US" }
        
        // Map detected language names to language codes
        let languageMap: [String: String] = [
            "english": "en-US",
            "french": "fr-FR",
            "spanish": "es-ES",
            "german": "de-DE",
            "portuguese": "pt-BR",
            "chinese": "zh-CN",
            "japanese": "ja-JP",
            "korean": "ko-KR",
            "arabic": "ar-SA",
            "hindi": "hi-IN",
            "italian": "it-IT",
            "dutch": "nl-NL",
            "polish": "pl-PL",
            "russian": "ru-RU",
            "turkish": "tr-TR",
            "thai": "th-TH",
            "vietnamese": "vi-VN",
            "indonesian": "id-ID",
            "malay": "ms-MY",
            "swedish": "sv-SE",
            "norwegian": "nb-NO",
            "danish": "da-DK",
            "finnish": "fi-FI",
            "hebrew": "he-IL",
            "greek": "el-GR",
            "czech": "cs-CZ",
            "hungarian": "hu-HU",
            "romanian": "ro-RO",
            "ukrainian": "uk-UA",
            "swahili": "sw-KE",
            "afrikaans": "af-ZA"
        ]
        
        // Find matching language
        for (key, code) in languageMap {
            if language.contains(key) {
                return code
            }
        }
        
        return "en-US"
    }
    
    private var hasImages: Bool {
        document.originalImageBase64 != nil || !document.originalImageURLs.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Tab Selector
                    HStack(spacing: 0) {
                        DocumentReviewTabButton(
                            title: "Original",
                            icon: "doc.text",
                            isSelected: selectedTab == 0,
                            action: { selectedTab = 0 }
                        )
                        
                        if hasTranslation {
                            DocumentReviewTabButton(
                                title: "Translated",
                                icon: "globe",
                                isSelected: selectedTab == 1,
                                action: { selectedTab = 1 }
                            )
                        }
                        
                        DocumentReviewTabButton(
                            title: "Cleaned",
                            icon: "sparkles",
                            isSelected: selectedTab == (hasTranslation ? 2 : 1),
                            action: { selectedTab = hasTranslation ? 2 : 1 }
                        )
                        
                        if hasImages {
                            DocumentReviewTabButton(
                                title: "Images",
                                icon: "photo.stack",
                                isSelected: selectedTab == (hasTranslation ? 3 : 2),
                                action: { selectedTab = hasTranslation ? 3 : 2 }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Content
                    TabView(selection: $selectedTab) {
                        // Original Text Tab
                        originalTextTab
                            .tag(0)
                        
                        if hasTranslation {
                            // Translated Text Tab
                            translatedTextTab
                                .tag(1)
                        }
                        
                        // Cleaned Text Tab
                        cleanedTextTab
                            .tag(hasTranslation ? 2 : 1)
                        
                        if hasImages {
                            // Images Tab
                            imagesTab
                                .tag(hasTranslation ? 3 : 2)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
                
                // Floating Read Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            if isReading {
                                stopReading()
                            } else {
                                startReading()
                            }
                        }) {
                            HStack(spacing: 8) {
                                if isLoadingAudio {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: isReading ? "stop.fill" : "speaker.wave.2.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                
                                Text(isReading ? "Stop" : "Read")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(isReading ? Color.red : Color.blue)
                                    .shadow(color: (isReading ? Color.red : Color.blue).opacity(0.4), radius: 8, x: 0, y: 4)
                            )
                        }
                        .disabled(isLoadingAudio)
                        .padding(.trailing, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Review Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(textSecondary)
                }
            }
            .alert("Listen to English Translation?", isPresented: $showTranslationOffer) {
                Button("Yes") {
                    readEnglishTranslation()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Would you like me to read the English translation of this document?")
            }
        }
    }
    
    private var originalTextTab: some View {
        let fullText = document.originalText.isEmpty ? document.cleanedText : document.originalText
        
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(textSecondary)
                    Text("Original (\(document.detectedLanguage ?? "Unknown"))")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                if isReading && selectedTab == 0 {
                    Text(highlightedText(for: fullText))
                        .font(.system(size: 15))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                } else {
                    Text(fullText)
                        .font(.system(size: 15))
                        .foregroundColor(textPrimary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    private var translatedTextTab: some View {
        let fullText = document.translatedText ?? "No translation available"
        
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(textSecondary)
                    Text("Translated (English)")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                if isReading && hasTranslation && selectedTab == 1 {
                    Text(highlightedText(for: fullText))
                        .font(.system(size: 15))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                } else {
                    Text(fullText)
                        .font(.system(size: 15))
                        .foregroundColor(textPrimary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    private var cleanedTextTab: some View {
        let cleanedTabIndex = hasTranslation ? 2 : 1
        
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(textSecondary)
                    Text("System Cleaned & Structured")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                if isReading && selectedTab == cleanedTabIndex {
                    Text(highlightedText(for: document.cleanedText))
                        .font(.system(size: 15))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                } else {
                    Text(document.cleanedText)
                        .font(.system(size: 15))
                        .foregroundColor(textPrimary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    private var imagesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "photo.stack")
                        .foregroundColor(textSecondary)
                    Text("Scanned Images")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                // Check for Firebase URLs first (from database)
                if !document.originalImageURLs.isEmpty {
                    ForEach(document.originalImageURLs, id: \.self) { urlString in
                        if let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(height: 200)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                case .failure:
                                    VStack {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundColor(.orange)
                                        Text("Failed to load image")
                                            .font(.caption)
                                            .foregroundColor(textSecondary)
                                    }
                                    .frame(height: 100)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                // Fallback to local base64 storage
                else if let base64 = document.originalImageBase64,
                   let imageData = Data(base64Encoded: base64),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                } else {
                    Text("No images available")
                        .font(.system(size: 14))
                        .foregroundColor(textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - TTS Methods
    
    private func startReading() {
        isLoadingAudio = true
        isReadingTranslation = false
        
        // Get the text to read based on selected tab
        let textToRead: String
        let languageCode: String
        
        if selectedTab == 0 {
            // Reading original text
            textToRead = document.originalText.isEmpty ? document.cleanedText : document.originalText
            languageCode = documentLanguageCode
        } else if hasTranslation && selectedTab == 1 {
            // Reading translated text (English)
            textToRead = document.translatedText ?? document.cleanedText
            languageCode = "en-US"
            isReadingTranslation = true
        } else {
            // Reading cleaned text (could be in any language)
            textToRead = document.cleanedText
            languageCode = documentLanguageCode
        }
        
        // Prepare words for highlighting
        words = textToRead.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        currentWordIndex = 0
        
        Task {
            do {
                // Second instance (after submission): Skip intro speech
                // Document has already been reviewed and acknowledged
                let result = try await ttsService.generateSpeech(
                    text: textToRead,
                    employeeName: document.submittedBy ?? "User",
                    documentType: document.type.displayName,
                    languageCode: languageCode,
                    skipIntro: true  // Skip intro for already-submitted documents
                )
                
                await MainActor.run {
                    introWordCount = result.introWordCount
                    playAudio(audioData: result.audioData)
                }
            } catch {
                await MainActor.run {
                    isLoadingAudio = false
                    print("TTS Error: \(error)")
                }
            }
        }
    }
    
    /// Read the English translation after user accepts the offer
    private func readEnglishTranslation() {
        guard let translatedText = document.translatedText, !translatedText.isEmpty else {
            return
        }
        
        isLoadingAudio = true
        isReadingTranslation = true
        
        // Prepare words for highlighting
        words = translatedText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        currentWordIndex = 0
        
        // Switch to translation tab if available
        if hasTranslation {
            selectedTab = 1
        }
        
        Task {
            do {
                // Skip intro for already-submitted documents
                let result = try await ttsService.generateSpeech(
                    text: translatedText,
                    employeeName: document.submittedBy ?? "User",
                    documentType: document.type.displayName,
                    languageCode: "en-US",  // Always English for translation
                    skipIntro: true  // Skip intro for already-submitted documents
                )
                
                await MainActor.run {
                    introWordCount = result.introWordCount
                    playAudio(audioData: result.audioData)
                }
            } catch {
                await MainActor.run {
                    isLoadingAudio = false
                    isReadingTranslation = false
                    print("TTS Error: \(error)")
                }
            }
        }
    }
    
    private func playAudio(audioData: Data) {
        do {
            // Configure audio session for playback (same as AI Vision)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            print("TTS: Audio session configured, data size: \(audioData.count) bytes")
            
            // Use AVAudioPlayer directly like AI Vision
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            print("TTS: Audio playback started, duration: \(audioPlayer?.duration ?? 0), intro words: \(introWordCount)")
            
            isLoadingAudio = false
            isReading = true
            
            // Reading speed: ~2.5 words per second (average TTS speed)
            let wordsPerSecond: Double = 2.5
            let interval = 1.0 / wordsPerSecond
            
            // Calculate delay for intro speech (if any)
            // For skipIntro=true, introWordCount will be 0
            let introDelaySeconds = Double(introWordCount) * interval
            
            if introWordCount > 0 {
                print("TTS: Delaying highlight by \(introDelaySeconds)s for intro (\(introWordCount) words)")
                
                // Delay starting the highlight timer until intro finishes
                introDelayTimer = Timer.scheduledTimer(withTimeInterval: introDelaySeconds, repeats: false) { [self] _ in
                    startHighlightTimer(interval: interval)
                }
            } else {
                // No intro (skipIntro=true) - start highlighting immediately
                startHighlightTimer(interval: interval)
            }
            
            // Also set a timer to check for audio completion
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                if !(audioPlayer?.isPlaying ?? false) && !isLoadingAudio {
                    timer.invalidate()
                    onAudioFinished()
                }
            }
        } catch {
            isLoadingAudio = false
            isReading = false
            print("TTS: Audio playback error: \(error)")
        }
    }
    
    /// Start the highlight timer for syncing text with speech
    private func startHighlightTimer(interval: Double) {
        print("TTS: Starting text highlighting, \(words.count) words at \(1.0/interval) words/sec")
        
        highlightTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            if currentWordIndex < words.count {
                currentWordIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
    
    /// Called when audio playback finishes naturally
    private func onAudioFinished() {
        let wasReadingTranslation = isReadingTranslation
        let wasNonEnglish = isNonEnglishDocument && hasTranslation && !wasReadingTranslation
        
        // Clean up audio state
        audioPlayer?.stop()
        audioPlayer = nil
        highlightTimer?.invalidate()
        highlightTimer = nil
        introDelayTimer?.invalidate()
        introDelayTimer = nil
        isReading = false
        currentWordIndex = 0
        words = []
        introWordCount = 0
        
        // If we just finished reading non-English original text and there's a translation,
        // offer to read the English version
        if wasNonEnglish {
            // Small delay before showing the popup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showTranslationOffer = true
            }
        }
        
        isReadingTranslation = false
    }
    
    /// Stop reading manually (user pressed stop)
    private func stopReading() {
        audioPlayer?.stop()
        audioPlayer = nil
        highlightTimer?.invalidate()
        highlightTimer = nil
        introDelayTimer?.invalidate()
        introDelayTimer = nil
        isReading = false
        currentWordIndex = 0
        words = []
        introWordCount = 0
        isReadingTranslation = false
        // Don't show translation offer when user manually stops
    }
    
    // Helper to build highlighted text
    private func highlightedText(for fullText: String) -> AttributedString {
        var attributedString = AttributedString(fullText)
        
        guard isReading && currentWordIndex > 0 && currentWordIndex <= words.count else {
            return attributedString
        }
        
        // Find and highlight all words up to currentWordIndex
        var searchStartIndex = fullText.startIndex
        for i in 0..<currentWordIndex {
            guard i < words.count else { break }
            let word = words[i]
            
            if let range = fullText.range(of: word, range: searchStartIndex..<fullText.endIndex) {
                if let attributedRange = Range(range, in: attributedString) {
                    attributedString[attributedRange].backgroundColor = .yellow.opacity(0.5)
                    attributedString[attributedRange].foregroundColor = .black
                }
                searchStartIndex = range.upperBound
            }
        }
        
        return attributedString
    }
}

// MARK: - Document Review Tab Button
struct DocumentReviewTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var iconColor: Color {
        switch icon {
        case "doc.text": return .blue
        case "globe": return .green
        case "sparkles": return .purple
        case "photo.stack": return .orange
        default: return AppColors.primary
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? iconColor : .gray)
                
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? (colorScheme == .dark ? .white : .black) : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isSelected ?
                (colorScheme == .dark ? Color.white.opacity(0.1) : Color.white) :
                Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct CaseTimelineEntryView: View {
    let entry: CaseAuditEntry
    let colorScheme: ColorScheme
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline dot and line
            VStack(spacing: 0) {
                Circle()
                    .fill(AppColors.primary)
                    .frame(width: 10, height: 10)
                
                Rectangle()
                    .fill(AppColors.primary.opacity(0.3))
                    .frame(width: 2)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.action)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textPrimary)
                
                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundColor(textSecondary)
                
                if !entry.details.isEmpty {
                    Text(entry.details)
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
                        .padding(10)
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Document Upload Sheet
struct DocumentUploadSheet: View {
    let conflictCase: ConflictCase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedType: CaseDocumentType = .complaintA
    @State private var documentContent = ""
    @State private var selectedEmployee: InvolvedEmployee?
    @State private var showScanner = false
    @State private var inputMethod: InputMethod = .none
    
    // Get employees appropriate for the selected document type
    private var availableEmployees: [InvolvedEmployee] {
        switch selectedType {
        case .complaintA:
            if let complainantA = conflictCase.complainantA {
                return [complainantA]
            }
            return []
        case .complaintB:
            if let complainantB = conflictCase.complainantB {
                return [complainantB]
            }
            return []
        case .witnessStatement:
            return conflictCase.witnesses
        case .evidence, .priorRecord, .counselingRecord, .warningDocument, .other:
            return conflictCase.involvedEmployees
        }
    }
    
    enum InputMethod {
        case none
        case scan
        case manual
    }
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var inputBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
    }
    
    private var inputBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Document Type Picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("DOCUMENT TYPE")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(textSecondary)
                            
                            Picker("Type", selection: $selectedType) {
                                ForEach(CaseDocumentType.allCases, id: \.self) { type in
                                    Text(type.displayName).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(textPrimary)
                            .onChange(of: selectedType) { _, _ in
                                // Reset employee selection when document type changes
                                selectedEmployee = nil
                            }
                        }
                        
                        // Input Method Selection
                        if inputMethod == .none {
                            inputMethodSelection
                        } else if inputMethod == .manual {
                            manualInputSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(textSecondary)
                }
            }
            .fullScreenCover(isPresented: $showScanner) {
                DocumentScannerEntryView(
                    conflictCase: conflictCase,
                    documentType: selectedType,
                    onDocumentAdded: {
                        dismiss()
                    }
                )
            }
        }
    }
    
    private var inputMethodSelection: some View {
        VStack(spacing: 16) {
            Text("HOW WOULD YOU LIKE TO ADD THIS DOCUMENT?")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Scan Option
            Button {
                showScanner = true
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 22))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scan Document")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(textPrimary)
                        
                        Text("Use camera to scan and OCR")
                            .font(.system(size: 13))
                            .foregroundColor(textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding(16)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            
            // Manual Entry Option
            Button {
                withAnimation {
                    inputMethod = .manual
                }
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "keyboard")
                            .font(.system(size: 22))
                            .foregroundColor(.green)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Type Manually")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(textPrimary)
                        
                        Text("Enter document text directly")
                            .font(.system(size: 13))
                            .foregroundColor(textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding(16)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }
    
    private var manualInputSection: some View {
        VStack(spacing: 20) {
            // Back button
            Button {
                withAnimation {
                    inputMethod = .none
                    selectedEmployee = nil
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Back to options")
                        .font(.system(size: 14))
                }
                .foregroundColor(AppColors.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Submitted By - Employee Dropdown
            VStack(alignment: .leading, spacing: 8) {
                Text("Submitted By")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textSecondary)
                
                if availableEmployees.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No employees available")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(textPrimary)
                            
                            Text("Please add employees to the case first")
                                .font(.system(size: 13))
                                .foregroundColor(textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if availableEmployees.count == 1 {
                    // Auto-select single employee
                    let employee = availableEmployees[0]
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppColors.primary.opacity(0.15))
                                .frame(width: 40, height: 40)
                            
                            Text(employee.name.prefix(1).uppercased())
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(employee.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(textPrimary)
                            
                            if !employee.role.isEmpty || !employee.department.isEmpty {
                                Text([employee.role, employee.department].filter { !$0.isEmpty }.joined(separator: " • "))
                                    .font(.system(size: 13))
                                    .foregroundColor(textSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.success)
                    }
                    .padding(14)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onAppear {
                        selectedEmployee = employee
                    }
                } else {
                    // Multiple employees - show picker
                    Menu {
                        ForEach(availableEmployees) { employee in
                            Button {
                                selectedEmployee = employee
                            } label: {
                                HStack {
                                    Text(employee.name)
                                    if !employee.role.isEmpty {
                                        Text("(\(employee.role))")
                                            .foregroundColor(.secondary)
                                    }
                                    if selectedEmployee?.id == employee.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if let employee = selectedEmployee {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.primary.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    
                                    Text(employee.name.prefix(1).uppercased())
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(AppColors.primary)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(employee.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(textPrimary)
                                    
                                    if !employee.role.isEmpty || !employee.department.isEmpty {
                                        Text([employee.role, employee.department].filter { !$0.isEmpty }.joined(separator: " • "))
                                            .font(.system(size: 13))
                                            .foregroundColor(textSecondary)
                                    }
                                }
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray)
                                
                                Text("Select employee...")
                                    .font(.system(size: 15))
                                    .foregroundColor(textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .padding(14)
                        .background(inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedEmployee != nil ? AppColors.primary.opacity(0.3) : inputBorder, lineWidth: 1)
                        )
                    }
                }
            }
            
            // Document Content
            VStack(alignment: .leading, spacing: 8) {
                Text("Document Content")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textSecondary)
                
                TextEditor(text: $documentContent)
                    .frame(minHeight: 200)
                    .padding(12)
                    .background(inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(inputBorder, lineWidth: 1)
                    )
            }
            
            // Add Button
            Button {
                addDocument()
            } label: {
                HStack {
                    if canAddDocument {
                        Image(systemName: "doc.badge.plus")
                        Text("Add Document")
                    } else {
                        Image(systemName: "exclamationmark.circle")
                        Text(availableEmployees.isEmpty ? "No Employees" : "Select Employee First")
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canAddDocument ? AppColors.primary : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canAddDocument)
        }
    }
    
    private var canAddDocument: Bool {
        !documentContent.isEmpty && selectedEmployee != nil
    }
    
    private func addDocument() {
        let document = CaseDocument(
            type: selectedType,
            cleanedText: documentContent,
            employeeId: selectedEmployee?.id,
            submittedBy: selectedEmployee?.name
        )
        Task {
            await ConflictResolutionManager.shared.addDocument(
                to: conflictCase.id,
                document: document
            )
        }
        dismiss()
    }
}

// MARK: - Reanalysis Loading Overlay
struct ReanalysisLoadingOverlay: View {
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var currentStage: Int = 0
    
    private let stages = [
        ("doc.text.magnifyingglass", "Scanning new evidence..."),
        ("brain.head.profile", "Analyzing prior history..."),
        ("arrow.triangle.2.circlepath", "Cross-referencing statements..."),
        ("chart.bar.doc.horizontal", "Updating analysis results..."),
        ("sparkles", "Finalizing insights...")
    ]
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.12) : Color.white
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated icon
            ZStack {
                // Outer rotating ring
                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [AppColors.primary, AppColors.primary.opacity(0.2)]),
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(rotationAngle))
                
                // Pulsing background
                Circle()
                    .fill(AppColors.primary.opacity(0.1))
                    .frame(width: 70, height: 70)
                    .scaleEffect(pulseScale)
                
                // Center icon
                Image(systemName: stages[currentStage].0)
                    .font(.system(size: 28))
                    .foregroundColor(AppColors.primary)
                    .transition(.scale.combined(with: .opacity))
                    .id(currentStage)
            }
            
            VStack(spacing: 8) {
                Text("Re-Analyzing with New Evidence")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Text(stages[currentStage].1)
                    .font(.system(size: 14))
                    .foregroundColor(textSecondary)
                    .animation(.easeInOut(duration: 0.3), value: currentStage)
            }
            
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<stages.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStage ? AppColors.primary : AppColors.primary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentStage ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3), value: currentStage)
                }
            }
        }
        .padding(40)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 10)
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Rotation animation
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        
        // Pulse animation
        withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }
        
        // Stage progression
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStage = (currentStage + 1) % stages.count
            }
        }
    }
}

// MARK: - Preview
#Preview {
    CaseDetailView(caseId: UUID())
}
