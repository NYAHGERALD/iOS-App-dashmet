import SwiftUI

// MARK: - Submission Signature Flow

struct SubmissionSignatureFlowView: View {
    @ObservedObject var viewModel: SafetyAssessmentViewModel
    @Binding var isPresented: Bool
    
    enum SignatureStep {
        case employee
        case teamLeader
    }
    
    @State private var currentStep: SignatureStep = .employee
    @State private var employeeSignatureImage: UIImage?
    @State private var employeeSignatureEmpty = true
    @State private var teamLeaderSignatureImage: UIImage?
    @State private var teamLeaderSignatureEmpty = true
    @State private var confirmAccuracy = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var isDrawing = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Step indicator
                    stepIndicator
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            if currentStep == .employee {
                                employeeSignatureStep
                            } else {
                                teamLeaderSignatureStep
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                    .scrollDisabled(isDrawing)
                    
                    // Bottom action
                    bottomAction
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Step Indicator
    
    private var stepIndicator: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    if currentStep == .teamLeader {
                        withAnimation { currentStep = .employee }
                    } else {
                        isPresented = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text(currentStep == .employee ? "Cancel" : "Back")
                            .font(.system(size: 17))
                    }
                    .foregroundColor(.accentColor)
                }
                
                Spacer()
                
                Text("Submit Assessment")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                // Balance spacer
                Text("Cancel")
                    .font(.system(size: 17))
                    .foregroundColor(.clear)
            }
            
            // Progress steps
            HStack(spacing: 8) {
                stepBadge(number: 1, title: "Employee", isActive: currentStep == .employee, isCompleted: currentStep == .teamLeader)
                
                Rectangle()
                    .fill(currentStep == .teamLeader ? Color(hex: "10B981") : AppColors.border)
                    .frame(height: 2)
                    .frame(maxWidth: 40)
                
                stepBadge(number: 2, title: "Team Leader", isActive: currentStep == .teamLeader, isCompleted: false)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.surface)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
    
    private func stepBadge(number: Int, title: String, isActive: Bool, isCompleted: Bool) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color(hex: "10B981") : isActive ? Color(hex: "3B82F6") : AppColors.surfaceSecondary)
                    .frame(width: 28, height: 28)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isActive ? .white : AppColors.textTertiary)
                }
            }
            
            Text(title)
                .font(.system(size: 13, weight: isActive || isCompleted ? .semibold : .regular))
                .foregroundColor(isActive || isCompleted ? AppColors.textPrimary : AppColors.textTertiary)
        }
    }
    
    // MARK: - Employee Signature Step
    
    private var employeeSignatureStep: some View {
        VStack(spacing: 20) {
            // Info card
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "3B82F6"))
                    Text("Employee Signature")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                }
                
                Text("The employee must sign below to confirm their participation in this workplace safety assessment.")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "EFF6FF"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Assessment summary
            assessmentSummaryCard
            
            // Signature canvas
            SignatureCaptureView(
                title: "Employee Signature",
                signerName: viewModel.employeeName.isEmpty ? "Employee" : viewModel.employeeName,
                signatureImage: $employeeSignatureImage,
                isEmpty: $employeeSignatureEmpty,
                isDrawing: $isDrawing,
                onClear: {
                    employeeSignatureImage = nil
                    employeeSignatureEmpty = true
                }
            )
        }
    }
    
    // MARK: - Team Leader Signature Step
    
    private var teamLeaderSignatureStep: some View {
        VStack(spacing: 20) {
            // Info card
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "10B981"))
                    Text("Team Leader Signature")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                }
                
                Text("The team leader must sign below to confirm the assessment has been completed accurately.")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "ECFDF5"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Assessment summary
            assessmentSummaryCard
            
            // Signature canvas
            SignatureCaptureView(
                title: "Team Leader Signature",
                signerName: viewModel.teamLeaderName,
                signatureImage: $teamLeaderSignatureImage,
                isEmpty: $teamLeaderSignatureEmpty,
                isDrawing: $isDrawing,
                onClear: {
                    teamLeaderSignatureImage = nil
                    teamLeaderSignatureEmpty = true
                }
            )
            
            // Confirmation checkbox
            Button {
                confirmAccuracy.toggle()
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: confirmAccuracy ? "checkmark.square.fill" : "square")
                        .font(.system(size: 22))
                        .foregroundColor(confirmAccuracy ? Color(hex: "10B981") : AppColors.textTertiary)
                    
                    Text("I confirm that all information in this assessment has been completed accurately and reflects the true conditions observed during the inspection.")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(confirmAccuracy ? Color(hex: "ECFDF5") : AppColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(confirmAccuracy ? Color(hex: "10B981") : AppColors.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // Error message
            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppColors.error)
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.error)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    // MARK: - Assessment Summary Card
    
    private var assessmentSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Assessment Summary")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            HStack(spacing: 16) {
                summaryItem(label: "Assessment", value: viewModel.assessmentNumber)
                summaryItem(label: "Items", value: "\(viewModel.totalItems)")
            }
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(Color(hex: "10B981")).frame(width: 8, height: 8)
                    Text("\(viewModel.acceptableCount) A")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(AppColors.error).frame(width: 8, height: 8)
                    Text("\(viewModel.unacceptableCount) U")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(AppColors.textTertiary).frame(width: 8, height: 8)
                    Text("\(viewModel.naCount) NA")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func summaryItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppColors.textTertiary)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
        }
    }
    
    // MARK: - Bottom Action
    
    private var bottomAction: some View {
        VStack(spacing: 0) {
            Divider()
            
            if currentStep == .employee {
                Button {
                    withAnimation { currentStep = .teamLeader }
                } label: {
                    HStack(spacing: 8) {
                        Text("Continue to Team Leader")
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        !employeeSignatureEmpty
                        ? Color(hex: "3B82F6")
                        : Color.gray.opacity(0.3)
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(employeeSignatureEmpty)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            } else {
                Button {
                    Task { await submitWithSignatures() }
                } label: {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 16))
                        }
                        Text(isSubmitting ? "Submitting..." : "Submit Assessment")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        canSubmitFinal
                        ? LinearGradient(colors: [Color(hex: "10B981"), Color(hex: "059669")], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canSubmitFinal || isSubmitting)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .background(AppColors.surface)
    }
    
    private var canSubmitFinal: Bool {
        !employeeSignatureEmpty && !teamLeaderSignatureEmpty && confirmAccuracy
    }
    
    // MARK: - Submit with Signatures
    
    private func submitWithSignatures() async {
        guard let employeeSig = employeeSignatureImage,
              let teamLeaderSig = teamLeaderSignatureImage else {
            errorMessage = "Both signatures are required"
            return
        }
        
        guard confirmAccuracy else {
            errorMessage = "Please confirm the accuracy of the assessment"
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        do {
            // 1. Upload employee signature to Firebase
            let employeeSigUrl = try await FirebaseStorageService.shared.uploadSafetySignature(
                employeeSig,
                assessmentNumber: viewModel.assessmentNumber,
                role: "employee"
            )
            
            // 2. Upload team leader signature to Firebase
            let teamLeaderSigUrl = try await FirebaseStorageService.shared.uploadSafetySignature(
                teamLeaderSig,
                assessmentNumber: viewModel.assessmentNumber,
                role: "team_leader"
            )
            
            // 3. Submit assessment with signature URLs
            await viewModel.submitAssessmentWithSignatures(
                employeeSignatureUrl: employeeSigUrl,
                teamLeaderSignatureUrl: teamLeaderSigUrl
            )
            
            if viewModel.errorMessage == nil {
                isPresented = false
            } else {
                errorMessage = viewModel.errorMessage
            }
        } catch {
            errorMessage = "Failed to upload signatures: \(error.localizedDescription)"
        }
        
        isSubmitting = false
    }
}
