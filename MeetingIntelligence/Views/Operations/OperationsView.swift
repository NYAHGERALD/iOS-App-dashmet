//
//  OperationsView.swift
//  MeetingIntelligence
//
//  Operations Hub - View & Manage Reported Issues
//

import SwiftUI

struct OperationsView: View {
    @StateObject private var operationsService = OperationsService.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showReportIssue = false
    @State private var selectedStatusFilter: String? = nil
    @State private var selectedPriorityFilter: String? = nil
    @State private var filterAnimating = false
    var onMenuTap: () -> Void
    
    private var filteredIssues: [OperationsIssue] {
        operationsService.issues.filter { issue in
            let statusMatch = selectedStatusFilter == nil || issue.status == selectedStatusFilter
            let priorityMatch = selectedPriorityFilter == nil || issue.priority == selectedPriorityFilter
            return statusMatch && priorityMatch
        }
    }
    
    private var isFilterActive: Bool {
        selectedStatusFilter != nil || selectedPriorityFilter != nil
    }
    
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                if operationsService.isLoading && operationsService.issues.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading issues...")
                            .font(.system(size: 14))
                            .foregroundColor(textSecondary)
                    }
                } else if operationsService.issues.isEmpty {
                    emptyState
                } else if filteredIssues.isEmpty && isFilterActive {
                    filteredEmptyState
                } else {
                    issuesList
                }
                
                // Floating Report Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showReportIssue = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Report")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [AppColors.primary, AppColors.secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: AppColors.primary.opacity(0.35), radius: 8, x: 0, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Operations")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onMenuTap()
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(textPrimary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Section("Status") {
                            Button {
                                selectedStatusFilter = nil
                            } label: {
                                if selectedStatusFilter == nil {
                                    Label("All Statuses", systemImage: "checkmark")
                                } else {
                                    Text("All Statuses")
                                }
                            }
                            ForEach(["OPEN", "IN_PROGRESS", "RESOLVED", "CLOSED"], id: \.self) { status in
                                Button {
                                    selectedStatusFilter = selectedStatusFilter == status ? nil : status
                                } label: {
                                    if selectedStatusFilter == status {
                                        Label(statusLabel(status), systemImage: "checkmark")
                                    } else {
                                        Text(statusLabel(status))
                                    }
                                }
                            }
                        }
                        Section("Priority") {
                            Button {
                                selectedPriorityFilter = nil
                            } label: {
                                if selectedPriorityFilter == nil {
                                    Label("All Priorities", systemImage: "checkmark")
                                } else {
                                    Text("All Priorities")
                                }
                            }
                            ForEach(["LOW", "MEDIUM", "HIGH", "CRITICAL"], id: \.self) { priority in
                                Button {
                                    selectedPriorityFilter = selectedPriorityFilter == priority ? nil : priority
                                } label: {
                                    if selectedPriorityFilter == priority {
                                        Label(priority.capitalized, systemImage: "checkmark")
                                    } else {
                                        Text(priority.capitalized)
                                    }
                                }
                            }
                        }
                        if isFilterActive {
                            Section {
                                Button(role: .destructive) {
                                    selectedStatusFilter = nil
                                    selectedPriorityFilter = nil
                                } label: {
                                    Label("Clear Filters", systemImage: "xmark.circle")
                                }
                            }
                        }
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 20))
                                .foregroundColor(isFilterActive ? AppColors.primary : textPrimary)
                            
                            if isFilterActive {
                                Circle()
                                    .fill(AppColors.primary)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showReportIssue) {
                ReportIssueView()
            }
            .onChange(of: showReportIssue) { newValue in
                if !newValue {
                    // Refresh list when sheet is dismissed
                    Task { await operationsService.fetchIssues() }
                }
            }
            .task {
                await operationsService.fetchIssues()
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "exclamationmark.bubble")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text("No Issues Reported")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(textPrimary)
            
            Text("Report machine or quality issues to track and resolve them quickly.")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showReportIssue = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("Report an Issue")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Filtered Empty State
    private var filteredEmptyState: some View {
        VStack(spacing: 24) {
            // Animated filter icon artwork
            ZStack {
                // Outer pulsing ring
                Circle()
                    .stroke(AppColors.primary.opacity(0.15), lineWidth: 2)
                    .frame(width: 130, height: 130)
                    .scaleEffect(filterAnimating ? 1.15 : 1.0)
                    .opacity(filterAnimating ? 0.0 : 0.6)
                    .animation(
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: false),
                        value: filterAnimating
                    )
                
                // Middle ring
                Circle()
                    .stroke(AppColors.primary.opacity(0.1), lineWidth: 1.5)
                    .frame(width: 110, height: 110)
                    .scaleEffect(filterAnimating ? 1.1 : 1.0)
                    .opacity(filterAnimating ? 0.0 : 0.4)
                    .animation(
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: false).delay(0.4),
                        value: filterAnimating
                    )
                
                // Background circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.primary.opacity(0.08), AppColors.secondary.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                // Filter icon with sliders animation
                ZStack {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.primary, AppColors.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(filterAnimating ? 8 : -8))
                        .animation(
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: filterAnimating
                        )
                    
                    // Small magnifying glass overlay
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.warning)
                        .offset(x: 22, y: -22)
                        .scaleEffect(filterAnimating ? 1.15 : 0.9)
                        .animation(
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                            value: filterAnimating
                        )
                }
            }
            
            VStack(spacing: 8) {
                Text("No Matching Issues")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(textPrimary)
                
                Text("Try adjusting your filters to see more results.")
                    .font(.system(size: 14))
                    .foregroundColor(textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    selectedStatusFilter = nil
                    selectedPriorityFilter = nil
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 14))
                    Text("Clear Filters")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(AppColors.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(AppColors.primary.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .onAppear { filterAnimating = true }
    }
    
    // MARK: - Issues List
    private var issuesList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredIssues) { issue in
                    NavigationLink(destination: IssueDetailView(issue: issue)) {
                        issueRow(issue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .refreshable {
            await operationsService.fetchIssues()
        }
    }
    
    private func issueRow(_ issue: OperationsIssue) -> some View {
        HStack(spacing: 12) {
            // Status color indicator
            Circle()
                .fill(statusColor(issue.status))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textPrimary)
                    .lineLimit(1)
                
                Text(issue.issueNumber)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.primary)
            }
            
            Spacer()
            
            // Priority
            priorityBadge(issue.priority)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(cardBorder, lineWidth: 1)
        )
        .padding(.vertical, 4)
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status {
        case "OPEN": return AppColors.info
        case "IN_PROGRESS": return AppColors.warning
        case "RESOLVED": return AppColors.success
        case "CLOSED": return AppColors.textTertiary
        default: return AppColors.info
        }
    }
    
    private func statusLabel(_ status: String) -> String {
        switch status {
        case "OPEN": return "Open"
        case "IN_PROGRESS": return "In Progress"
        case "RESOLVED": return "Resolved"
        case "CLOSED": return "Closed"
        default: return status
        }
    }
    
    private func priorityBadge(_ priority: String) -> some View {
        let color: Color = {
            switch priority {
            case "LOW": return AppColors.success
            case "MEDIUM": return AppColors.warning
            case "HIGH": return .orange
            case "CRITICAL": return AppColors.error
            default: return AppColors.info
            }
        }()
        
        return Text(priority)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Issue Detail View
struct IssueDetailView: View {
    let issue: OperationsIssue
    @Environment(\.colorScheme) private var colorScheme
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6) }
    private var textTertiary: Color { colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4) }
    private var cardBackground: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.white }
    private var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08) }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                headerSection
                
                // Description
                detailCard(title: "Description") {
                    Text(issue.description)
                        .font(.system(size: 14))
                        .foregroundColor(textPrimary)
                }
                
                // Location
                detailCard(title: "Location") {
                    locationContent
                }
                
                // Reporter & Dates
                detailCard(title: "Details") {
                    detailsContent
                }
                
                // Photos
                if let photos = issue.photos, !photos.isEmpty {
                    detailCard(title: "Photos (\(photos.count))") {
                        photosGrid(photos)
                    }
                }
            }
            .padding()
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(issue.issueNumber)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Type + Priority + Status
            HStack(spacing: 8) {
                // Type
                HStack(spacing: 4) {
                    Image(systemName: issue.type == "MACHINE" ? "gearshape.2" : "checkmark.seal")
                        .font(.system(size: 11))
                    Text(issue.type == "MACHINE" ? "Machine" : "Quality")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(issue.type == "MACHINE" ? AppColors.warning : AppColors.info)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((issue.type == "MACHINE" ? AppColors.warning : AppColors.info).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                
                // Priority
                priorityTag(issue.priority)
                
                Spacer()
                
                // Status
                statusTag(issue.status)
            }
            
            Text(issue.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(textPrimary)
        }
    }
    
    // MARK: - Location
    private var locationContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let dept = issue.Department {
                infoRow(icon: "building.2", label: "Department", value: dept.name)
            }
            if let shift = issue.Shift {
                infoRow(icon: "clock", label: "Shift", value: shift.name)
            }
            if let area = issue.Area {
                infoRow(icon: "square.grid.2x2", label: "Area", value: area.name)
            }
            if let line = issue.Line {
                infoRow(icon: "arrow.right.square", label: "Line", value: line.name)
            }
            if let equip = issue.Equipment {
                infoRow(icon: "wrench.and.screwdriver", label: "Equipment", value: equip.name)
            }
            if let comp = issue.Component {
                infoRow(icon: "cpu", label: "Component", value: comp.name)
            }
        }
    }
    
    // MARK: - Details
    private var detailsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let reporter = issue.ReportedBy {
                infoRow(icon: "person", label: "Reported By", value: "\(reporter.firstName) \(reporter.lastName)")
            }
            if let date = issue.createdAt {
                infoRow(icon: "calendar", label: "Date", value: formatDate(date))
            }
        }
    }
    
    // MARK: - Photos Grid
    private func photosGrid(_ photos: [IssuePhoto]) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 8) {
            ForEach(photos) { photo in
                AsyncImage(url: URL(string: photo.url)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 100)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundColor(textTertiary)
                            }
                    case .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 100)
                            .overlay { ProgressView() }
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    private func detailCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(cardBorder, lineWidth: 1)
        )
    }
    
    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(textTertiary)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(textPrimary)
        }
    }
    
    private func priorityTag(_ priority: String) -> some View {
        let color: Color = {
            switch priority {
            case "LOW": return AppColors.success
            case "MEDIUM": return AppColors.warning
            case "HIGH": return .orange
            case "CRITICAL": return AppColors.error
            default: return AppColors.info
            }
        }()
        
        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(priority)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private func statusTag(_ status: String) -> some View {
        let (color, label): (Color, String) = {
            switch status {
            case "OPEN": return (AppColors.info, "Open")
            case "IN_PROGRESS": return (AppColors.warning, "In Progress")
            case "RESOLVED": return (AppColors.success, "Resolved")
            case "CLOSED": return (AppColors.textTertiary, "Closed")
            default: return (AppColors.info, status)
            }
        }()
        
        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .short
            return display.string(from: date)
        }
        return dateString
    }
}

#Preview {
    OperationsView(onMenuTap: {})
}
