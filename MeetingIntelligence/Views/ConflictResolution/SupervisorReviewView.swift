//
//  SupervisorReviewView.swift
//  MeetingIntelligence
//
//  Phase 9: Supervisor Review
//  Main review screen for AI-generated documents before finalization
//

import SwiftUI

// MARK: - Review Status
enum ReviewStatus: String, Codable {
    case pending = "PENDING"
    case inReview = "IN_REVIEW"
    case changesRequested = "CHANGES_REQUESTED"
    case approved = "APPROVED"
    case rejected = "REJECTED"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending Review"
        case .inReview: return "In Review"
        case .changesRequested: return "Changes Requested"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .gray
        case .inReview: return .blue
        case .changesRequested: return .orange
        case .approved: return .green
        case .rejected: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .inReview: return "eye"
        case .changesRequested: return "exclamationmark.triangle"
        case .approved: return "checkmark.seal.fill"
        case .rejected: return "xmark.seal.fill"
        }
    }
}

// MARK: - Review Comment
struct ReviewComment: Identifiable, Codable {
    let id: UUID
    let section: String
    let comment: String
    let createdAt: Date
    let createdBy: String
    var isResolved: Bool
    
    init(section: String, comment: String, createdBy: String) {
        self.id = UUID()
        self.section = section
        self.comment = comment
        self.createdAt = Date()
        self.createdBy = createdBy
        self.isResolved = false
    }
}

// MARK: - Document Section
struct DocumentSection: Identifiable {
    let id: String
    let title: String
    var content: String
    var isEditable: Bool
    var hasChanges: Bool
    
    init(id: String, title: String, content: String, isEditable: Bool = true) {
        self.id = id
        self.title = title
        self.content = content
        self.isEditable = isEditable
        self.hasChanges = false
    }
}

// MARK: - Supervisor Review View
struct SupervisorReviewView: View {
    let conflictCase: ConflictCase
    let generatedResult: GeneratedDocumentResult
    let onApprove: (GeneratedDocumentResult, [DocumentEdit]) -> Void
    let onRequestChanges: ([ReviewComment]) -> Void
    let onReject: (String) -> Void
    let onBack: () -> Void
    
    @State private var reviewStatus: ReviewStatus = .inReview
    @State private var documentSections: [DocumentSection] = []
    @State private var comments: [ReviewComment] = []
    @State private var edits: [DocumentEdit] = []
    @State private var selectedSection: DocumentSection? = nil
    @State private var showCommentSheet = false
    @State private var showApprovalSheet = false
    @State private var showRejectSheet = false
    @State private var showEditHistory = false
    @State private var showPreview = false
    @State private var newComment = ""
    @State private var rejectReason = ""
    @State private var approvalNotes = ""
    
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
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Review Status Header
                        reviewStatusHeader
                        
                        // Document Info Card
                        documentInfoCard
                        
                        // Quick Actions
                        quickActionsBar
                        
                        // Document Sections
                        documentSectionsView
                        
                        // Comments Section
                        if !comments.isEmpty {
                            commentsSection
                        }
                        
                        // Action Buttons
                        actionButtons
                    }
                    .padding()
                }
            }
            .navigationTitle("Review Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        onBack()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showEditHistory = true
                        } label: {
                            Label("Edit History", systemImage: "clock.arrow.circlepath")
                        }
                        
                        Button {
                            showCommentSheet = true
                        } label: {
                            Label("Add Comment", systemImage: "text.bubble")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showRejectSheet = true
                        } label: {
                            Label("Reject Document", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                loadDocumentSections()
                logReviewStarted()
            }
            .sheet(item: $selectedSection) { section in
                DocumentSectionEditorSheet(
                    section: section,
                    onSave: { updatedContent in
                        saveEdit(for: section, newContent: updatedContent)
                        selectedSection = nil
                    },
                    onCancel: {
                        selectedSection = nil
                    }
                )
            }
            .sheet(isPresented: $showCommentSheet) {
                AddCommentSheet(
                    sections: documentSections,
                    onAdd: { section, comment in
                        addComment(section: section, comment: comment)
                        showCommentSheet = false
                    },
                    onCancel: {
                        showCommentSheet = false
                    }
                )
            }
            .sheet(isPresented: $showApprovalSheet) {
                ApprovalConfirmationSheet(
                    documentTitle: generatedResult.document.title,
                    editCount: edits.count,
                    notes: $approvalNotes,
                    onApprove: {
                        approveDocument()
                        showApprovalSheet = false
                    },
                    onCancel: {
                        showApprovalSheet = false
                    }
                )
            }
            .sheet(isPresented: $showRejectSheet) {
                RejectDocumentSheet(
                    reason: $rejectReason,
                    onReject: {
                        rejectDocument()
                        showRejectSheet = false
                    },
                    onCancel: {
                        showRejectSheet = false
                    }
                )
            }
            .sheet(isPresented: $showEditHistory) {
                EditHistoryView(
                    edits: edits,
                    onDismiss: {
                        showEditHistory = false
                    }
                )
            }
            .sheet(isPresented: $showPreview) {
                ReviewDocumentPreviewSheet(
                    document: generatedResult,
                    sections: documentSections,
                    conflictCase: conflictCase,
                    onDismiss: {
                        showPreview = false
                    }
                )
            }
        }
    }
    
    // MARK: - Review Status Header
    private var reviewStatusHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(reviewStatus.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: reviewStatus.icon)
                    .font(.system(size: 20))
                    .foregroundColor(reviewStatus.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(reviewStatus.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Text("Last updated: \(Date().formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 12))
                    .foregroundColor(textSecondary)
            }
            
            Spacer()
            
            if !edits.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(edits.count)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.blue)
                    Text("edits")
                        .font(.system(size: 10))
                        .foregroundColor(textSecondary)
                }
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Document Info Card
    private var documentInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: documentIcon)
                    .font(.system(size: 24))
                    .foregroundColor(documentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(generatedResult.document.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    Text("Generated \(generatedResult.generatedAt.formatted())")
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
                }
                
                Spacer()
                
                actionTypeBadge
            }
            
            Divider()
            
            // Case reference
            HStack {
                Label(conflictCase.caseNumber, systemImage: "folder")
                Spacer()
                Label("\(documentSections.count) sections", systemImage: "list.bullet")
            }
            .font(.system(size: 12))
            .foregroundColor(textSecondary)
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var documentIcon: String {
        switch generatedResult.actionType {
        case .coaching: return "person.2.fill"
        case .counseling: return "doc.text.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .escalate: return "arrow.up.circle.fill"
        }
    }
    
    private var documentColor: Color {
        switch generatedResult.actionType {
        case .coaching: return .green
        case .counseling: return .blue
        case .warning: return .orange
        case .escalate: return .red
        }
    }
    
    private var actionTypeBadge: some View {
        Text(generatedResult.actionType.displayName)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(documentColor)
            .clipShape(Capsule())
    }
    
    // MARK: - Quick Actions Bar
    private var quickActionsBar: some View {
        HStack(spacing: 12) {
            quickActionButton(icon: "pencil", label: "Edit All", color: .blue) {
                // Select first editable section
                if let firstEditable = documentSections.first(where: { $0.isEditable }) {
                    selectedSection = firstEditable
                }
            }
            
            quickActionButton(icon: "text.bubble", label: "Comment", color: .orange) {
                showCommentSheet = true
            }
            
            quickActionButton(icon: "eye", label: "Preview", color: .purple) {
                showPreview = true
            }
            
            quickActionButton(icon: "clock.arrow.circlepath", label: "History", color: .gray) {
                showEditHistory = true
            }
        }
    }
    
    private func quickActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }
                
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Document Sections View
    private var documentSectionsView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Document Sections")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Spacer()
                
                if documentSections.contains(where: { $0.hasChanges }) {
                    Text("Modified")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            
            ForEach(documentSections) { section in
                documentSectionCard(section)
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func documentSectionCard(_ section: DocumentSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(section.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                if section.hasChanges {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                if section.isEditable {
                    Button {
                        selectedSection = section
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Text(section.content)
                .font(.system(size: 13))
                .foregroundColor(textSecondary)
                .lineLimit(3)
            
            // Section comments
            let sectionComments = comments.filter { $0.section == section.id && !$0.isResolved }
            if !sectionComments.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text("\(sectionComments.count) comment\(sectionComments.count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(innerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Comments Section
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Review Comments")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Spacer()
                
                Text("\(comments.filter { !$0.isResolved }.count) open")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
            }
            
            ForEach(comments) { comment in
                commentCard(comment)
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func commentCard(_ comment: ReviewComment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(comment.isResolved ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: comment.isResolved ? "checkmark" : "text.bubble")
                    .font(.system(size: 12))
                    .foregroundColor(comment.isResolved ? .green : .orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.section)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textSecondary)
                    
                    Spacer()
                    
                    Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundColor(textSecondary)
                }
                
                Text(comment.comment)
                    .font(.system(size: 13))
                    .foregroundColor(textPrimary)
                
                if !comment.isResolved {
                    Button {
                        resolveComment(comment)
                    } label: {
                        Text("Mark Resolved")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(innerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Approve button
            Button {
                showApprovalSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Approve Document")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Request changes button
            if !comments.isEmpty {
                Button {
                    onRequestChanges(comments)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Request Changes (\(comments.filter { !$0.isResolved }.count))")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadDocumentSections() {
        switch generatedResult.document {
        case .coaching(let doc):
            documentSections = [
                DocumentSection(id: "overview", title: "Overview", content: doc.overview),
                DocumentSection(id: "outline", title: "Discussion Outline", content: doc.discussionOutline.opening),
                DocumentSection(id: "talking_points", title: "Talking Points", content: doc.talkingPoints.joined(separator: "\n• ")),
                DocumentSection(id: "questions", title: "Questions to Ask", content: doc.questionsToAsk.joined(separator: "\n• ")),
                DocumentSection(id: "followup", title: "Follow-Up Plan", content: doc.followUpPlan.timeline)
            ]
            
        case .counseling(let doc):
            documentSections = [
                DocumentSection(id: "summary", title: "Incident Summary", content: doc.incidentSummary),
                DocumentSection(id: "expectations", title: "Expectations", content: doc.expectations.joined(separator: "\n• ")),
                DocumentSection(id: "consequences", title: "Consequences", content: doc.consequences),
                DocumentSection(id: "acknowledgment", title: "Acknowledgment Statement", content: doc.acknowledgmentSection)
            ]
            
        case .warning(let doc):
            documentSections = [
                DocumentSection(id: "level", title: "Warning Level", content: doc.warningLevel, isEditable: false),
                DocumentSection(id: "description", title: "Description", content: doc.describeInDetail),
                DocumentSection(id: "policy", title: "Policy Violated", content: doc.companyRulesViolated.joined(separator: "\n• ")),
                DocumentSection(id: "corrective", title: "Corrective Action Required", content: doc.requiredCorrectiveAction.joined(separator: "\n• ")),
                DocumentSection(id: "consequences", title: "Future Consequences", content: doc.consequencesOfNotPerforming)
            ]
            
        case .escalation(let doc):
            let caseSummaryText = "Case: \(doc.caseSummary.caseNumber)\nType: \(doc.caseSummary.caseType)\nDate: \(doc.caseSummary.incidentDate)\nLocation: \(doc.caseSummary.location)"
            documentSections = [
                DocumentSection(id: "summary", title: "Case Summary", content: caseSummaryText),
                DocumentSection(id: "urgency", title: "Urgency Level", content: doc.urgencyLevel, isEditable: false),
                DocumentSection(id: "notes", title: "Supervisor Notes", content: doc.supervisorNotes),
                DocumentSection(id: "recommendations", title: "Recommended Actions", content: doc.recommendedActions.joined(separator: "\n• "))
            ]
        }
    }
    
    private func saveEdit(for section: DocumentSection, newContent: String) {
        guard let index = documentSections.firstIndex(where: { $0.id == section.id }) else { return }
        
        let originalContent = documentSections[index].content
        
        // Create edit record
        let edit = DocumentEdit(
            sectionId: section.id,
            sectionTitle: section.title,
            originalContent: originalContent,
            newContent: newContent,
            editedBy: "Supervisor" // Would use actual user name
        )
        edits.append(edit)
        
        // Update section
        documentSections[index].content = newContent
        documentSections[index].hasChanges = true
        
        // Log edit
        AuditTrailService.shared.logDocumentEdited(
            caseId: conflictCase.id,
            caseNumber: conflictCase.caseNumber,
            sectionEdited: section.title,
            previousContent: originalContent,
            newContent: newContent
        )
    }
    
    private func addComment(section: String, comment: String) {
        let newComment = ReviewComment(
            section: section,
            comment: comment,
            createdBy: "Supervisor"
        )
        comments.append(newComment)
        
        reviewStatus = .changesRequested
    }
    
    private func resolveComment(_ comment: ReviewComment) {
        guard let index = comments.firstIndex(where: { $0.id == comment.id }) else { return }
        comments[index].isResolved = true
    }
    
    private func approveDocument() {
        reviewStatus = .approved
        
        // Log approval
        AuditTrailService.shared.logEvent(
            caseId: conflictCase.id,
            caseNumber: conflictCase.caseNumber,
            eventType: .supervisorReviewCompleted,
            description: "Document approved with \(edits.count) edits"
        )
        
        onApprove(generatedResult, edits)
    }
    
    private func rejectDocument() {
        reviewStatus = .rejected
        
        // Log rejection
        AuditTrailService.shared.logEvent(
            caseId: conflictCase.id,
            caseNumber: conflictCase.caseNumber,
            eventType: .supervisorReviewCompleted,
            description: "Document rejected: \(rejectReason)"
        )
        
        onReject(rejectReason)
    }
    
    private func logReviewStarted() {
        AuditTrailService.shared.logEvent(
            caseId: conflictCase.id,
            caseNumber: conflictCase.caseNumber,
            eventType: .supervisorReviewStarted,
            description: "Supervisor review started for \(generatedResult.document.title)"
        )
    }
}

// MARK: - Document Edit Model
struct DocumentEdit: Identifiable, Codable {
    let id: UUID
    let sectionId: String
    let sectionTitle: String
    let originalContent: String
    let newContent: String
    let editedAt: Date
    let editedBy: String
    
    init(sectionId: String, sectionTitle: String, originalContent: String, newContent: String, editedBy: String) {
        self.id = UUID()
        self.sectionId = sectionId
        self.sectionTitle = sectionTitle
        self.originalContent = originalContent
        self.newContent = newContent
        self.editedAt = Date()
        self.editedBy = editedBy
    }
}

// MARK: - Document Preview Sheet
struct ReviewDocumentPreviewSheet: View {
    let document: GeneratedDocumentResult
    let sections: [DocumentSection]
    let conflictCase: ConflictCase
    let onDismiss: () -> Void
    
    @State private var companyLogo: UIImage? = nil
    @State private var showImagePicker = false
    @State private var warningType: WarningType = .written
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.3) : Color.black
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(UIColor.systemBackground) : .white
    }
    
    // Get employee name from case
    private var employeeName: String {
        conflictCase.involvedEmployees.first?.name ?? "_______________"
    }
    
    // Get employee title/position
    private var employeeTitle: String {
        conflictCase.involvedEmployees.first?.role ?? "_______________"
    }
    
    // Get warning level from document
    private var warningLevel: String {
        if case .warning(let doc) = document.document {
            return doc.warningLevel
        }
        return "First Written Warning"
    }
    
    // Get description content
    private var descriptionContent: String {
        sections.first(where: { $0.id == "description" })?.content ?? ""
    }
    
    // Get policy violated content
    private var policyViolatedContent: String {
        sections.first(where: { $0.id == "policy" })?.content ?? ""
    }
    
    // Get corrective action content
    private var correctiveActionContent: String {
        sections.first(where: { $0.id == "corrective" })?.content ?? ""
    }
    
    // Get consequences content
    private var consequencesContent: String {
        sections.first(where: { $0.id == "consequences" })?.content ?? ""
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Official Warning Notice Template
                    warningNoticeTemplate
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Document Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showImagePicker = true
                        } label: {
                            Label("Add Company Logo", systemImage: "photo.badge.plus")
                        }
                        
                        Button {
                            // Export PDF
                        } label: {
                            Label("Export PDF", systemImage: "doc.fill")
                        }
                        
                        Button {
                            // Print
                        } label: {
                            Label("Print", systemImage: "printer")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                LogoImagePicker(image: $companyLogo)
            }
        }
    }
    
    // MARK: - Warning Notice Template
    private var warningNoticeTemplate: some View {
        VStack(spacing: 0) {
            // Company Logo Section
            companyLogoSection
            
            // Title Section
            titleSection
            
            // Intention Statement
            intentionStatement
            
            // Date Line
            dateLine
            
            // Warning Type Selection
            warningTypeRow
            
            // Employee Info Table
            employeeInfoTable
            
            // Company Rules Violated
            companyRulesSection
            
            // Description Section
            descriptionSection
            
            // Signature Section
            signatureSection
            
            // Certification Statement
            certificationStatement
        }
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    // MARK: - Company Logo Section
    private var companyLogoSection: some View {
        VStack(spacing: 8) {
            if let logo = companyLogo {
                Image(uiImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 60)
            } else {
                Button {
                    showImagePicker = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.gray)
                        Text("Tap to Add Company Logo")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .frame(height: 60)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .border(borderColor, width: 0.5)
    }
    
    // MARK: - Title Section
    private var titleSection: some View {
        VStack(spacing: 2) {
            Text("WARNING NOTICE / AVISO DISCIPLINARIO")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .border(borderColor, width: 0.5)
    }
    
    // MARK: - Intention Statement
    private var intentionStatement: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("The intention of this action is to enable the employee to understand what is expected. Therefore, it is meant to be a pro-active step to clarify a situation and avoid further occurrences.")
                .font(.system(size: 8))
                .foregroundColor(.primary)
            
            Text("La intención de esta acción disciplinaria es hacerle entender al empleado lo que se espera de el/ella. Esta acción es un paso pro-activo para clarificar situaciones y evitar ocurrencias futuras.")
                .font(.system(size: 8))
                .italic()
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .border(borderColor, width: 0.5)
    }
    
    // MARK: - Date Line
    private var dateLine: some View {
        HStack(spacing: 4) {
            Text("Today's Date:")
                .font(.system(size: 9, weight: .medium))
            Text(Date().formatted(date: .numeric, time: .omitted))
                .font(.system(size: 9))
                .underline()
            
            Text("Day of the Week:")
                .font(.system(size: 9, weight: .medium))
                .padding(.leading, 8)
            Text(dayOfWeek(Date()))
                .font(.system(size: 9))
                .underline()
            
            Text("Date of the Incident:")
                .font(.system(size: 9, weight: .medium))
                .padding(.leading, 8)
            Text(conflictCase.incidentDate.formatted(date: .numeric, time: .omitted))
                .font(.system(size: 9))
                .underline()
            
            Text("Day of the Week:")
                .font(.system(size: 9, weight: .medium))
                .padding(.leading, 8)
            Text(dayOfWeek(conflictCase.incidentDate))
                .font(.system(size: 9))
                .underline()
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .border(borderColor, width: 0.5)
    }
    
    // MARK: - Warning Type Row
    private var warningTypeRow: some View {
        HStack(spacing: 16) {
            warningTypeCheckbox(type: .verbal, label: "Verbal")
            warningTypeCheckbox(type: .written, label: "Written", marked: true)
            warningTypeCheckbox(type: .suspension, label: "Suspension")
            warningTypeCheckbox(type: .termination, label: "Termination")
            warningTypeCheckbox(type: .other, label: "Other")
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .border(borderColor, width: 0.5)
    }
    
    private func warningTypeCheckbox(type: WarningType, label: String, marked: Bool = false) -> some View {
        HStack(spacing: 4) {
            ZStack {
                Rectangle()
                    .stroke(borderColor, lineWidth: 1)
                    .frame(width: 12, height: 12)
                
                if marked || warningType == type {
                    Text("X")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            
            Text(label)
                .font(.system(size: 9, weight: type == .written ? .bold : .regular))
                .underline(type == .suspension)
        }
    }
    
    // MARK: - Employee Info Table
    private var employeeInfoTable: some View {
        VStack(spacing: 0) {
            // Row 1: Name and Prior Warnings
            HStack(spacing: 0) {
                // Name cell
                VStack(alignment: .leading, spacing: 2) {
                    Text("Name:")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(employeeName)
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .border(borderColor, width: 0.5)
                
                // Prior Warnings cell
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Prior Warnings:")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 1) {
                            HStack(spacing: 4) {
                                Text("Date:")
                                    .font(.system(size: 8))
                                Text("________")
                                    .font(.system(size: 8))
                                Text("(V, W, S) Circle One")
                                    .font(.system(size: 7))
                            }
                            HStack(spacing: 4) {
                                Text("Date:")
                                    .font(.system(size: 8))
                                Text("________")
                                    .font(.system(size: 8))
                                Text("(V, W, S) Circle One")
                                    .font(.system(size: 7))
                            }
                        }
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .border(borderColor, width: 0.5)
            }
            
            // Row 2: Title, Department, File No
            HStack(spacing: 0) {
                // Title cell
                VStack(alignment: .leading, spacing: 2) {
                    Text("Title:")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(employeeTitle)
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .border(borderColor, width: 0.5)
                
                // Department cell
                VStack(alignment: .leading, spacing: 2) {
                    Text("Department:")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(conflictCase.department)
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .border(borderColor, width: 0.5)
                
                // File No cell
                VStack(alignment: .leading, spacing: 2) {
                    Text("File No.")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(conflictCase.caseNumber)
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(6)
                .frame(width: 100, alignment: .leading)
                .border(borderColor, width: 0.5)
            }
        }
    }
    
    // MARK: - Company Rules Section
    private var companyRulesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Company rules violated")
                .font(.system(size: 10, weight: .medium))
            
            Text(policyViolatedContent.isEmpty ? "• ________________________________" : policyViolatedContent)
                .font(.system(size: 9))
                .foregroundColor(.primary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 60)
        .border(borderColor, width: 0.5)
    }
    
    // MARK: - Description Section
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Describe in detail
            VStack(alignment: .leading, spacing: 4) {
                Text("Describe in detail what happened")
                    .font(.system(size: 10, weight: .medium))
                
                Text(descriptionContent.isEmpty ? " " : descriptionContent)
                    .font(.system(size: 9))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 80)
            .border(borderColor, width: 0.5)
            
            // Conduct Deficiency (empty space for manual entry)
            VStack(alignment: .leading, spacing: 4) {
                Text("Conduct Deficiency:")
                    .font(.system(size: 10, weight: .bold))
                
                Text(" ")
                    .font(.system(size: 9))
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 40)
            .border(borderColor, width: 0.5)
            
            // Required Corrective Action
            VStack(alignment: .leading, spacing: 4) {
                Text("Required Corrective Action:")
                    .font(.system(size: 10, weight: .bold))
                
                Text(correctiveActionContent.isEmpty ? " " : correctiveActionContent)
                    .font(.system(size: 9))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 60)
            .border(borderColor, width: 0.5)
            
            // Consequences of not performing
            VStack(alignment: .leading, spacing: 4) {
                Text("Consequences of not performing:")
                    .font(.system(size: 10, weight: .bold))
                
                Text(consequencesContent.isEmpty ? " " : consequencesContent)
                    .font(.system(size: 9))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 60)
            .border(borderColor, width: 0.5)
        }
    }
    
    // MARK: - Signature Section
    private var signatureSection: some View {
        VStack(spacing: 0) {
            // Row 1: Supervisor and Manager
            HStack(spacing: 0) {
                signatureCell(label: "Supervisor")
                signatureCell(label: "Date")
                signatureCell(label: "Manager")
                signatureCell(label: "Date")
            }
            
            // Row 2: HR and Employee
            HStack(spacing: 0) {
                signatureCell(label: "H.R. Department")
                signatureCell(label: "Date")
                signatureCell(label: "Employee Signature")
                signatureCell(label: "Date")
            }
        }
    }
    
    private func signatureCell(label: String) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Text("_______________________")
                .font(.system(size: 9))
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 60)
        .border(borderColor, width: 0.5)
    }
    
    // MARK: - Certification Statement
    private var certificationStatement: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("I, the undersigned, hereby certify that the situation has been explained to me. I understand the consequences if the infraction is not remedied. I certify that I have received a copy of this notice.")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Yo doy a conocer que se me ha explicado la situación presente. Yo entiendo las consecuencias futuras si no cumplo con las reglas. Yo certifico que he recibido una copia de este documento siempre y cuando lo firme.")
                .font(.system(size: 8))
                .italic()
                .foregroundColor(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .border(borderColor, width: 0.5)
    }
    
    // MARK: - Helper Methods
    private func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

// MARK: - Warning Type Enum
enum WarningType: String, CaseIterable {
    case verbal = "Verbal"
    case written = "Written"
    case suspension = "Suspension"
    case termination = "Termination"
    case other = "Other"
}

// MARK: - Image Picker
struct LogoImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: LogoImagePicker
        
        init(_ parent: LogoImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
