import SwiftUI

// MARK: - Render.com-style Delete Confirmation

struct DeleteAssessmentConfirmationView: View {
    let assessment: SafetyAssessment
    let onConfirmDelete: (String) async -> Bool
    @Environment(\.dismiss) private var dismiss
    
    @State private var confirmationText = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @FocusState private var isTextFieldFocused: Bool
    
    private var assessmentNumber: String {
        assessment.assessmentNumber
    }
    
    private var isConfirmationValid: Bool {
        confirmationText == assessmentNumber
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        warningIcon
                        warningHeader
                        consequencesCard
                        confirmationSection
                        deleteButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .interactiveDismissDisabled(isDeleting)
    }
    
    // MARK: - Warning Icon
    
    private var warningIcon: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.1))
                .frame(width: 80, height: 80)
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.red)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Warning Header
    
    private var warningHeader: some View {
        VStack(spacing: 8) {
            Text("Delete Assessment")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            
            Text("This action is permanent and cannot be undone.")
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Consequences Card
    
    private var consequencesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("By deleting this assessment, you will permanently lose:")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
            
            consequenceRow(
                icon: "doc.text.fill",
                text: "All assessment data, inspection items, and their status",
                color: Color(hex: "EF4444")
            )
            
            consequenceRow(
                icon: "camera.fill",
                text: "All photos and evidence attached to assessment items",
                color: Color(hex: "F97316")
            )
            
            if assessment.employeeSignature != nil || assessment.teamLeaderSignature != nil {
                consequenceRow(
                    icon: "signature",
                    text: "Employee and team leader signatures",
                    color: Color(hex: "8B5CF6")
                )
            }
            
            consequenceRow(
                icon: "text.bubble.fill",
                text: "Deficiency descriptions, corrective actions, and comments",
                color: Color(hex: "3B82F6")
            )
            
            if assessment.status == .submitted {
                consequenceRow(
                    icon: "checkmark.shield.fill",
                    text: "The submitted assessment record and its audit trail",
                    color: Color(hex: "10B981")
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func consequenceRow(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Confirmation Section
    
    private var confirmationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 0) {
                Text("To confirm, type ")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textPrimary)
                
                Text(assessmentNumber)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.red)
                
                Text(" below:")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            TextField("", text: $confirmationText)
                .font(.system(size: 15))
                .padding(12)
                .background(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            confirmationText.isEmpty
                                ? AppColors.border
                                : (isConfirmationValid ? Color.red : Color(hex: "F97316")),
                            lineWidth: confirmationText.isEmpty ? 1 : 1.5
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .focused($isTextFieldFocused)
            
            if !confirmationText.isEmpty && !isConfirmationValid {
                Text("Assessment number does not match")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "F97316"))
            }
            
            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                    Text(error)
                        .font(.system(size: 12))
                }
                .foregroundColor(.red)
            }
        }
        .padding(16)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.border.opacity(0.5), lineWidth: 1)
        )
    }
    
    // MARK: - Delete Button
    
    private var deleteButton: some View {
        Button {
            isTextFieldFocused = false
            Task { await performDelete() }
        } label: {
            HStack(spacing: 8) {
                if isDeleting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 15))
                }
                Text(isDeleting ? "Deleting..." : "Permanently Delete Assessment")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isConfirmationValid && !isDeleting
                    ? Color.red
                    : Color.gray.opacity(0.3)
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!isConfirmationValid || isDeleting)
    }
    
    // MARK: - Delete Action
    
    private func performDelete() async {
        guard isConfirmationValid else { return }
        
        isDeleting = true
        errorMessage = nil
        
        let success = await onConfirmDelete(confirmationText)
        
        if success {
            dismiss()
        } else {
            errorMessage = "Failed to delete assessment. Check console for details."
            isDeleting = false
        }
    }
}
