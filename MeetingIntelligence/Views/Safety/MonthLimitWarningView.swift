import SwiftUI

struct MonthLimitWarningView: View {
    let assessment: SafetyAssessment?
    let onViewAssessment: () -> Void
    let onDismiss: () -> Void
    
    private var currentMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator spacer
            Spacer().frame(height: 8)
            
            // Warning icon
            ZStack {
                Circle()
                    .fill(Color(hex: "FEF3C7"))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(Color(hex: "F59E0B"))
            }
            .padding(.top, 16)
            
            // Title
            Text("Assessment Limit Reached")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .padding(.top, 16)
            
            // Message card
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "3B82F6"))
                        .padding(.top, 2)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("You can only create **one** Safety Assessment per month.")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("An assessment for **\(currentMonthYear)** already exists:")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                // Assessment number badge
                if let assessment = assessment {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "10B981"))
                        
                        Text(assessment.assessmentNumber)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        statusBadge(assessment.status)
                    }
                    .padding(12)
                    .background(Color(hex: "F0FDF4"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "10B981").opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Tip
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "F59E0B"))
                        .padding(.top, 1)
                    
                    Text("You can edit or update your existing assessment instead of creating a new one.")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(16)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 10) {
                Button {
                    onViewAssessment()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 15))
                        Text("View Existing Assessment")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "10B981"), Color(hex: "059669")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button {
                    onDismiss()
                } label: {
                    Text("Dismiss")
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.surface)
                        .foregroundColor(AppColors.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(AppColors.background)
    }
    
    private func statusBadge(_ status: WSAStatus) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 6, height: 6)
            Text(status.rawValue)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(statusColor(status).opacity(0.15))
        .clipShape(Capsule())
    }
    
    private func statusColor(_ status: WSAStatus) -> Color {
        switch status {
        case .draft: return Color(hex: "F59E0B")
        case .submitted: return AppColors.primary
        case .completed: return AppColors.success
        }
    }
}
