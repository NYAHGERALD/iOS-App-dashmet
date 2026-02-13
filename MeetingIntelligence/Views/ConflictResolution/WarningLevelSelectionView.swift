//
//  WarningLevelSelectionView.swift
//  MeetingIntelligence
//
//  Phase 8: Warning Level Selection Modal
//  Allows supervisor to select First/Second/Final warning level
//

import SwiftUI

// MARK: - Warning Level
enum WarningLevel: String, CaseIterable, Identifiable {
    case first = "FIRST"
    case second = "SECOND"
    case final = "FINAL"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .first: return "First Written Warning"
        case .second: return "Second Written Warning"
        case .final: return "Final Written Warning"
        }
    }
    
    var shortName: String {
        switch self {
        case .first: return "First Warning"
        case .second: return "Second Warning"
        case .final: return "Final Warning"
        }
    }
    
    var description: String {
        switch self {
        case .first: 
            return "Initial formal documentation that sets baseline for progressive discipline."
        case .second:
            return "Follow-up to previous warning; system will auto-link to prior warning record."
        case .final:
            return "Last step before termination consideration; requires HR review before issuance."
        }
    }
    
    var icon: String {
        switch self {
        case .first: return "1.circle.fill"
        case .second: return "2.circle.fill"
        case .final: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .first: return .yellow
        case .second: return .orange
        case .final: return .red
        }
    }
    
    var consequences: String {
        switch self {
        case .first:
            return "• Documented in employee file\n• Sets foundation for progressive discipline\n• Improvement period typically 30-60 days"
        case .second:
            return "• Links to prior warning record\n• Demonstrates pattern of behavior\n• Shorter improvement timeline\n• May affect performance review"
        case .final:
            return "• Last opportunity before termination\n• Requires HR approval to issue\n• Employee placed on probation\n• Any future violation may result in termination"
        }
    }
    
    var requiresHRReview: Bool {
        self == .final
    }
}

// MARK: - Prior Warning Info
struct PriorWarningInfo {
    let warningLevel: WarningLevel
    let date: Date
    let reason: String
    let caseNumber: String
}

// MARK: - Warning Level Selection View
struct WarningLevelSelectionView: View {
    @Binding var selectedLevel: WarningLevel?
    let employeeName: String
    let priorWarnings: [PriorWarningInfo]
    let onConfirm: (WarningLevel) -> Void
    let onCancel: () -> Void
    
    @State private var acknowledgedHRReview = false
    
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
    
    private var suggestedLevel: WarningLevel {
        if priorWarnings.isEmpty {
            return .first
        } else if priorWarnings.count == 1 {
            return .second
        } else {
            return .final
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection
                    
                    // Prior Warnings (if any)
                    if !priorWarnings.isEmpty {
                        priorWarningsSection
                    }
                    
                    // System Suggestion
                    suggestionSection
                    
                    // Warning Level Options
                    warningLevelOptionsSection
                    
                    // Selected Level Details
                    if let level = selectedLevel {
                        selectedLevelDetailsSection(level)
                    }
                    
                    // HR Review Acknowledgment (for Final Warning)
                    if selectedLevel == .final {
                        hrReviewAcknowledgmentSection
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Select Warning Level")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Confirm") {
                        if let level = selectedLevel {
                            onConfirm(level)
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedLevel == nil || (selectedLevel == .final && !acknowledgedHRReview))
                }
            }
            .onAppear {
                if selectedLevel == nil {
                    selectedLevel = suggestedLevel
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("Written Warning for \(employeeName)")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(textPrimary)
                .multilineTextAlignment(.center)
            
            Text("Select the appropriate warning level based on the severity and history of the issue.")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Prior Warnings Section
    private var priorWarningsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                
                Text("Prior Warning History")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textPrimary)
            }
            
            ForEach(priorWarnings.indices, id: \.self) { index in
                let warning = priorWarnings[index]
                HStack(spacing: 12) {
                    Circle()
                        .fill(warning.warningLevel.color)
                        .frame(width: 10, height: 10)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(warning.warningLevel.shortName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(textPrimary)
                        
                        Text("\(warning.date.formatted(date: .abbreviated, time: .omitted)) • \(warning.caseNumber)")
                            .font(.system(size: 11))
                            .foregroundColor(textSecondary)
                        
                        Text(warning.reason)
                            .font(.system(size: 12))
                            .foregroundColor(textSecondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "link")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                }
                .padding()
                .background(innerCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Suggestion Section
    private var suggestionSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 18))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("System Recommendation")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Based on prior history, a \(suggestedLevel.shortName) is recommended.")
                    .font(.system(size: 13))
                    .foregroundColor(textPrimary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Warning Level Options Section
    private var warningLevelOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Warning Level")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textPrimary)
            
            ForEach(WarningLevel.allCases) { level in
                warningLevelOption(level)
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func warningLevelOption(_ level: WarningLevel) -> some View {
        let isSelected = selectedLevel == level
        let isSuggested = level == suggestedLevel
        
        return Button {
            selectedLevel = level
            if level != .final {
                acknowledgedHRReview = false
            }
        } label: {
            HStack(spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? level.color : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(level.color)
                            .frame(width: 14, height: 14)
                    }
                }
                
                // Icon
                Image(systemName: level.icon)
                    .font(.system(size: 20))
                    .foregroundColor(level.color)
                    .frame(width: 28)
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(level.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(textPrimary)
                        
                        if isSuggested {
                            Text("Suggested")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .clipShape(Capsule())
                        }
                        
                        if level.requiresHRReview {
                            Text("HR Review Required")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(level.description)
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding()
            .background(isSelected ? level.color.opacity(0.08) : innerCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? level.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Selected Level Details Section
    private func selectedLevelDetailsSection(_ level: WarningLevel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(level.color)
                
                Text("Consequences of \(level.shortName)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textPrimary)
            }
            
            Text(level.consequences)
                .font(.system(size: 13))
                .foregroundColor(textSecondary)
                .lineSpacing(4)
        }
        .padding()
        .background(level.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - HR Review Acknowledgment Section
    private var hrReviewAcknowledgmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
                
                Text("Final Warning Requirements")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.red)
            }
            
            Text("Final Written Warnings require HR review and approval before they can be issued to the employee. This ensures compliance with company policy and legal requirements.")
                .font(.system(size: 13))
                .foregroundColor(textSecondary)
            
            Button {
                acknowledgedHRReview.toggle()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: acknowledgedHRReview ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20))
                        .foregroundColor(acknowledgedHRReview ? .green : textSecondary)
                    
                    Text("I understand this document will be sent to HR for review before it can be finalized and issued.")
                        .font(.system(size: 13))
                        .foregroundColor(textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding()
            .background(innerCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding()
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview
#Preview {
    WarningLevelSelectionView(
        selectedLevel: .constant(.first),
        employeeName: "John Smith",
        priorWarnings: [
            PriorWarningInfo(
                warningLevel: .first,
                date: Date().addingTimeInterval(-60 * 24 * 60 * 60),
                reason: "Violation of attendance policy",
                caseNumber: "CR-2024-045"
            )
        ],
        onConfirm: { _ in },
        onCancel: {}
    )
}
