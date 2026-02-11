//
//  PolicyDetailView.swift
//  MeetingIntelligence
//
//  Displays policy details and structured sections
//

import SwiftUI

struct PolicyDetailView: View {
    @StateObject private var manager = ConflictResolutionManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    let policy: WorkplacePolicy
    
    @State private var searchText = ""
    @State private var selectedSectionType: PolicySectionType?
    @State private var showDeleteAlert = false
    @State private var expandedSections: Set<UUID> = []
    
    // Adaptive colors
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var textTertiary: Color {
        colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    private var cardBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }
    
    // Filtered sections based on search and type filter
    private var filteredSections: [PolicySection] {
        var sections = policy.sections
        
        if let type = selectedSectionType {
            sections = sections.filter { $0.type == type }
        }
        
        if !searchText.isEmpty {
            sections = sections.filter { section in
                section.title.localizedCaseInsensitiveContains(searchText) ||
                section.content.localizedCaseInsensitiveContains(searchText) ||
                section.keywords.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        return sections.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Policy Header
                        policyHeaderSection
                        
                        // Status & Actions
                        statusActionsSection
                        
                        // Search Bar
                        searchBar
                        
                        // Section Type Filter
                        sectionTypeFilter
                        
                        // Sections List
                        sectionsListSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Policy Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if policy.status != .active {
                            Button {
                                manager.activatePolicy(policy)
                            } label: {
                                Label("Activate Policy", systemImage: "checkmark.seal")
                            }
                        }
                        
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Delete Policy", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(textPrimary)
                    }
                }
            }
            .alert("Delete Policy?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    manager.deletePolicy(policy)
                    dismiss()
                }
            } message: {
                Text("This action cannot be undone. All cases using this policy will no longer have policy references.")
            }
        }
    }
    
    // MARK: - Policy Header Section
    private var policyHeaderSection: some View {
        VStack(spacing: 16) {
            // Icon & Name
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.primary.opacity(0.15))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 28))
                        .foregroundColor(AppColors.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(policy.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(textPrimary)
                    
                    Text("Version \(policy.version)")
                        .font(.system(size: 14))
                        .foregroundColor(textSecondary)
                    
                    if let source = policy.documentSource {
                        Text(source.fileName)
                            .font(.system(size: 12))
                            .foregroundColor(textTertiary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            
            // Stats Row
            HStack(spacing: 0) {
                statItem(value: "\(policy.sectionCount)", label: "Sections")
                
                Divider()
                    .frame(height: 40)
                
                statItem(value: policy.formattedEffectiveDate, label: "Effective")
                
                Divider()
                    .frame(height: 40)
                
                statItem(value: policy.status.displayName, label: "Status", color: policy.status.color)
            }
            .padding(.vertical, 12)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
    
    private func statItem(value: String, label: String, color: Color? = nil) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color ?? textPrimary)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Status & Actions Section
    private var statusActionsSection: some View {
        VStack(spacing: 12) {
            if policy.status == .active {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.success)
                    
                    Text("This is the active policy for all new cases")
                        .font(.system(size: 14))
                        .foregroundColor(textPrimary)
                    
                    Spacer()
                }
                .padding(14)
                .background(AppColors.success.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if policy.status == .draft {
                Button {
                    manager.activatePolicy(policy)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 18))
                        
                        Text("Activate This Policy")
                            .font(.system(size: 15, weight: .semibold))
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white)
                    .padding(14)
                    .background(AppColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(textSecondary)
            
            TextField("Search sections...", text: $searchText)
                .foregroundColor(textPrimary)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(textSecondary)
                }
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(cardBorder, lineWidth: 1)
        )
    }
    
    // MARK: - Section Type Filter
    private var sectionTypeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All filter
                PolicyFilterChip(
                    title: "All",
                    isSelected: selectedSectionType == nil,
                    colorScheme: colorScheme
                ) {
                    selectedSectionType = nil
                }
                
                ForEach(PolicySectionType.allCases, id: \.self) { type in
                    let count = policy.sections.filter { $0.type == type }.count
                    if count > 0 {
                        PolicyFilterChip(
                            title: type.displayName,
                            count: count,
                            isSelected: selectedSectionType == type,
                            colorScheme: colorScheme
                        ) {
                            selectedSectionType = type
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Sections List Section
    private var sectionsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sections")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Spacer()
                
                Text("\(filteredSections.count)")
                    .font(.system(size: 14))
                    .foregroundColor(textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(cardBackground)
                    .clipShape(Capsule())
            }
            
            if filteredSections.isEmpty {
                emptySearchState
            } else {
                ForEach(filteredSections) { section in
                    SectionRowView(
                        section: section,
                        isExpanded: expandedSections.contains(section.id),
                        colorScheme: colorScheme,
                        onToggle: {
                            withAnimation(.spring(response: 0.3)) {
                                if expandedSections.contains(section.id) {
                                    expandedSections.remove(section.id)
                                } else {
                                    expandedSections.insert(section.id)
                                }
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Empty Search State
    private var emptySearchState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(textTertiary)
            
            Text("No sections found")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(textSecondary)
            
            Text("Try adjusting your search or filters")
                .font(.system(size: 13))
                .foregroundColor(textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Policy Filter Chip
struct PolicyFilterChip: View {
    let title: String
    var count: Int? = nil
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                
                if let count = count {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : AppColors.primary)
                }
            }
            .foregroundColor(isSelected ? .white : textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? AppColors.primary : cardBackground)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Section Row View
struct SectionRowView: View {
    let section: PolicySection
    let isExpanded: Bool
    let colorScheme: ColorScheme
    let onToggle: () -> Void
    
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    // Section Type Icon
                    Image(systemName: section.type.icon)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.primary)
                        .frame(width: 32, height: 32)
                        .background(AppColors.primary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if !section.sectionNumber.isEmpty {
                            Text(section.sectionNumber)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppColors.primary)
                        }
                        
                        Text(section.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(textPrimary)
                            .lineLimit(isExpanded ? nil : 1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(14)
            }
            
            // Content (when expanded)
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    Text(section.content)
                        .font(.system(size: 14))
                        .foregroundColor(textSecondary)
                        .lineSpacing(4)
                    
                    if !section.keywords.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(section.keywords, id: \.self) { keyword in
                                    Text(keyword)
                                        .font(.system(size: 11))
                                        .foregroundColor(AppColors.primary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(AppColors.primary.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Preview
#Preview {
    PolicyDetailView(policy: WorkplacePolicy(
        name: "Employee Conduct Policy",
        version: "2.1",
        effectiveDate: Date(),
        status: .active,
        sections: [
            PolicySection(sectionNumber: "1", title: "Introduction", content: "This policy establishes guidelines for employee conduct...", type: .overview),
            PolicySection(sectionNumber: "2", title: "Definitions", content: "For the purposes of this policy, the following definitions apply...", type: .definitions),
            PolicySection(sectionNumber: "3", title: "Expected Behavior", content: "All employees are expected to conduct themselves professionally...", type: .guidelines)
        ]
    ))
}
