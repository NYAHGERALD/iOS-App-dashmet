//
//  EscalationFlowView.swift
//  MeetingIntelligence
//
//  Phase 8: HR Escalation Flow
//  Priority selection and HR recipient selection for case escalation
//

import SwiftUI

// MARK: - Escalation Priority
enum EscalationPriority: String, CaseIterable, Identifiable {
    case critical = "CRITICAL"
    case high = "HIGH"
    case standard = "STANDARD"
    case informational = "INFORMATIONAL"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .critical: return "Critical"
        case .high: return "High"
        case .standard: return "Standard"
        case .informational: return "Informational"
        }
    }
    
    var subtitle: String {
        switch self {
        case .critical: return "Immediate HR attention required"
        case .high: return "Review within 24-48 hours"
        case .standard: return "Review within 1 week"
        case .informational: return "For HR awareness only"
        }
    }
    
    var description: String {
        switch self {
        case .critical:
            return "Safety concerns, harassment, discrimination, potential legal exposure"
        case .high:
            return "Repeated violations, multiple parties, complex situations"
        case .standard:
            return "Routine escalations, policy clarification needed, supervisor guidance requested"
        case .informational:
            return "Documentation purposes, pattern tracking, no immediate action required"
        }
    }
    
    var icon: String {
        switch self {
        case .critical: return "exclamationmark.3"
        case .high: return "exclamationmark.2"
        case .standard: return "clock"
        case .informational: return "info.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .critical: return .red
        case .high: return .orange
        case .standard: return .yellow
        case .informational: return .green
        }
    }
    
    var responseTime: String {
        switch self {
        case .critical: return "< 2 hours"
        case .high: return "24-48 hours"
        case .standard: return "3-5 business days"
        case .informational: return "As needed"
        }
    }
}

// MARK: - HR Recipient Type
enum HRRecipientType: String, CaseIterable, Identifiable {
    case hrBusinessPartner = "HR_BUSINESS_PARTNER"
    case hrManager = "HR_MANAGER"
    case employeeRelations = "EMPLOYEE_RELATIONS"
    case legalCompliance = "LEGAL_COMPLIANCE"
    case departmentHead = "DEPARTMENT_HEAD"
    case other = "OTHER"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .hrBusinessPartner: return "HR Business Partner"
        case .hrManager: return "HR Manager"
        case .employeeRelations: return "Employee Relations Specialist"
        case .legalCompliance: return "Legal/Compliance"
        case .departmentHead: return "Department Head"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .hrBusinessPartner: return "person.crop.circle.badge.checkmark"
        case .hrManager: return "person.crop.rectangle.stack"
        case .employeeRelations: return "person.2.fill"
        case .legalCompliance: return "scale.3d"
        case .departmentHead: return "building.2.fill"
        case .other: return "person.crop.circle.badge.plus"
        }
    }
    
    var recommendedFor: [EscalationPriority] {
        switch self {
        case .hrBusinessPartner: return [.high, .standard]
        case .hrManager: return [.critical, .high]
        case .employeeRelations: return [.critical, .high, .standard]
        case .legalCompliance: return [.critical]
        case .departmentHead: return [.high, .standard, .informational]
        case .other: return []
        }
    }
}

// MARK: - Escalation Configuration
struct EscalationConfiguration {
    var priority: EscalationPriority = .standard
    var selectedRecipients: Set<HRRecipientType> = []
    var customMessage: String = ""
    var confirmAccuracy: Bool = false
    var confirmTransfer: Bool = false
}

// MARK: - Escalation Flow View
struct EscalationFlowView: View {
    @Binding var configuration: EscalationConfiguration
    let conflictCase: ConflictCase
    let documentCount: Int
    let totalPages: Int
    let onSubmit: () -> Void
    let onSaveAsDraft: () -> Void
    let onCancel: () -> Void
    
    @State private var currentStep: EscalationStep = .priority
    @State private var showCustomRecipientInput = false
    @State private var customRecipientName = ""
    
    @Environment(\.colorScheme) private var colorScheme
    
    enum EscalationStep {
        case priority
        case recipients
        case confirmation
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
    
    private var innerCardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.gray.opacity(0.08)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress Indicator
                progressIndicator
                
                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        switch currentStep {
                        case .priority:
                            prioritySelectionView
                        case .recipients:
                            recipientSelectionView
                        case .confirmation:
                            confirmationView
                        }
                    }
                    .padding()
                }
                
                // Navigation Buttons
                navigationButtons
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        HStack(spacing: 4) {
            ForEach([EscalationStep.priority, .recipients, .confirmation], id: \.self) { step in
                let isCompleted = stepIndex(step) < stepIndex(currentStep)
                let isCurrent = step == currentStep
                
                if step != .priority {
                    Rectangle()
                        .fill(isCompleted ? Color.red : Color.gray.opacity(0.3))
                        .frame(height: 2)
                        .frame(maxWidth: 40)
                }
                
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.red : (isCurrent ? Color.red.opacity(0.2) : Color.gray.opacity(0.2)))
                        .frame(width: 28, height: 28)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("\(stepIndex(step) + 1)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isCurrent ? .red : textSecondary)
                    }
                }
            }
        }
        .padding()
        .background(cardBackground)
    }
    
    private func stepIndex(_ step: EscalationStep) -> Int {
        switch step {
        case .priority: return 0
        case .recipients: return 1
        case .confirmation: return 2
        }
    }
    
    private var stepTitle: String {
        switch currentStep {
        case .priority: return "Select Priority"
        case .recipients: return "Select Recipients"
        case .confirmation: return "Confirm Escalation"
        }
    }
    
    // MARK: - Priority Selection View
    private var prioritySelectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How urgent is this escalation?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(textPrimary)
            
            ForEach(EscalationPriority.allCases) { priority in
                priorityOption(priority)
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func priorityOption(_ priority: EscalationPriority) -> some View {
        let isSelected = configuration.priority == priority
        
        return Button {
            configuration.priority = priority
        } label: {
            HStack(spacing: 12) {
                // Color indicator
                RoundedRectangle(cornerRadius: 4)
                    .fill(priority.color)
                    .frame(width: 4, height: 50)
                
                // Icon
                ZStack {
                    Circle()
                        .fill(priority.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: priority.icon)
                        .font(.system(size: 16))
                        .foregroundColor(priority.color)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(priority.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(priority.color)
                        
                        Text("• \(priority.responseTime)")
                            .font(.system(size: 11))
                            .foregroundColor(textSecondary)
                    }
                    
                    Text(priority.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(textPrimary)
                    
                    Text(priority.description)
                        .font(.system(size: 11))
                        .foregroundColor(textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? priority.color : Color.gray.opacity(0.3))
            }
            .padding()
            .background(isSelected ? priority.color.opacity(0.08) : innerCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? priority.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Recipient Selection View
    private var recipientSelectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Who should receive this escalation?")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Text("Select one or more recipients")
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
            }
            
            // Auto-suggested recipients
            if !suggestedRecipients.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommended for \(configuration.priority.displayName) Priority")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                    
                    ForEach(suggestedRecipients, id: \.self) { recipient in
                        recipientOption(recipient, isRecommended: true)
                    }
                }
                
                Divider()
                    .padding(.vertical, 8)
            }
            
            // All recipients
            ForEach(HRRecipientType.allCases.filter { !suggestedRecipients.contains($0) }) { recipient in
                recipientOption(recipient, isRecommended: false)
            }
            
            // Custom message
            VStack(alignment: .leading, spacing: 8) {
                Text("Additional Message (Optional)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textPrimary)
                
                TextEditor(text: $configuration.customMessage)
                    .frame(height: 80)
                    .padding(8)
                    .background(innerCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding(.top, 8)
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var suggestedRecipients: [HRRecipientType] {
        HRRecipientType.allCases.filter { $0.recommendedFor.contains(configuration.priority) }
    }
    
    private func recipientOption(_ recipient: HRRecipientType, isRecommended: Bool) -> some View {
        let isSelected = configuration.selectedRecipients.contains(recipient)
        
        return Button {
            if isSelected {
                configuration.selectedRecipients.remove(recipient)
            } else {
                configuration.selectedRecipients.insert(recipient)
            }
        } label: {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .red : textSecondary)
                
                // Icon
                Image(systemName: recipient.icon)
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                // Name
                Text(recipient.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textPrimary)
                
                if isRecommended {
                    Text("Recommended")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                
                Spacer()
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Confirmation View
    private var confirmationView: some View {
        VStack(spacing: 16) {
            // Package Summary
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                    
                    Text("Escalation Package")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textPrimary)
                }
                
                Divider()
                
                summaryRow("Case Number", conflictCase.caseNumber)
                summaryRow("Priority", configuration.priority.displayName, color: configuration.priority.color)
                summaryRow("Documents", "\(documentCount) documents")
                summaryRow("Total Pages", "\(totalPages) pages")
                summaryRow("Recipients", configuration.selectedRecipients.map { $0.displayName }.joined(separator: ", "))
                
                if !configuration.customMessage.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Additional Message")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(textSecondary)
                        Text(configuration.customMessage)
                            .font(.system(size: 13))
                            .foregroundColor(textPrimary)
                    }
                }
            }
            .padding()
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Attestations
            VStack(alignment: .leading, spacing: 12) {
                Text("Supervisor Attestation")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                attestationToggle(
                    text: "I confirm this information is accurate to the best of my knowledge",
                    isOn: $configuration.confirmAccuracy
                )
                
                attestationToggle(
                    text: "I understand this case will be transferred to HR for further action",
                    isOn: $configuration.confirmTransfer
                )
            }
            .padding()
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private func summaryRow(_ label: String, _ value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(color == .primary ? textPrimary : color)
        }
    }
    
    private func attestationToggle(text: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundColor(isOn.wrappedValue ? .green : textSecondary)
                
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(textPrimary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep != .priority {
                Button {
                    withAnimation {
                        switch currentStep {
                        case .recipients: currentStep = .priority
                        case .confirmation: currentStep = .recipients
                        default: break
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(innerCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            if currentStep == .confirmation {
                Button {
                    onSaveAsDraft()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save Draft")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            Button {
                withAnimation {
                    switch currentStep {
                    case .priority: currentStep = .recipients
                    case .recipients: currentStep = .confirmation
                    case .confirmation: onSubmit()
                    }
                }
            } label: {
                HStack {
                    Text(currentStep == .confirmation ? "Submit to HR" : "Continue")
                    Image(systemName: currentStep == .confirmation ? "paperplane.fill" : "chevron.right")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canProceed ? Color.red : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canProceed)
        }
        .padding()
        .background(cardBackground)
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case .priority: return true
        case .recipients: return !configuration.selectedRecipients.isEmpty
        case .confirmation: return configuration.confirmAccuracy && configuration.confirmTransfer
        }
    }
}

// MARK: - Preview
#Preview {
    EscalationFlowView(
        configuration: .constant(EscalationConfiguration()),
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
        documentCount: 5,
        totalPages: 12,
        onSubmit: {},
        onSaveAsDraft: {},
        onCancel: {}
    )
}
