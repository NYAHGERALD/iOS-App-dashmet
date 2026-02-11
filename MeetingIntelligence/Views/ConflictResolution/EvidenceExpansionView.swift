//
//  EvidenceExpansionView.swift
//  MeetingIntelligence
//
//  Phase 5: Evidence Expansion
//  Guides supervisors through adding witness statements and prior history
//

import SwiftUI

struct EvidenceExpansionView: View {
    let conflictCase: ConflictCase
    let onAddWitness: () -> Void
    let onScanWitnessStatement: (InvolvedEmployee) -> Void
    let onAddPriorHistory: () -> Void
    let onReAnalyze: () -> Void
    let onSkip: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var expandedSection: ExpandedSection? = nil
    @State private var hasWitnesses: Bool? = nil
    @State private var hasPriorHistory: Bool? = nil
    
    enum ExpandedSection {
        case witnesses
        case priorHistory
    }
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    // Check if there are witnesses without statements
    private var witnessesNeedingStatements: [InvolvedEmployee] {
        conflictCase.witnesses.filter { witness in
            !conflictCase.documents.contains { doc in
                doc.type == .witnessStatement && doc.employeeId == witness.id
            }
        }
    }
    
    // Check if prior history docs exist
    private var hasPriorHistoryDocs: Bool {
        conflictCase.documents.contains { doc in
            doc.type == .priorRecord || doc.type == .counselingRecord || doc.type == .warningDocument
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            headerSection
            
            // Witness Section
            witnessSection
            
            // Prior History Section
            priorHistorySection
            
            // Action Buttons
            actionButtons
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Expand the Evidence")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    Text("Strengthen your case with additional context")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Witness Section
    private var witnessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedSection == .witnesses {
                        expandedSection = nil
                    } else {
                        expandedSection = .witnesses
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "10B981"))
                        .frame(width: 32)
                    
                    Text("Were there any witnesses?")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(textPrimary)
                    
                    Spacer()
                    
                    // Status indicator
                    if !conflictCase.witnesses.isEmpty {
                        Text("\(conflictCase.witnesses.count) added")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "10B981"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "10B981").opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    Image(systemName: expandedSection == .witnesses ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textSecondary)
                }
                .padding()
                .background(Color.gray.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            
            // Expanded Content
            if expandedSection == .witnesses {
                VStack(alignment: .leading, spacing: 12) {
                    // Quick selection if no witnesses yet
                    if conflictCase.witnesses.isEmpty && hasWitnesses == nil {
                        HStack(spacing: 12) {
                            quickOptionButton(
                                title: "Yes",
                                isSelected: hasWitnesses == true,
                                color: .blue
                            ) {
                                hasWitnesses = true
                            }
                            
                            quickOptionButton(
                                title: "No",
                                isSelected: hasWitnesses == false,
                                color: .gray
                            ) {
                                hasWitnesses = false
                                expandedSection = nil
                            }
                        }
                    }
                    
                    // Show witnesses
                    if !conflictCase.witnesses.isEmpty || hasWitnesses == true {
                        // Existing witnesses
                        ForEach(conflictCase.witnesses) { witness in
                            witnessRow(witness)
                        }
                        
                        // Add witness button
                        Button {
                            onAddWitness()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Witness")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.horizontal, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private func witnessRow(_ witness: InvolvedEmployee) -> some View {
        let hasStatement = conflictCase.documents.contains { doc in
            doc.type == .witnessStatement && doc.employeeId == witness.id
        }
        
        return HStack(spacing: 12) {
            // Witness Avatar
            ZStack {
                Circle()
                    .fill(Color(hex: "10B981").opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Text(witness.name.prefix(1).uppercased())
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "10B981"))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(witness.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textPrimary)
                
                Text(witness.role)
                    .font(.system(size: 12))
                    .foregroundColor(textSecondary)
            }
            
            Spacer()
            
            // Statement status
            if hasStatement {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Statement")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "10B981"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "10B981").opacity(0.15))
                .clipShape(Capsule())
            } else {
                Button {
                    onScanWitnessStatement(witness)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.viewfinder")
                        Text("Scan")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: "10B981"))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Prior History Section
    private var priorHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedSection == .priorHistory {
                        expandedSection = nil
                    } else {
                        expandedSection = .priorHistory
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "F59E0B"))
                        .frame(width: 32)
                    
                    Text("Any prior history?")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(textPrimary)
                    
                    Spacer()
                    
                    // Status indicator
                    if hasPriorHistoryDocs {
                        let count = conflictCase.documents.filter { 
                            $0.type == .priorRecord || $0.type == .counselingRecord || $0.type == .warningDocument 
                        }.count
                        Text("\(count) added")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "F59E0B"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "F59E0B").opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    Image(systemName: expandedSection == .priorHistory ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textSecondary)
                }
                .padding()
                .background(Color.gray.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            
            // Expanded Content
            if expandedSection == .priorHistory {
                VStack(alignment: .leading, spacing: 12) {
                    // Quick selection if no history yet
                    if !hasPriorHistoryDocs && hasPriorHistory == nil {
                        HStack(spacing: 12) {
                            quickOptionButton(
                                title: "Yes",
                                isSelected: hasPriorHistory == true,
                                color: .blue
                            ) {
                                hasPriorHistory = true
                            }
                            
                            quickOptionButton(
                                title: "No",
                                isSelected: hasPriorHistory == false,
                                color: .gray
                            ) {
                                hasPriorHistory = false
                                expandedSection = nil
                            }
                        }
                    }
                    
                    // Show history options
                    if hasPriorHistoryDocs || hasPriorHistory == true {
                        // History type cards
                        Text("What type of prior history?")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(textSecondary)
                        
                        VStack(spacing: 8) {
                            historyTypeCard(
                                icon: "exclamationmark.triangle.fill",
                                title: "Prior Complaints",
                                subtitle: "Previous complaints between these employees",
                                color: Color(hex: "EF4444"),
                                type: .priorRecord
                            )
                            
                            historyTypeCard(
                                icon: "person.fill.questionmark",
                                title: "Counseling Records",
                                subtitle: "Previous counseling or HR discussions",
                                color: Color(hex: "8B5CF6"),
                                type: .counselingRecord
                            )
                            
                            historyTypeCard(
                                icon: "doc.text.fill",
                                title: "Previous Warnings",
                                subtitle: "Written or verbal warnings issued",
                                color: Color(hex: "F59E0B"),
                                type: .warningDocument
                            )
                        }
                    }
                }
                .padding(.horizontal, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private func historyTypeCard(icon: String, title: String, subtitle: String, color: Color, type: CaseDocumentType) -> some View {
        let existingCount = conflictCase.documents.filter { $0.type == type }.count
        
        return Button {
            onAddPriorHistory()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if existingCount > 0 {
                    Text("\(existingCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(color)
                        .frame(width: 24, height: 24)
                        .background(color.opacity(0.15))
                        .clipShape(Circle())
                }
                
                Image(systemName: "plus.circle")
                    .font(.system(size: 16))
                    .foregroundColor(textSecondary)
            }
            .padding(12)
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Re-analyze button (if new evidence added)
            let hasNewEvidence = !conflictCase.witnesses.isEmpty || hasPriorHistoryDocs
            
            if hasNewEvidence {
                Button {
                    onReAnalyze()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Re-Analyze with New Evidence")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            // Continue button
            Button {
                onSkip()
            } label: {
                Text(hasNewEvidence ? "Continue to Policy Alignment" : "Skip for Now")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textSecondary)
            }
        }
    }
    
    // MARK: - Helper Views
    private func quickOptionButton(title: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? color : color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Preview
#Preview {
    let sampleCase = ConflictCase(
        type: .conflict,
        incidentDate: Date(),
        location: "Die Cut Line 2",
        department: "Bakery",
        involvedEmployees: [
            InvolvedEmployee(name: "Maria Santos", role: "Machine Operator", department: "Bakery", employeeId: "EMP001", isComplainant: true),
            InvolvedEmployee(name: "John Williams", role: "Team Lead", department: "Bakery", employeeId: "EMP002", isComplainant: true),
            InvolvedEmployee(name: "Sarah Johnson", role: "Quality Inspector", department: "Bakery", employeeId: "EMP003", isComplainant: false)
        ]
    )
    
    ScrollView {
        EvidenceExpansionView(
            conflictCase: sampleCase,
            onAddWitness: { print("Add witness") },
            onScanWitnessStatement: { witness in print("Scan for \(witness.name)") },
            onAddPriorHistory: { print("Add prior history") },
            onReAnalyze: { print("Re-analyze") },
            onSkip: { print("Skip") }
        )
        .padding()
    }
    .background(AppColors.background)
}
