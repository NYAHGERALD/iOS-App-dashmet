import SwiftUI

struct SafetyAssessmentListView: View {
    @StateObject private var viewModel = SafetyAssessmentViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showingAssessment = false
    @State private var assessmentToDelete: SafetyAssessment?
    @State private var filterStatus: WSAStatus? = nil
    @State private var showMonthLimitWarning = false
    @State private var existingMonthAssessment: SafetyAssessment?
    @State private var monthPulse = false
    
    var onMenuTap: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Assessment list
                    assessmentListContent
                }
                
                // Floating "+" button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            // Check if user already has an assessment this month
                            if let existing = viewModel.existingAssessmentForCurrentMonth(userId: appState.currentUserID ?? "") {
                                existingMonthAssessment = existing
                                showMonthLimitWarning = true
                            } else {
                                viewModel.resetToNewAssessment()
                                showingAssessment = true
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "10B981"), Color(hex: "059669")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Circle())
                                .shadow(color: Color(hex: "10B981").opacity(0.4), radius: 8, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showingAssessment, onDismiss: {
                Task { await viewModel.fetchAssessments() }
            }) {
                SafetyAssessmentFormView(viewModel: viewModel)
            }
            .sheet(isPresented: $showMonthLimitWarning) {
                MonthLimitWarningView(
                    assessment: existingMonthAssessment,
                    onViewAssessment: {
                        showMonthLimitWarning = false
                        if let existing = existingMonthAssessment {
                            Task {
                                await viewModel.loadAssessmentById(id: existing.id)
                                showingAssessment = true
                            }
                        }
                    },
                    onDismiss: {
                        showMonthLimitWarning = false
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $assessmentToDelete) { assessment in
                DeleteAssessmentConfirmationView(
                    assessment: assessment,
                    onConfirmDelete: { confirmNumber in
                        await viewModel.deleteAssessment(id: assessment.id, confirmNumber: confirmNumber)
                    }
                )
                .presentationDetents([.large])
            }
            .task {
                let fullName = "\(appState.firstName ?? "") \(appState.lastName ?? "")".trimmingCharacters(in: .whitespaces)
                await viewModel.configure(teamLeader: fullName.isEmpty ? "Team Leader" : fullName)
                await viewModel.fetchDepartments()
                if viewModel.assessments.isEmpty {
                    await viewModel.fetchAssessments()
                }
            }
        }
    }
    
    // MARK: - Filtered Assessments
    
    private var filteredAssessments: [SafetyAssessment] {
        if let filter = filterStatus {
            return viewModel.assessments.filter { $0.status == filter }
        }
        return viewModel.assessments
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 16) {
            // Menu Button
            if let onMenuTap = onMenuTap {
                Button(action: onMenuTap) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 22))
                        .foregroundColor(AppColors.textPrimary)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Safety Assessments")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                
                Text("\(viewModel.assessments.count) assessment\(viewModel.assessments.count == 1 ? "" : "s")")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            // More options menu
            Menu {
                Section("Filter") {
                    Button {
                        filterStatus = nil
                    } label: {
                        Label("All", systemImage: filterStatus == nil ? "checkmark.circle.fill" : "circle")
                    }
                    Button {
                        filterStatus = .draft
                    } label: {
                        Label("Drafts (\(viewModel.assessments.filter { $0.status == .draft }.count))", systemImage: filterStatus == .draft ? "checkmark.circle.fill" : "circle")
                    }
                    Button {
                        filterStatus = .submitted
                    } label: {
                        Label("Submitted (\(viewModel.assessments.filter { $0.status == .submitted }.count))", systemImage: filterStatus == .submitted ? "checkmark.circle.fill" : "circle")
                    }
                }
                
                Section {
                    Button {
                        Task { await viewModel.fetchAssessments() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 22))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
    
    // MARK: - Assessment List Content
    
    private var assessmentListContent: some View {
        Group {
            if viewModel.isLoadingList {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading assessments...")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.top, 8)
                    Spacer()
                }
            } else if filteredAssessments.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textTertiary)
                    Text(filterStatus == nil ? "No assessments yet" : "No \(filterStatus!.rawValue.lowercased()) assessments")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("Tap the + button to create your first safety assessment")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal, 40)
            } else {
                List {
                    ForEach(filteredAssessments) { assessment in
                        assessmentCard(assessment)
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    
                    // Bottom spacing for FAB
                    Color.clear.frame(height: 80)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await viewModel.fetchAssessments()
                }
            }
        }
    }
    
    // MARK: - Assessment Card
    
    private func assessmentCard(_ assessment: SafetyAssessment) -> some View {
        Button {
            Task {
                await viewModel.loadAssessmentById(id: assessment.id)
                showingAssessment = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(assessment.assessmentNumber)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        
                        if let createdAt = assessment.createdAt {
                            Text(formatDate(createdAt))
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Month name extracted from assessment number
                    Text(monthName(from: assessment.assessmentNumber))
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.black)
                        .scaleEffect(monthPulse ? 1.06 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.8)
                            .repeatForever(autoreverses: true),
                            value: monthPulse
                        )
                        .onAppear { monthPulse = true }
                    
                    statusBadge(assessment.status)
                }
                
                HStack(spacing: 16) {
                    if let creator = assessment.CreatedBy {
                        Label("\(creator.firstName) \(creator.lastName)", systemImage: "person.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    if let dept = assessment.Department {
                        Label(dept.name, systemImage: "building.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    if assessment.status == .submitted {
                        Button {
                            Task {
                                await viewModel.editAssessment(id: assessment.id)
                                await viewModel.loadAssessmentById(id: assessment.id)
                                showingAssessment = true
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 12))
                                Text("Edit")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .padding(16)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                assessmentToDelete = assessment
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
            .tint(.red)
        }
    }
    
    // MARK: - Helper Views
    
    private func statusBadge(_ status: WSAStatus) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 6, height: 6)
            Text(status.rawValue)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
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
    
    /// Extracts month name from assessment number like WSA-202603-001-KD → "MARCH"
    private func monthName(from assessmentNumber: String) -> String {
        // Format: WSA-YYYYMM-SEQ-INITIALS
        let parts = assessmentNumber.split(separator: "-")
        guard parts.count >= 2 else { return "" }
        let yyyymm = String(parts[1]) // e.g. "202603"
        guard yyyymm.count == 6,
              let month = Int(yyyymm.suffix(2)),
              month >= 1 && month <= 12 else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        var components = DateComponents()
        components.month = month
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date).uppercased()
        }
        return ""
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}
