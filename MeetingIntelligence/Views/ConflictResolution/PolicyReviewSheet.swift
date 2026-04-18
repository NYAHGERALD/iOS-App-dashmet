//
//  PolicyReviewSheet.swift
//  MeetingIntelligence
//
//  Review Active Policy — select sections to add to Policy Alignment
//  with AI-driven relevance validation before adding
//

import SwiftUI

struct PolicyReviewSheet: View {
    let policy: WorkplacePolicy
    let existingMatches: [PolicyMatchResult]
    let conflictCase: ConflictCase
    let analysisResult: AIComparisonResult?
    let onAddSections: ([PolicyMatchResult]) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var searchText = ""
    @State private var selectedIds: Set<UUID> = []
    
    // AI validation states
    @State private var isValidating = false
    @State private var validationStep = 0
    @State private var validationResults: [PolicyMatchResult]?
    @State private var showResults = false
    @State private var validationError: String?
    
    private let validationSteps = [
        "Reading selected sections...",
        "Analyzing case evidence...",
        "Matching against complaints...",
        "Evaluating relevance...",
        "Generating assessment..."
    ]
    
    private var matchedSectionIds: Set<UUID> {
        Set(existingMatches.map { $0.sectionId })
    }
    
    private func matchLevel(for section: PolicySection) -> PolicyMatchResult.ConfidenceLevel? {
        if let match = existingMatches.first(where: { $0.sectionId == section.id || $0.sectionNumber == section.sectionNumber }) {
            return match.confidenceLevel
        }
        return nil
    }
    
    private var filteredSections: [PolicySection] {
        let sections = policy.sections
        if searchText.isEmpty { return sections }
        let q = searchText.lowercased()
        return sections.filter {
            $0.sectionNumber.lowercased().contains(q) ||
            $0.title.lowercased().contains(q) ||
            $0.content.lowercased().contains(q) ||
            ($0.firstProgression ?? "").lowercased().contains(q) ||
            ($0.secondProgression ?? "").lowercased().contains(q) ||
            ($0.thirdProgression ?? "").lowercased().contains(q) ||
            ($0.fourthProgression ?? "").lowercased().contains(q)
        }
    }
    
    private var selectableSections: [PolicySection] {
        filteredSections.filter { !isAlreadyMatched($0) }
    }
    
    private func isAlreadyMatched(_ section: PolicySection) -> Bool {
        matchedSectionIds.contains(section.id) ||
        existingMatches.contains(where: { $0.sectionNumber == section.sectionNumber })
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                VStack(spacing: 0) {
                    // Search bar
                    searchBar
                    
                    // Table
                    if isValidating {
                        validatingView
                    } else if showResults, let results = validationResults {
                        resultsView(results)
                    } else {
                        sectionsList
                    }
                    
                    // Footer
                    if !isValidating && !showResults {
                        footerBar
                    }
                }
            }
            .navigationTitle(policy.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !selectedIds.isEmpty && !isValidating && !showResults {
                        Button {
                            handleAddSelected()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Add (\(selectedIds.count))")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .clipShape(Capsule())
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if !isValidating {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.gray)
            TextField("Search sections, content, violations...", text: $searchText)
                .font(.system(size: 14))
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    // MARK: - Sections List
    
    private var sectionsList: some View {
        List {
            ForEach(filteredSections) { section in
                let matched = isAlreadyMatched(section)
                let level = matchLevel(for: section)
                let isSelected = selectedIds.contains(section.id)
                
                Button {
                    if !matched {
                        if isSelected {
                            selectedIds.remove(section.id)
                        } else {
                            selectedIds.insert(section.id)
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        // Checkbox or matched indicator
                        if matched {
                            // No checkbox for already-matched
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(matchedBadgeColor(level).opacity(0.2))
                                    .frame(width: 22, height: 22)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(matchedBadgeColor(level))
                            }
                        } else {
                            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                .font(.system(size: 20))
                                .foregroundColor(isSelected ? .blue : .gray.opacity(0.4))
                        }
                        
                        // Section number + badge
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(section.sectionNumber)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(matched && level == .low ? .gray : .primary)
                                
                                if matched {
                                    Text(matchedBadgeLabel(level))
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(matchedBadgeColor(level))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(matchedBadgeColor(level).opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                            
                            Text(section.title)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .frame(width: 80, alignment: .leading)
                        
                        // Policy content
                        Text(section.content)
                            .font(.system(size: 13))
                            .foregroundColor(matched && level == .low ? .gray : .primary)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        // 1st violation
                        Text(section.firstProgression ?? "—")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 70, alignment: .leading)
                            .lineLimit(1)
                    }
                }
                .listRowBackground(
                    matched
                        ? matchedRowColor(level)
                        : isSelected
                        ? Color.blue.opacity(0.08)
                        : Color.clear
                )
                .disabled(matched)
                .opacity(matched && level == .low ? 0.6 : 1.0)
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Footer
    
    private var footerBar: some View {
        HStack {
            Text("\(filteredSections.count) sections • \(selectedIds.count) selected")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Spacer()
            
            if !selectedIds.isEmpty {
                Button {
                    handleAddSelected()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Add Selected to Policy Alignment")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) {
            Divider()
        }
    }
    
    // MARK: - AI Validation Loading
    
    private var validatingView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.purple.opacity(0.2), lineWidth: 5)
                    .frame(width: 90, height: 90)
                
                Circle()
                    .trim(from: 0, to: CGFloat(validationStep + 1) / CGFloat(validationSteps.count))
                    .stroke(Color.purple, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: validationStep)
                
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundColor(.purple)
            }
            
            VStack(spacing: 8) {
                Text("Analyzing Relevance")
                    .font(.system(size: 18, weight: .bold))
                
                Text("Checking \(selectedIds.count) section\(selectedIds.count != 1 ? "s" : "") against case evidence")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            // Step checklist
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(validationSteps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 12) {
                        if index < validationStep {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 18))
                        } else if index == validationStep {
                            ProgressView()
                                .frame(width: 18, height: 18)
                        } else {
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                .frame(width: 18, height: 18)
                        }
                        
                        Text(step)
                            .font(.system(size: 14, weight: index <= validationStep ? .medium : .regular))
                            .foregroundColor(index <= validationStep ? .primary : .secondary)
                    }
                }
            }
            .frame(width: 260, alignment: .leading)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Results View
    
    private func resultsView(_ results: [PolicyMatchResult]) -> some View {
        VStack(spacing: 0) {
            // Results header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.purple)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Relevance Analysis Complete")
                        .font(.system(size: 15, weight: .bold))
                    Text("\(results.filter { $0.matchConfidence >= 0.5 }.count) of \(results.count) section\(results.count != 1 ? "s" : "") found relevant")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color(.systemGray6))
            
            // Results list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(results) { match in
                        resultCard(match)
                    }
                }
                .padding(16)
            }
            
            // Results footer
            resultsFooter(results)
        }
    }
    
    private func resultCard(_ match: PolicyMatchResult) -> some View {
        let conf = match.matchConfidence
        let isRelevant = conf >= 0.5
        let level = conf >= 0.8 ? "High Relevance" : conf >= 0.65 ? "Moderate Relevance" : conf >= 0.5 ? "Low Relevance" : "Not Relevant"
        let badgeColor: Color = conf >= 0.8 ? .green : conf >= 0.65 ? .orange : conf >= 0.5 ? .yellow : .red
        
        return VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack {
                if !isRelevant {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                Text("Section \(match.sectionNumber)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(level)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(badgeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badgeColor.opacity(0.15))
                    .clipShape(Capsule())
                
                Text("\(Int(conf * 100))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isRelevant ? .green : .red)
            }
            
            // Title
            Text(match.sectionTitle)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(2)
            
            // Explanation
            Text(match.relevanceExplanation)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineSpacing(3)
            
            // Key phrases
            if !match.keyPhrases.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(match.keyPhrases, id: \.self) { phrase in
                            Text(phrase)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            // Not relevant warning
            if !isRelevant {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                    Text("This section may not be relevant to this case")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(!isRelevant ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    private func resultsFooter(_ results: [PolicyMatchResult]) -> some View {
        HStack {
            if results.contains(where: { $0.matchConfidence < 0.5 }) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    Text("Some sections have low relevance")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                Button {
                    showResults = false
                    validationResults = nil
                } label: {
                    Text("Decline")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                Button {
                    if let results = validationResults {
                        onAddSections(results)
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                        Text("Accept & Add All")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) {
            Divider()
        }
    }
    
    // MARK: - Actions
    
    private func handleAddSelected() {
        guard !selectedIds.isEmpty else { return }
        
        let selectedSections = policy.sections.filter { selectedIds.contains($0.id) }
        guard !selectedSections.isEmpty else { return }
        
        // Start AI validation
        isValidating = true
        validationStep = 0
        showResults = false
        validationResults = nil
        validationError = nil
        
        // Animate steps
        let stepTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { timer in
            if validationStep < validationSteps.count - 1 {
                withAnimation { validationStep += 1 }
            } else {
                timer.invalidate()
            }
        }
        
        // Run AI analysis
        Task {
            do {
                let complaintA = conflictCase.documents.first { $0.type == .complaintA }
                let complaintB = conflictCase.documents.first { $0.type == .complaintB }
                let employees = conflictCase.involvedEmployees.filter { $0.isComplainant }
                
                guard let docA = complaintA, let docB = complaintB, employees.count >= 2 else {
                    throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing complaint documents or employees"])
                }
                
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
                
                let result = try await PolicyMatchingService.shared.matchPolicies(
                    conflictCase: conflictCase,
                    complaintA: docA,
                    complaintAEmployee: employees[0],
                    complaintB: docB,
                    complaintBEmployee: employees[1],
                    analysisResult: analysisResult,
                    witnessStatements: witnessStatements,
                    policySections: selectedSections
                )
                
                await MainActor.run {
                    stepTimer.invalidate()
                    
                    // Filter to only selected sections
                    let selectedSectionIds = Set(selectedSections.map { $0.id })
                    let selectedSectionNumbers = Set(selectedSections.map { $0.sectionNumber })
                    var aiMatches = result.matches.filter {
                        selectedSectionIds.contains($0.sectionId) || selectedSectionNumbers.contains($0.sectionNumber)
                    }
                    
                    // Map sectionTitle to content
                    aiMatches = aiMatches.map { m in
                        let content = selectedSections.first(where: { $0.id == m.sectionId })?.content ?? m.sectionTitle
                        return PolicyMatchResult(
                            id: m.id,
                            sectionId: m.sectionId,
                            sectionNumber: m.sectionNumber,
                            sectionTitle: content,
                            relevanceExplanation: m.relevanceExplanation,
                            matchConfidence: m.matchConfidence,
                            keyPhrases: m.keyPhrases
                        )
                    }
                    
                    // Add fallback entries for sections AI didn't return
                    let returnedIds = Set(aiMatches.map { $0.sectionId })
                    let returnedNumbers = Set(aiMatches.map { $0.sectionNumber })
                    for section in selectedSections {
                        if !returnedIds.contains(section.id) && !returnedNumbers.contains(section.sectionNumber) {
                            aiMatches.append(PolicyMatchResult(
                                sectionId: section.id,
                                sectionNumber: section.sectionNumber,
                                sectionTitle: section.content,
                                relevanceExplanation: "This section does not appear to be directly relevant to the behaviors described in the complaint statements or witness accounts for this case.",
                                matchConfidence: 0.2,
                                keyPhrases: []
                            ))
                        }
                    }
                    
                    // Fast-forward remaining steps
                    fastForwardSteps {
                        validationResults = aiMatches
                        isValidating = false
                        showResults = true
                    }
                }
            } catch {
                await MainActor.run {
                    stepTimer.invalidate()
                    
                    // Fallback entries
                    let fallback = selectedSections.map { section in
                        PolicyMatchResult(
                            sectionId: section.id,
                            sectionNumber: section.sectionNumber,
                            sectionTitle: section.content,
                            relevanceExplanation: "AI analysis could not be completed. You may still add this section based on your professional judgment.",
                            matchConfidence: 0.5,
                            keyPhrases: []
                        )
                    }
                    
                    fastForwardSteps {
                        validationResults = fallback
                        isValidating = false
                        showResults = true
                    }
                }
            }
        }
    }
    
    private func fastForwardSteps(completion: @escaping () -> Void) {
        func advance(step: Int) {
            if step < validationSteps.count {
                withAnimation { validationStep = step }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    advance(step: step + 1)
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    completion()
                }
            }
        }
        advance(step: validationStep + 1)
    }
    
    // MARK: - Helpers
    
    private func matchedBadgeColor(_ level: PolicyMatchResult.ConfidenceLevel?) -> Color {
        switch level {
        case .high: return .green
        case .moderate: return .orange
        case .low, .none: return .gray
        }
    }
    
    private func matchedBadgeLabel(_ level: PolicyMatchResult.ConfidenceLevel?) -> String {
        switch level {
        case .high: return "HIGH"
        case .moderate: return "MOD"
        case .low: return "LOW"
        case .none: return "MATCHED"
        }
    }
    
    private func matchedRowColor(_ level: PolicyMatchResult.ConfidenceLevel?) -> Color {
        switch level {
        case .high: return Color.green.opacity(0.06)
        case .moderate: return Color.orange.opacity(0.06)
        case .low, .none: return Color.gray.opacity(0.06)
        }
    }
}
