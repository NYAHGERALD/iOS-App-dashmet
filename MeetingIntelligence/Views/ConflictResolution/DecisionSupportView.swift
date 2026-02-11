//
//  DecisionSupportView.swift
//  MeetingIntelligence
//
//  Phase 7: Decision Support
//  AI-powered recommendations for resolving workplace conflicts
//

import SwiftUI

struct DecisionSupportView: View {
    let conflictCase: ConflictCase
    let analysisResult: AIComparisonResult?
    let policyMatches: [PolicyMatchResult]?
    let onSelectRecommendation: (RecommendationOption) -> Void
    let onSkip: () -> Void
    
    @State private var recommendationResult: RecommendationResult?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedRecommendation: RecommendationOption?
    @State private var expandedOptionId: String?
    @State private var showConfirmation = false
    
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
        VStack(spacing: 20) {
            // Header
            headerSection
            
            if isLoading {
                loadingSection
            } else if let error = errorMessage {
                errorSection(error)
            } else if let result = recommendationResult {
                recommendationsSection(result)
            } else {
                readySection
            }
            
            // Action Buttons
            actionButtons
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showConfirmation) {
            if let recommendation = selectedRecommendation {
                confirmationSheet(recommendation)
            }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.indigo.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "lightbulb.max.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.indigo)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Decision Support")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    Text("System-powered action recommendations")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Loading Section
    private var loadingSection: some View {
        VStack(spacing: 20) {
            // Thinking animation
            HStack(spacing: 8) {
                ForEach(0..<4) { index in
                    Circle()
                        .fill(Color.indigo.opacity(0.6))
                        .frame(width: 10, height: 10)
                        .offset(y: animationOffset(for: index))
                        .animation(
                            Animation.easeInOut(duration: 0.5)
                                .repeatForever()
                                .delay(Double(index) * 0.15),
                            value: isLoading
                        )
                }
            }
            .padding(.top, 16)
            
            Text("Analyzing Case Details...")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(textPrimary)
            
            Text("Our System is evaluating all evidence to generate appropriate recommendations")
                .font(.system(size: 13))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 24)
    }
    
    private func animationOffset(for index: Int) -> CGFloat {
        isLoading ? -8 : 0
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
            
            Text("Analysis Failed")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                errorMessage = nil
            } label: {
                Text("Try Again")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.indigo)
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Ready Section
    private var readySection: some View {
        VStack(spacing: 16) {
            // Info cards
            HStack(spacing: 12) {
                infoCard(icon: "doc.text.fill", title: "Complaints", value: "2", color: .blue)
                infoCard(icon: "chart.bar.fill", title: "Analysis", 
                         value: analysisResult != nil ? "✓" : "—", 
                         color: analysisResult != nil ? .green : .gray)
                infoCard(icon: "doc.badge.gearshape.fill", title: "Policies", 
                         value: "\(policyMatches?.count ?? 0)", 
                         color: .purple)
            }
            
            Text("Ready to generate System recommendations based on all available case data.")
                .font(.system(size: 13))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
            
            // Disclaimer
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                
                Text("You make the final decision. System provides options only.")
                    .font(.system(size: 12))
                    .foregroundColor(textSecondary)
            }
            .padding(12)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private func infoCard(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(textPrimary)
            
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(innerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Recommendations Section
    private func recommendationsSection(_ result: RecommendationResult) -> some View {
        VStack(spacing: 16) {
            // Options
            ForEach(result.recommendations) { option in
                recommendationCard(option, isPrimary: option.id == result.primaryRecommendationId)
            }
            
            // Supervisor Guidance
            if !result.supervisorGuidance.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 14))
                            .foregroundColor(.indigo)
                        
                        Text("Supervisor Guidance")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(textPrimary)
                    }
                    
                    Text(result.supervisorGuidance)
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                        .lineSpacing(4)
                }
                .padding(12)
                .background(Color.indigo.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Recommendation Card
    private func recommendationCard(_ option: RecommendationOption, isPrimary: Bool) -> some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedOptionId == option.id {
                        expandedOptionId = nil
                    } else {
                        expandedOptionId = option.id
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    // Option letter badge
                    ZStack {
                        Circle()
                            .fill(typeColor(for: option.type).opacity(0.15))
                            .frame(width: 36, height: 36)
                        
                        Text(option.optionLetter)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(typeColor(for: option.type))
                    }
                    
                    // Title and type
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(option.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(textPrimary)
                                .lineLimit(1)
                            
                            if isPrimary {
                                Text("Recommended")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.indigo)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Text(option.type.displayName)
                            .font(.system(size: 11))
                            .foregroundColor(textSecondary)
                    }
                    
                    Spacer()
                    
                    // Risk badge
                    Text(option.riskLevel.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(riskColor(for: option.riskLevel))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(riskColor(for: option.riskLevel).opacity(0.15))
                        .clipShape(Capsule())
                    
                    Image(systemName: expandedOptionId == option.id ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textSecondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded content
            if expandedOptionId == option.id {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Description
                    Text(option.description)
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                    
                    // Rationale
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Why This Option?")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(textPrimary)
                        
                        Text(option.rationale)
                            .font(.system(size: 13))
                            .foregroundColor(textSecondary)
                            .lineSpacing(4)
                    }
                    
                    // Risk explanation
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 14))
                            .foregroundColor(riskColor(for: option.riskLevel))
                        
                        Text(option.riskExplanation)
                            .font(.system(size: 12))
                            .foregroundColor(textSecondary)
                    }
                    .padding(10)
                    .background(riskColor(for: option.riskLevel).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Next steps
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Next Steps")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(textPrimary)
                        
                        ForEach(Array(option.nextSteps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.indigo)
                                    .frame(width: 16)
                                
                                Text(step)
                                    .font(.system(size: 12))
                                    .foregroundColor(textSecondary)
                            }
                        }
                    }
                    
                    // Timeframe and confidence
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            Text(option.timeframe)
                                .font(.system(size: 11))
                                .foregroundColor(textSecondary)
                        }
                        
                        Spacer()
                        
                        Text(option.confidenceLabel)
                            .font(.system(size: 11))
                            .foregroundColor(.indigo)
                    }
                    
                    // Select button
                    Button {
                        selectedRecommendation = option
                        showConfirmation = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Select This Option")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(typeColor(for: option.type))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(innerCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isPrimary ? Color.indigo.opacity(0.3) : Color.clear, lineWidth: 2)
                )
        )
    }
    
    // MARK: - Confirmation Sheet
    private func confirmationSheet(_ option: RecommendationOption) -> some View {
        NavigationView {
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(typeColor(for: option.type).opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: option.type.icon)
                        .font(.system(size: 36))
                        .foregroundColor(typeColor(for: option.type))
                }
                .padding(.top, 20)
                
                // Title
                VStack(spacing: 8) {
                    Text("Confirm Selection")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(textPrimary)
                    
                    Text("You selected: \(option.title)")
                        .font(.system(size: 15))
                        .foregroundColor(textSecondary)
                }
                
                // Summary
                VStack(alignment: .leading, spacing: 12) {
                    summaryRow(label: "Action Type", value: option.type.displayName)
                    summaryRow(label: "Risk Level", value: option.riskLevel.displayName)
                    summaryRow(label: "Timeframe", value: option.timeframe)
                }
                .padding()
                .background(innerCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Disclaimer
                Text("This will proceed to the next step where you can review and edit the generated documentation.")
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                // Buttons
                VStack(spacing: 12) {
                    Button {
                        showConfirmation = false
                        onSelectRecommendation(option)
                    } label: {
                        Text("Confirm & Continue")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(typeColor(for: option.type))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button {
                        showConfirmation = false
                    } label: {
                        Text("Go Back")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(textSecondary)
                    }
                }
                .padding(.bottom, 20)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showConfirmation = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
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
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if recommendationResult == nil && !isLoading {
                // Generate recommendations button
                Button {
                    generateRecommendations()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                        Text("Get System Recommendations")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            if recommendationResult != nil {
                // Regenerate button
                Button {
                    recommendationResult = nil
                    generateRecommendations()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                        Text("Regenerate Options")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.indigo)
                }
            }
            
            // Skip button
            Button {
                onSkip()
            } label: {
                Text(recommendationResult != nil ? "Decide Later" : "Skip for Now")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textSecondary)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func typeColor(for type: RecommendationType) -> Color {
        switch type {
        case .coaching: return .green
        case .counseling: return .blue
        case .warning: return .orange
        case .escalate: return .red
        }
    }
    
    private func riskColor(for level: RiskLevel) -> Color {
        switch level {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    // MARK: - Generate Recommendations
    private func generateRecommendations() {
        // Get complaints
        let complaintA = conflictCase.documents.first { $0.type == .complaintA }
        let complaintB = conflictCase.documents.first { $0.type == .complaintB }
        
        guard let docA = complaintA, let docB = complaintB else {
            errorMessage = "Need both complaints to generate recommendations"
            return
        }
        
        // Get employees for complaints
        let employees = conflictCase.involvedEmployees.filter { $0.isComplainant }
        guard employees.count >= 2 else {
            errorMessage = "Need involved employees to generate recommendations"
            return
        }
        
        // Get witness statements from case documents and convert to WitnessStatementInput
        let witnessStatements: [WitnessStatementInput] = conflictCase.documents
            .filter { $0.type == .witnessStatement && (!$0.cleanedText.isEmpty || !$0.originalText.isEmpty) }
            .compactMap { doc in
                if let employeeId = doc.employeeId,
                   let witness = conflictCase.involvedEmployees.first(where: { $0.id == employeeId }) {
                    let text = doc.cleanedText.isEmpty ? doc.originalText : doc.cleanedText
                    return WitnessStatementInput(witnessName: witness.name, text: text)
                }
                return nil
            }
        
        // Build prior history info from case documents
        let hasPriorComplaints = conflictCase.documents.contains { $0.type == .priorRecord }
        let hasPriorCounseling = conflictCase.documents.contains { $0.type == .counselingRecord }
        let hasPriorWarnings = conflictCase.documents.contains { $0.type == .warningDocument }
        
        // Build notes from prior history documents
        var priorHistoryNotes: [String] = []
        if hasPriorComplaints {
            let priorDocs = conflictCase.documents.filter { $0.type == .priorRecord }
            for doc in priorDocs {
                let text = doc.cleanedText.isEmpty ? doc.originalText : doc.cleanedText
                if !text.isEmpty {
                    priorHistoryNotes.append("Prior complaint: \(text.prefix(200))...")
                }
            }
        }
        if hasPriorCounseling {
            let counselingDocs = conflictCase.documents.filter { $0.type == .counselingRecord }
            for doc in counselingDocs {
                let text = doc.cleanedText.isEmpty ? doc.originalText : doc.cleanedText
                if !text.isEmpty {
                    priorHistoryNotes.append("Counseling record: \(text.prefix(200))...")
                }
            }
        }
        if hasPriorWarnings {
            let warningDocs = conflictCase.documents.filter { $0.type == .warningDocument }
            for doc in warningDocs {
                let text = doc.cleanedText.isEmpty ? doc.originalText : doc.cleanedText
                if !text.isEmpty {
                    priorHistoryNotes.append("Warning: \(text.prefix(200))...")
                }
            }
        }
        
        let priorHistory: PriorHistoryInfo? = (hasPriorComplaints || hasPriorCounseling || hasPriorWarnings) ?
            PriorHistoryInfo(
                hasPriorComplaints: hasPriorComplaints,
                hasPriorCounseling: hasPriorCounseling,
                hasPriorWarnings: hasPriorWarnings,
                notes: priorHistoryNotes.isEmpty ? nil : priorHistoryNotes.joined(separator: "\n")
            ) : nil
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await RecommendationService.shared.getRecommendations(
                    conflictCase: conflictCase,
                    complaintA: docA,
                    complaintAEmployee: employees[0],
                    complaintB: docB,
                    complaintBEmployee: employees[1],
                    analysisResult: analysisResult,
                    policyMatches: policyMatches,
                    witnessStatements: witnessStatements,
                    priorHistory: priorHistory
                )
                
                await MainActor.run {
                    self.recommendationResult = result
                    self.isLoading = false
                    // Auto-expand primary recommendation
                    self.expandedOptionId = result.primaryRecommendationId
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    DecisionSupportView(
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
        analysisResult: nil,
        policyMatches: nil,
        onSelectRecommendation: { _ in },
        onSkip: {}
    )
    .padding()
    .background(Color.gray.opacity(0.1))
}
