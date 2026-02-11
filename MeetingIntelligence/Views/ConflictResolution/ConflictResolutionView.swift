//
//  ConflictResolutionView.swift
//  MeetingIntelligence
//
//  Main view for the Policy-Aware Conflict Resolution Assistant
//

import SwiftUI

struct ConflictResolutionView: View {
    @StateObject private var manager = ConflictResolutionManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedTab: CRTab = .cases
    @State private var showCreateCase = false
    @State private var showUploadPolicy = false
    @State private var showPolicyDetail: WorkplacePolicy?
    @State private var showCaseDetail: ConflictCase?
    
    // Adaptive colors
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    private var cardBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }
    
    enum CRTab: String, CaseIterable {
        case cases = "Cases"
        case policies = "Policies"
        case analytics = "Analytics"
        
        var icon: String {
            switch self {
            case .cases: return "folder.fill"
            case .policies: return "doc.text.fill"
            case .analytics: return "chart.bar.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Tab Bar
                    tabBar
                    
                    // Content
                    TabView(selection: $selectedTab) {
                        casesView
                            .tag(CRTab.cases)
                        
                        policiesView
                            .tag(CRTab.policies)
                        
                        analyticsView
                            .tag(CRTab.analytics)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("Conflict Resolution")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showCreateCase = true
                        } label: {
                            Label("New Case", systemImage: "folder.badge.plus")
                        }
                        
                        Button {
                            showUploadPolicy = true
                        } label: {
                            Label("Upload Policy", systemImage: "doc.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
            .sheet(isPresented: $showCreateCase) {
                CreateCaseView()
            }
            .sheet(isPresented: $showUploadPolicy) {
                PolicyUploadView()
            }
            .sheet(item: $showPolicyDetail) { policy in
                PolicyDetailView(policy: policy)
            }
            .sheet(item: $showCaseDetail) { conflictCase in
                CaseDetailView(caseId: conflictCase.id)
            }
        }
    }
    
    // MARK: - Tab Bar
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(CRTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(selectedTab == tab ? AppColors.primary : textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == tab ?
                        AppColors.primary.opacity(0.1) :
                        Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(cardBackground)
    }
    
    // MARK: - Cases View
    private var casesView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Quick Stats
                quickStatsSection
                
                // Active Policy Banner
                if let policy = manager.activePolicy {
                    activePolicyBanner(policy: policy)
                } else {
                    noPolicyBanner
                }
                
                // Cases List
                casesListSection
            }
            .padding()
        }
    }
    
    // MARK: - Quick Stats
    private var quickStatsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ConflictStatCard(
                    title: "Total Cases",
                    value: "\(manager.totalCases)",
                    icon: "folder.fill",
                    color: AppColors.primary,
                    colorScheme: colorScheme
                )
                
                ConflictStatCard(
                    title: "Open",
                    value: "\(manager.openCases)",
                    icon: "folder.badge.gearshape",
                    color: AppColors.warning,
                    colorScheme: colorScheme
                )
                
                ConflictStatCard(
                    title: "Closed",
                    value: "\(manager.closedCases)",
                    icon: "checkmark.seal.fill",
                    color: AppColors.success,
                    colorScheme: colorScheme
                )
                
                ConflictStatCard(
                    title: "Escalated",
                    value: "\(manager.escalatedCases)",
                    icon: "arrow.up.forward.square.fill",
                    color: AppColors.error,
                    colorScheme: colorScheme
                )
            }
        }
    }
    
    // MARK: - Active Policy Banner
    private func activePolicyBanner(policy: WorkplacePolicy) -> some View {
        Button {
            showPolicyDetail = policy
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.success)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Active Policy")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textSecondary)
                    
                    Text(policy.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    Text("v\(policy.version) • \(policy.sectionCount) sections")
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(textSecondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.success.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.success.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - No Policy Banner
    private var noPolicyBanner: some View {
        Button {
            showUploadPolicy = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.warning)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("No Active Policy")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    Text("Upload a workplace policy to enable System-powered case analysis")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.primary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.warning.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.warning.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Cases List Section
    private var casesListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Cases")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Spacer()
                
                if !manager.cases.isEmpty {
                    Button {
                        // Show all cases
                    } label: {
                        Text("See All")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
            
            if manager.cases.isEmpty {
                emptyCasesState
            } else {
                ForEach(manager.cases.prefix(5)) { conflictCase in
                    CaseRowView(
                        conflictCase: conflictCase,
                        colorScheme: colorScheme,
                        onDelete: {
                            manager.deleteCase(conflictCase)
                        }
                    )
                    .onTapGesture {
                        showCaseDetail = conflictCase
                    }
                }
            }
        }
    }
    
    // MARK: - Empty Cases State
    private var emptyCasesState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(textSecondary.opacity(0.5))
            
            Text("No Cases Yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Text("Create your first conflict case to get started with System-assisted resolution")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                showCreateCase = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Case")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppColors.primary)
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Policies View
    private var policiesView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Upload Policy Button
                uploadPolicyCard
                
                // Policies List
                policiesListSection
            }
            .padding()
        }
    }
    
    // MARK: - Upload Policy Card
    private var uploadPolicyCard: some View {
        Button {
            showUploadPolicy = true
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.1))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upload Policy Document")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    Text("PDF, DOC, or TXT file")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AppColors.primary)
            }
            .padding(16)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(cardBorder, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Policies List Section
    private var policiesListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Policies")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textPrimary)
            
            if manager.policies.isEmpty {
                emptyPoliciesState
            } else {
                ForEach(manager.policies) { policy in
                    PolicyRowView(
                        policy: policy,
                        isActive: manager.activePolicy?.id == policy.id,
                        colorScheme: colorScheme
                    )
                    .onTapGesture {
                        showPolicyDetail = policy
                    }
                }
            }
        }
    }
    
    // MARK: - Empty Policies State
    private var emptyPoliciesState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(textSecondary.opacity(0.5))
            
            Text("No Policies Uploaded")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Text("Upload your workplace policy to enable System-powered conflict analysis and resolution support")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Analytics View
    private var analyticsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Coming soon placeholder
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 60))
                        .foregroundColor(textSecondary.opacity(0.5))
                    
                    Text("Analytics Coming Soon")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    Text("Track case patterns, resolution times, and policy alignment over time")
                        .font(.system(size: 14))
                        .foregroundColor(textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            }
            .padding()
        }
    }
}

// MARK: - Conflict Stat Card
struct ConflictStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let colorScheme: ColorScheme
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(textPrimary)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(color)
        }
        .padding(16)
        .frame(width: 120)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: color.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Case Row View
struct CaseRowView: View {
    let conflictCase: ConflictCase
    let colorScheme: ColorScheme
    var onDelete: (() -> Void)? = nil
    
    @State private var showDeleteConfirmation = false
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Type Icon
            ZStack {
                Circle()
                    .fill(conflictCase.type.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: conflictCase.type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(conflictCase.type.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(conflictCase.displayTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                HStack(spacing: 8) {
                    Text(conflictCase.type.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
                    
                    Text("•")
                        .foregroundColor(textSecondary)
                    
                    Text(conflictCase.formattedIncidentDate)
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
                }
            }
            
            Spacer()
            
            // Status Badge
            Text(conflictCase.status.displayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(conflictCase.status.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(conflictCase.status.color.opacity(0.15))
                .clipShape(Capsule())
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(textSecondary)
        }
        .padding(14)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if onDelete != nil {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .contextMenu {
            if onDelete != nil {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Case", systemImage: "trash")
                }
            }
        }
        .alert("Delete Case", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Are you sure you want to delete \(conflictCase.caseNumber)? This action cannot be undone.")
        }
    }
}

// MARK: - Policy Row View
struct PolicyRowView: View {
    let policy: WorkplacePolicy
    let isActive: Bool
    let colorScheme: ColorScheme
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Document Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.primary.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(policy.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    if isActive {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.success)
                    }
                }
                
                HStack(spacing: 8) {
                    Text("v\(policy.version)")
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
                    
                    Text("•")
                        .foregroundColor(textSecondary)
                    
                    Text("\(policy.sectionCount) sections")
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
                }
            }
            
            Spacer()
            
            // Status Badge
            Text(policy.status.displayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(policy.status.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(policy.status.color.opacity(0.15))
                .clipShape(Capsule())
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(textSecondary)
        }
        .padding(14)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Preview
#Preview {
    ConflictResolutionView()
}
