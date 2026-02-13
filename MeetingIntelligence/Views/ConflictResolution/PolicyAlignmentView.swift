//
//  PolicyAlignmentView.swift
//  MeetingIntelligence
//
//  Phase 6: Policy Alignment
//  Shows which policy sections may be relevant to the case
//

import SwiftUI

struct PolicyAlignmentView: View {
    let conflictCase: ConflictCase
    let policy: WorkplacePolicy?
    let analysisResult: AIComparisonResult?
    @Binding var autoRun: Bool
    let onPolicyMatched: ([PolicyMatchResult]) -> Void
    let onRunPolicyMatch: () -> Void
    let onSkip: () -> Void
    
    @State private var policyMatchResult: PolicyMatchingResult?
    @State private var isMatching = false
    @State private var matchingError: String?
    @State private var expandedMatchId: UUID?
    @State private var loadingProgress: CGFloat = 0
    @State private var loadingStage: String = "Initializing..."
    
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
            
            if policy == nil {
                // No policy available
                noPolicySection
            } else if isMatching {
                // Loading state
                matchingLoadingSection
            } else if let error = matchingError {
                // Error state
                errorSection(error)
            } else if let result = policyMatchResult {
                // Results
                resultsSection(result)
            } else {
                // Ready to match
                readyToMatchSection
            }
            
            // Action Buttons
            actionButtons
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            // Auto-run if triggered by re-analysis
            if autoRun && policy != nil && policyMatchResult == nil {
                autoRun = false
                runPolicyMatching()
            }
        }
        .onChange(of: autoRun) { newValue in
            if newValue && policy != nil && !isMatching {
                autoRun = false
                runPolicyMatching()
            }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(.purple)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Policy Alignment")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    Text("Identify relevant policy sections")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - No Policy Section
    private var noPolicySection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.orange)
            }
            
            Text("No Policy Linked")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Text("Link a workplace policy to this case to enable policy alignment analysis.")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Matching Loading Section
    private var matchingLoadingSection: some View {
        VStack(spacing: 24) {
            // Animated circular progress
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.purple.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                // Animated progress circle
                Circle()
                    .trim(from: 0, to: loadingProgress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.purple, .purple.opacity(0.3)]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                // Spinning dots
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 8, height: 8)
                        .offset(y: -40)
                        .rotationEffect(.degrees(Double(index) * 120 + loadingProgress * 360))
                }
                
                // Center icon
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 24))
                    .foregroundColor(.purple)
                    .opacity(0.8 + 0.2 * sin(loadingProgress * .pi * 4))
            }
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    loadingProgress = 1.0
                }
            }
            
            VStack(spacing: 8) {
                Text("Analyzing Policy Relevance")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Text(loadingStage)
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
            
            // Loading stages indicator
            HStack(spacing: 8) {
                ForEach(0..<4) { index in
                    Capsule()
                        .fill(index <= Int(loadingProgress * 4) ? Color.purple : Color.purple.opacity(0.2))
                        .frame(width: 24, height: 4)
                }
            }
        }
        .padding(.vertical, 32)
        .onAppear {
            animateLoadingStages()
        }
    }
    
    private func animateLoadingStages() {
        let stages = [
            "Reading case documents...",
            "Extracting key terms...",
            "Matching policy sections...",
            "Generating recommendations..."
        ]
        
        for (index, stage) in stages.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 1.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    loadingStage = stage
                }
            }
        }
    }
    
    private func animationScale(for index: Int) -> CGFloat {
        isMatching ? 1.3 : 1.0
    }
    
    // MARK: - Error Section
    private func errorSection(_ error: String) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.red)
            }
            
            Text("Matching Failed")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            Button {
                matchingError = nil
            } label: {
                Text("Try Again")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.purple)
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Ready to Match Section
    private var readyToMatchSection: some View {
        VStack(spacing: 16) {
            if let policy = policy {
                // Policy info
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.purple.opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.purple)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(policy.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(textPrimary)
                            .lineLimit(1)
                        
                        Text("\(policy.sections.count) sections available")
                            .font(.system(size: 12))
                            .foregroundColor(textSecondary)
                    }
                    
                    Spacer()
                    
                    // Status badge
                    if policy.status == .active {
                        Text("Active")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .padding(12)
                .background(innerCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Text("Run policy matching to identify which sections of your workplace policy may be relevant to this case.")
                .font(.system(size: 13))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Results Section
    private func resultsSection(_ result: PolicyMatchingResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Match count summary
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("\(result.matches.count)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.purple)
                    Text("Relevant")
                        .font(.system(size: 11))
                        .foregroundColor(textSecondary)
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack(spacing: 4) {
                    Text("\(result.highConfidenceMatches.count)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.green)
                    Text("High")
                        .font(.system(size: 11))
                        .foregroundColor(textSecondary)
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack(spacing: 4) {
                    Text("\(result.moderateConfidenceMatches.count)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.orange)
                    Text("Moderate")
                        .font(.system(size: 11))
                        .foregroundColor(textSecondary)
                }
            }
            .padding(.horizontal, 8)
            
            // Matched sections
            if result.hasMatches {
                VStack(spacing: 12) {
                    ForEach(result.matches) { match in
                        matchCard(match)
                    }
                }
            } else {
                noMatchesFound
            }
            
            // Overall guidance
            if !result.overallGuidance.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.yellow)
                        
                        Text("Supervisor Guidance")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(textPrimary)
                    }
                    
                    Text(result.overallGuidance)
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Match Card
    private func matchCard(_ match: PolicyMatchResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (always visible)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedMatchId == match.id {
                        expandedMatchId = nil
                    } else {
                        expandedMatchId = match.id
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    // Top row: Section number + Confidence badge
                    HStack {
                        Text("Section \(match.sectionNumber)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(textSecondary)
                        
                        Spacer()
                        
                        // Confidence badge
                        Text(match.confidenceLevel.label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(confidenceColor(for: match))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(confidenceColor(for: match).opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    // Section title row
                    HStack(alignment: .top, spacing: 10) {
                        // Confidence indicator dot
                        Circle()
                            .fill(confidenceColor(for: match))
                            .frame(width: 10, height: 10)
                            .padding(.top, 4)
                        
                        Text(match.sectionTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(textPrimary)
                            .lineLimit(expandedMatchId == match.id ? nil : 3)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Image(systemName: expandedMatchId == match.id ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(textSecondary)
                            .padding(.top, 4)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded content
            if expandedMatchId == match.id {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Relevance explanation
                    Text(match.relevanceExplanation)
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Key phrases - displayed as wrapped text items
                    if !match.keyPhrases.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Key Phrases")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(textSecondary)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(match.keyPhrases, id: \.self) { phrase in
                                    Text(phrase)
                                        .font(.system(size: 12))
                                        .foregroundColor(.purple)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.purple.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    
                    // Confidence percentage
                    HStack {
                        Text("Relevance Score")
                            .font(.system(size: 11))
                            .foregroundColor(textSecondary)
                        
                        Spacer()
                        
                        Text("\(Int(match.matchConfidence * 100))%")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(confidenceColor(for: match))
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(innerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func confidenceColor(for match: PolicyMatchResult) -> Color {
        switch match.confidenceLevel {
        case .high: return .green
        case .moderate: return .orange
        case .low: return .gray
        }
    }
    
    // MARK: - No Matches Found
    private var noMatchesFound: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.green)
            
            Text("No Direct Policy Matches")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(textPrimary)
            
            Text("The System did not find policy sections directly relevant to this case. This doesn't mean no policies apply - use your professional judgment.")
                .font(.system(size: 13))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if policyMatchResult == nil && policy != nil && !isMatching {
                // Run matching button
                Button {
                    runPolicyMatching()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                        Text("Check Policy Alignment")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            if policyMatchResult != nil {
                // Re-run button
                Button {
                    policyMatchResult = nil
                    runPolicyMatching()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                        Text("Re-analyze Policies")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.purple)
                }
            }
            
            // Skip button (always available)
            Button {
                onSkip()
            } label: {
                Text(policyMatchResult != nil ? "Continue" : "Skip for Now")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textSecondary)
            }
        }
    }
    
    // MARK: - Run Policy Matching
    private func runPolicyMatching() {
        guard let policy = policy else { return }
        
        // Get complaints (both complaint A and B)
        let complaintA = conflictCase.documents.first { $0.type == .complaintA }
        let complaintB = conflictCase.documents.first { $0.type == .complaintB }
        
        guard let docA = complaintA, let docB = complaintB else {
            matchingError = "Need both complaints to run policy matching"
            return
        }
        
        // Get employees for complaints
        let employees = conflictCase.involvedEmployees.filter { $0.isComplainant }
        guard employees.count >= 2 else {
            matchingError = "Need involved employees to run policy matching"
            return
        }
        
        // Get witness statements
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
        
        // Get prior history document summaries for policy matching context
        let priorHistoryContext = conflictCase.documents
            .filter { $0.type == .priorRecord || $0.type == .counselingRecord || $0.type == .warningDocument }
            .map { doc in
                let text = doc.cleanedText.isEmpty ? (doc.translatedText ?? doc.originalText) : doc.cleanedText
                return "[\(doc.type.displayName)]: \(text.prefix(200))"
            }
            .joined(separator: "\n")
        
        isMatching = true
        matchingError = nil
        loadingProgress = 0
        loadingStage = "Initializing..."
        
        Task {
            do {
                let result = try await PolicyMatchingService.shared.matchPolicies(
                    conflictCase: conflictCase,
                    complaintA: docA,
                    complaintAEmployee: employees[0],
                    complaintB: docB,
                    complaintBEmployee: employees[1],
                    analysisResult: analysisResult,
                    witnessStatements: witnessStatements,
                    policySections: policy.sections,
                    priorHistoryContext: priorHistoryContext.isEmpty ? nil : priorHistoryContext
                )
                
                await MainActor.run {
                    self.policyMatchResult = result
                    self.isMatching = false
                    self.loadingProgress = 0
                    // Call callback with results
                    self.onPolicyMatched(result.matches)
                }
            } catch {
                await MainActor.run {
                    self.matchingError = error.localizedDescription
                    self.isMatching = false
                    self.loadingProgress = 0
                }
            }
        }
    }
}

// MARK: - Flow Layout for Tags (Renamed to avoid conflict with SummaryTab)
struct PolicyFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = PolicyFlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = PolicyFlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }
    
    struct PolicyFlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
                
                self.size.width = max(self.size.width, currentX)
            }
            
            self.size.height = currentY + lineHeight
        }
    }
}

// MARK: - Preview
#Preview {
    @Previewable @State var autoRun = false
    
    PolicyAlignmentView(
        conflictCase: ConflictCase(
            id: UUID(),
            caseNumber: "CR-2025-001",
            type: .conflict,
            status: .inProgress,
            incidentDate: Date(),
            location: "Building A - Floor 3",
            department: "Engineering",
            involvedEmployees: [],
            documents: [],
            comparisonResult: nil,
            policyMatches: [],
            recommendations: [],
            createdBy: ""
        ),
        policy: nil,
        analysisResult: nil,
        autoRun: $autoRun,
        onPolicyMatched: { _ in },
        onRunPolicyMatch: {},
        onSkip: {}
    )
    .padding()
    .background(Color.gray.opacity(0.1))
}
