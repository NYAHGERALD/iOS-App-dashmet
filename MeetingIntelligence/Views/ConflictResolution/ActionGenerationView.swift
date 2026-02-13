//
//  ActionGenerationView.swift
//  MeetingIntelligence
//
//  Phase 8: Action Generation
//  Displays and allows editing of generated action documents
//

import SwiftUI

struct ActionGenerationView: View {
    let conflictCase: ConflictCase
    let selectedRecommendation: RecommendationOption
    let analysisResult: AIComparisonResult?
    let policyMatches: [PolicyMatchResult]?
    let onDocumentGenerated: (GeneratedDocumentResult) -> Void
    let onBack: () -> Void
    
    @State private var generatedResult: GeneratedDocumentResult?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showEditMode = false
    
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
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                if isGenerating {
                    generatingSection
                } else if let error = errorMessage {
                    errorSection(error)
                } else if let result = generatedResult {
                    documentSection(result)
                } else {
                    readyToGenerateSection
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Generated Document")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    onBack()
                }
            }
            
            if generatedResult != nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showEditMode.toggle()
                    } label: {
                        Image(systemName: showEditMode ? "checkmark" : "pencil")
                    }
                }
            }
        }
        .onAppear {
            if generatedResult == nil && !isGenerating {
                generateDocument()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(actionColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: selectedRecommendation.type.icon)
                        .font(.system(size: 24))
                        .foregroundColor(actionColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedRecommendation.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    Text("Case \(conflictCase.caseNumber)")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var actionColor: Color {
        switch selectedRecommendation.type {
        case .coaching: return .green
        case .counseling: return .blue
        case .warning: return .orange
        case .escalate: return .red
        }
    }
    
    // MARK: - Generating Section
    private var generatingSection: some View {
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
                    .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: isGenerating)
                
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 28))
                    .foregroundColor(actionColor)
            }
            
            VStack(spacing: 8) {
                Text("Generating Document...")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Text("Our System is creating your \(selectedRecommendation.type.displayName.lowercased()) document")
                    .font(.system(size: 14))
                    .foregroundColor(textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // What's being generated
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
    
    // MARK: - Ready to Generate Section
    private var readyToGenerateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.gearshape.fill")
                .font(.system(size: 48))
                .foregroundColor(actionColor)
            
            Text("Ready to Generate")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Text("Tap below to generate your \(selectedRecommendation.type.displayName.lowercased()) document")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                generateDocument()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Generate Document")
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
    
    // MARK: - Document Section
    private func documentSection(_ result: GeneratedDocumentResult) -> some View {
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
            
            // Document content based on type
            switch result.document {
            case .coaching(let doc):
                coachingDocumentView(doc)
            case .counseling(let doc):
                counselingDocumentView(doc)
            case .warning(let doc):
                warningDocumentView(doc)
            case .escalation(let doc):
                escalationDocumentView(doc)
            }
            
            // Action buttons
            VStack(spacing: 12) {
                Button {
                    onDocumentGenerated(result)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Accept & Continue")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(actionColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button {
                    generatedResult = nil
                    generateDocument()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Regenerate")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(actionColor)
                }
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Coaching Document View
    private func coachingDocumentView(_ doc: CoachingDocument) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            documentTitle(doc.title)
            
            // Overview
            documentSection(title: "Overview", content: doc.overview)
            
            // Discussion Outline
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Discussion Outline")
                
                labeledText("Opening:", doc.discussionOutline.opening)
                
                if !doc.discussionOutline.keyPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Key Points:")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(textSecondary)
                        
                        ForEach(doc.discussionOutline.keyPoints, id: \.self) { point in
                            bulletPoint(point)
                        }
                    }
                }
            }
            .padding()
            .background(innerCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Talking Points
            listSection(title: "Talking Points", items: doc.talkingPoints)
            
            // Questions to Ask
            listSection(title: "Questions to Ask", items: doc.questionsToAsk)
            
            // Behavioral Focus Areas
            if !doc.behavioralFocusAreas.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Behavioral Focus Areas")
                    
                    ForEach(doc.behavioralFocusAreas, id: \.area) { area in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(area.area)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(textPrimary)
                            
                            Text(area.description)
                                .font(.system(size: 13))
                                .foregroundColor(textSecondary)
                            
                            HStack(spacing: 4) {
                                Text("Expected:")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.green)
                                Text(area.expectedChange)
                                    .font(.system(size: 12))
                                    .foregroundColor(textSecondary)
                            }
                        }
                        .padding()
                        .background(innerCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            
            // Follow-up Plan
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Follow-up Plan")
                
                labeledText("Timeline:", doc.followUpPlan.timeline)
                
                if !doc.followUpPlan.checkInDates.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Check-in Dates:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(textSecondary)
                        ForEach(doc.followUpPlan.checkInDates, id: \.self) { date in
                            bulletPoint(date)
                        }
                    }
                }
                
                if !doc.followUpPlan.successIndicators.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Success Indicators:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(textSecondary)
                        ForEach(doc.followUpPlan.successIndicators, id: \.self) { indicator in
                            bulletPoint(indicator)
                        }
                    }
                }
            }
            .padding()
            .background(innerCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    // MARK: - Counseling Document View
    private func counselingDocumentView(_ doc: CounselingDocument) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            documentTitle(doc.title)
            
            // Header info
            HStack {
                labeledText("Date:", doc.documentDate)
                Spacer()
                labeledText("Employees:", doc.employeeNames.joined(separator: ", "))
            }
            .padding()
            .background(innerCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Incident Summary
            documentSection(title: "Incident Summary", content: doc.incidentSummary)
            
            // Discussion Points
            listSection(title: "Discussion Points", items: doc.discussionPoints)
            
            // Expectations
            listSection(title: "Expectations", items: doc.expectations)
            
            // Policy References
            if !doc.policyReferences.isEmpty {
                listSection(title: "Policy References", items: doc.policyReferences)
            }
            
            // Improvement Plan
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Improvement Plan")
                
                labeledText("Timeline:", doc.improvementPlan.timeline)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Goals:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textSecondary)
                    ForEach(doc.improvementPlan.goals, id: \.self) { goal in
                        bulletPoint(goal)
                    }
                }
                
                if !doc.improvementPlan.supportProvided.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Support Provided:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(textSecondary)
                        ForEach(doc.improvementPlan.supportProvided, id: \.self) { support in
                            bulletPoint(support)
                        }
                    }
                }
            }
            .padding()
            .background(innerCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Consequences
            documentSection(title: "Consequences", content: doc.consequences)
            
            // Acknowledgment
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Acknowledgment")
                Text(doc.acknowledgmentSection)
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
                    .italic()
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    // MARK: - Warning Document View
    private func warningDocumentView(_ doc: WarningDocument) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            documentTitle(doc.title)
            
            // Warning level badge
            HStack {
                Text(doc.warningLevel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .clipShape(Capsule())
                
                Spacer()
                
                Text(doc.documentDate)
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
            }
            
            // Employees
            HStack {
                Text("Employees:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textSecondary)
                Text(doc.employeeNames.joined(separator: ", "))
                    .font(.system(size: 13))
                    .foregroundColor(textPrimary)
            }
            
            // Company Rules Violated
            if !doc.companyRulesViolated.isEmpty {
                listSection(title: "Company Rules Violated", items: doc.companyRulesViolated, color: .red)
            }
            
            // Describe in Detail What Happened
            documentSection(title: "Describe in Detail What Happened", content: doc.describeInDetail)
            
            // Conduct Deficiency
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Conduct Deficiency")
                Text(doc.conductDeficiency)
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
                    .lineSpacing(4)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Required Corrective Action
            listSection(title: "Required Corrective Action", items: doc.requiredCorrectiveAction, color: .blue)
            
            // Consequences of Not Performing
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Consequences of Not Performing")
                Text(doc.consequencesOfNotPerforming)
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
                    .lineSpacing(4)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Prior Actions (if any)
            if !doc.priorActions.isEmpty && doc.priorActions != "No prior formal actions documented" {
                documentSection(title: "Prior Actions", content: doc.priorActions)
            }
            
            // Review Date
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.orange)
                Text("Review Date: \(doc.reviewDate)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textPrimary)
            }
            .padding()
            .background(innerCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Signature Section
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Signatures Required")
                
                signatureLine("Employee Acknowledgment", doc.signatureSection.employeeAcknowledgment)
                signatureLine("Supervisor Statement", doc.signatureSection.supervisorStatement)
                signatureLine("HR Review", doc.signatureSection.hrReviewStatement)
            }
            .padding()
            .background(innerCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    // MARK: - Escalation Document View
    private func escalationDocumentView(_ doc: EscalationDocument) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            documentTitle(doc.title)
            
            // Urgency badge
            HStack {
                Text("Urgency: \(doc.urgencyLevel)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(doc.urgencyLevel == "Urgent" ? Color.red : (doc.urgencyLevel == "High" ? Color.orange : Color.blue))
                    .clipShape(Capsule())
                
                Spacer()
                
                Text("Prepared by: \(doc.preparedBy)")
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
            }
            
            // Case Summary
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Case Summary")
                
                summaryRow("Case Number", doc.caseSummary.caseNumber)
                summaryRow("Type", doc.caseSummary.caseType)
                summaryRow("Incident Date", doc.caseSummary.incidentDate)
                summaryRow("Location", doc.caseSummary.location)
                summaryRow("Department", doc.caseSummary.department)
            }
            .padding()
            .background(innerCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Involved Parties
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Involved Parties")
                
                ForEach(doc.involvedParties, id: \.name) { party in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(party.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(textPrimary)
                            Text("(\(party.role))")
                                .font(.system(size: 12))
                                .foregroundColor(textSecondary)
                        }
                        Text(party.summary)
                            .font(.system(size: 13))
                            .foregroundColor(textSecondary)
                    }
                    .padding()
                    .background(innerCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            // Timeline
            if !doc.incidentTimeline.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Incident Timeline")
                    
                    ForEach(doc.incidentTimeline, id: \.date) { event in
                        HStack(alignment: .top, spacing: 12) {
                            Text(event.date)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.blue)
                                .frame(width: 80, alignment: .leading)
                            
                            Text(event.event)
                                .font(.system(size: 13))
                                .foregroundColor(textSecondary)
                        }
                    }
                }
                .padding()
                .background(innerCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // Evidence Summary
            listSection(title: "Evidence Summary", items: doc.evidenceSummary)
            
            // Policy References
            if !doc.policyReferences.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Policy References")
                    
                    ForEach(doc.policyReferences, id: \.section) { ref in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ref.section)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(textPrimary)
                            Text(ref.relevance)
                                .font(.system(size: 12))
                                .foregroundColor(textSecondary)
                        }
                    }
                }
                .padding()
                .background(innerCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // Analysis Findings
            listSection(title: "Analysis Findings", items: doc.analysisFindings)
            
            // Supervisor Notes
            documentSection(title: "Supervisor Notes", content: doc.supervisorNotes)
            
            // Recommended Actions
            listSection(title: "Recommended Actions", items: doc.recommendedActions)
            
            // Requested HR Actions
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Requested HR Actions")
                
                ForEach(doc.requestedHRActions, id: \.self) { action in
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                        Text(action)
                            .font(.system(size: 13))
                            .foregroundColor(textPrimary)
                    }
                }
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    // MARK: - Helper Views
    
    private func documentTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(textPrimary)
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(textPrimary)
    }
    
    private func documentSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title)
            Text(content)
                .font(.system(size: 13))
                .foregroundColor(textSecondary)
                .lineSpacing(4)
        }
        .padding()
        .background(innerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func listSection(title: String, items: [String], color: Color = .blue) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title)
            
            ForEach(items, id: \.self) { item in
                bulletPoint(item, color: color)
            }
        }
        .padding()
        .background(innerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func bulletPoint(_ text: String, color: Color = .blue) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(textSecondary)
        }
    }
    
    private func labeledText(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(textSecondary)
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(textPrimary)
        }
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
    
    private func signatureLine(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(textPrimary)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(textSecondary)
                .italic()
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
                .padding(.top, 8)
            
            Text("Signature / Date")
                .font(.system(size: 10))
                .foregroundColor(textSecondary)
        }
    }
    
    // MARK: - Generate Document
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
        
        // Map recommendation type to action type
        let actionType: ActionType
        switch selectedRecommendation.type {
        case .coaching: actionType = .coaching
        case .counseling: actionType = .counseling
        case .warning: actionType = .warning
        case .escalate: actionType = .escalate
        }
        
        isGenerating = true
        errorMessage = nil
        
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
                    supervisorName: nil
                )
                
                await MainActor.run {
                    self.generatedResult = result
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isGenerating = false
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        ActionGenerationView(
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
            onDocumentGenerated: { _ in },
            onBack: {}
        )
    }
}
