//
//  ActionConfirmationView.swift
//  MeetingIntelligence
//
//  Phase 8: Action Confirmation Screen
//  Displays confirmation before generating official documentation
//

import SwiftUI

struct ActionConfirmationView: View {
    let selectedAction: RecommendationOption
    let conflictCase: ConflictCase
    let onConfirm: () -> Void
    let onChangeSelection: () -> Void
    
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
    
    private var actionColor: Color {
        switch selectedAction.type {
        case .coaching: return .green
        case .counseling: return .blue
        case .warning: return .orange
        case .escalate: return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header Icon
            ZStack {
                Circle()
                    .fill(actionColor.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: selectedAction.type.icon)
                    .font(.system(size: 36))
                    .foregroundColor(actionColor)
            }
            
            // Title
            VStack(spacing: 8) {
                Text("Confirm Selected Action")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(textPrimary)
                
                Text("Review before generating official documentation")
                    .font(.system(size: 14))
                    .foregroundColor(textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Selected Action Card
            VStack(spacing: 16) {
                // Action Type
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selected Action")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(textSecondary)
                        
                        Text(selectedAction.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(actionColor)
                    }
                    
                    Spacer()
                    
                    // Risk Level Badge
                    Text(selectedAction.riskLevel.displayName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(selectedAction.riskLevel.color)
                        .clipShape(Capsule())
                }
                
                Divider()
                
                // Case Context
                VStack(alignment: .leading, spacing: 8) {
                    Text("Case Context")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textSecondary)
                    
                    HStack(spacing: 16) {
                        infoItem(icon: "folder.fill", label: "Case", value: conflictCase.caseNumber)
                        infoItem(icon: "tag.fill", label: "Type", value: conflictCase.type.displayName)
                    }
                    
                    HStack(spacing: 16) {
                        infoItem(icon: "building.2.fill", label: "Dept", value: conflictCase.department)
                        infoItem(icon: "mappin.circle.fill", label: "Location", value: conflictCase.location)
                    }
                }
                
                Divider()
                
                // Estimated Generation Time
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                    
                    Text("Estimated generation time:")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                    
                    Text(estimatedTime)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    Spacer()
                }
            }
            .padding()
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Warning Notice
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                
                Text("This will generate official documentation that may become part of employee records.")
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 12) {
                Button(action: onConfirm) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Confirm & Generate")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(actionColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                
                Button(action: onChangeSelection) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                        Text("Change Selection")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textSecondary)
                }
            }
        }
        .padding(24)
    }
    
    // MARK: - Helper Views
    
    private func infoItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(textSecondary)
            
            Text(label + ":")
                .font(.system(size: 12))
                .foregroundColor(textSecondary)
            
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textPrimary)
                .lineLimit(1)
        }
    }
    
    private var estimatedTime: String {
        switch selectedAction.type {
        case .coaching: return "15-30 seconds"
        case .counseling: return "20-40 seconds"
        case .warning: return "30-60 seconds"
        case .escalate: return "45-90 seconds"
        }
    }
}

// MARK: - Preview
#Preview {
    ActionConfirmationView(
        selectedAction: RecommendationOption(
            id: "option_a",
            type: .coaching,
            title: "Informal Coaching Session",
            description: "Conduct a coaching session",
            rationale: "Based on analysis",
            riskLevel: .low,
            riskExplanation: "Low risk",
            nextSteps: [],
            timeframe: "48 hours",
            confidence: 0.85,
            targetEmployeeIds: []
        ),
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
        onConfirm: {},
        onChangeSelection: {}
    )
}
