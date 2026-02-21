//
//  ConflictAnalyticsView.swift
//  MeetingIntelligence
//
//  Enterprise-Grade Analytics Dashboard for Conflict Resolution
//  Displays comprehensive metrics, trends, and breakdowns
//

import SwiftUI
import Charts

// MARK: - Main Analytics View

struct ConflictAnalyticsView: View {
    @StateObject private var analyticsService = ConflictAnalyticsService.shared
    @ObservedObject private var manager = ConflictResolutionManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedTimeRange: TimeRange = .allTime
    @State private var isRefreshing = false
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    enum TimeRange: String, CaseIterable {
        case last30Days = "30 Days"
        case last90Days = "90 Days"
        case last12Months = "12 Months"
        case allTime = "All Time"
        
        var startDate: Date? {
            let calendar = Calendar.current
            switch self {
            case .last30Days:
                return calendar.date(byAdding: .day, value: -30, to: Date())
            case .last90Days:
                return calendar.date(byAdding: .day, value: -90, to: Date())
            case .last12Months:
                return calendar.date(byAdding: .month, value: -12, to: Date())
            case .allTime:
                return nil
            }
        }
    }
    
    var body: some View {
        Group {
            if analyticsService.isLoading && analyticsService.analyticsData == nil {
                loadingView
            } else if let error = analyticsService.errorMessage, analyticsService.analyticsData == nil {
                errorView(message: error)
            } else if let data = analyticsService.analyticsData {
                analyticsContent(data: data)
            } else {
                emptyStateView
            }
        }
        .task {
            await loadAnalytics()
        }
    }
    
    // MARK: - Main Content
    
    private func analyticsContent(data: ConflictAnalyticsData) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Time Range Picker
                timeRangePicker
                
                // Summary Cards
                summaryCards(data: data)
                
                // Resolution Metrics
                resolutionMetricsCard(data: data)
                
                // Status Breakdown Chart
                if !data.statusBreakdown.isEmpty {
                    statusBreakdownChart(data: data)
                }
                
                // Case Type Breakdown
                if !data.typeBreakdown.isEmpty {
                    typeBreakdownChart(data: data)
                }
                
                // Monthly Trends Chart
                if !data.monthlyTrends.isEmpty {
                    monthlyTrendsChart(data: data)
                }
                
                // Action Types Distribution
                if !data.actionTypeBreakdown.isEmpty {
                    actionTypeChart(data: data)
                }
                
                // Closure Reasons
                if !data.closureReasonBreakdown.isEmpty {
                    closureReasonsCard(data: data)
                }
                
                // Department Breakdown
                if !data.departmentBreakdown.isEmpty {
                    departmentBreakdownCard(data: data)
                }
                
                // Last Updated
                lastUpdatedFooter(data: data)
            }
            .padding()
        }
        .refreshable {
            await loadAnalytics()
        }
    }
    
    // MARK: - Time Range Picker
    
    private var timeRangePicker: some View {
        HStack {
            Text("Time Range")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(textSecondary)
            
            Spacer()
            
            Menu {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button {
                        selectedTimeRange = range
                        Task { await loadAnalytics() }
                    } label: {
                        HStack {
                            Text(range.rawValue)
                            if range == selectedTimeRange {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedTimeRange.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                }
                .foregroundColor(AppColors.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppColors.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Summary Cards
    
    private func summaryCards(data: ConflictAnalyticsData) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            AnalyticsSummaryCard(
                title: "Total Cases",
                value: "\(data.summary.totalCases)",
                icon: "folder.fill",
                color: .blue,
                colorScheme: colorScheme
            )
            
            AnalyticsSummaryCard(
                title: "Active Cases",
                value: "\(data.summary.activeCases)",
                icon: "clock.fill",
                color: .orange,
                colorScheme: colorScheme
            )
            
            AnalyticsSummaryCard(
                title: "Closed Cases",
                value: "\(data.summary.closedCases)",
                icon: "checkmark.circle.fill",
                color: .green,
                colorScheme: colorScheme
            )
            
            AnalyticsSummaryCard(
                title: "Resolution Rate",
                value: "\(String(format: "%.1f", data.summary.resolutionRate))%",
                icon: "chart.line.uptrend.xyaxis",
                color: .purple,
                colorScheme: colorScheme
            )
        }
    }
    
    // MARK: - Resolution Metrics Card
    
    private func resolutionMetricsCard(data: ConflictAnalyticsData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "timer")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.primary)
                
                Text("Resolution Metrics")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .center, spacing: 4) {
                    Text("\(String(format: "%.1f", data.resolutionMetrics.averageDays))")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.primary)
                    Text("Avg Days")
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 50)
                
                VStack(alignment: .center, spacing: 4) {
                    Text("\(data.resolutionMetrics.minDays)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.green)
                    Text("Min Days")
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 50)
                
                VStack(alignment: .center, spacing: 4) {
                    Text("\(data.resolutionMetrics.maxDays)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.orange)
                    Text("Max Days")
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Status Breakdown Chart
    
    private func statusBreakdownChart(data: ConflictAnalyticsData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.primary)
                
                Text("Status Distribution")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)
            }
            
            if #available(iOS 17.0, *) {
                Chart(data.statusBreakdown) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(colorForStatus(item.status))
                    .cornerRadius(4)
                }
                .frame(height: 200)
            } else {
                Chart(data.statusBreakdown) { item in
                    BarMark(
                        x: .value("Status", item.displayName),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(colorForStatus(item.status))
                    .cornerRadius(4)
                }
                .frame(height: 200)
            }
            
            // Legend
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(data.statusBreakdown) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(colorForStatus(item.status))
                            .frame(width: 10, height: 10)
                        
                        Text(item.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(textSecondary)
                        
                        Spacer()
                        
                        Text("\(item.count)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(textPrimary)
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Type Breakdown Chart
    
    private func typeBreakdownChart(data: ConflictAnalyticsData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "rectangle.3.group.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.primary)
                
                Text("Case Types")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)
            }
            
            Chart(data.typeBreakdown) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Type", item.displayName)
                )
                .foregroundStyle(colorForType(item.type))
                .cornerRadius(4)
            }
            .frame(height: CGFloat(data.typeBreakdown.count * 50))
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Monthly Trends Chart
    
    private func monthlyTrendsChart(data: ConflictAnalyticsData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.primary)
                
                Text("Monthly Trends")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)
            }
            
            Chart {
                ForEach(data.monthlyTrends) { item in
                    LineMark(
                        x: .value("Month", item.displayMonth),
                        y: .value("Created", item.created)
                    )
                    .foregroundStyle(.blue)
                    .symbol(.circle)
                    
                    LineMark(
                        x: .value("Month", item.displayMonth),
                        y: .value("Closed", item.closed)
                    )
                    .foregroundStyle(.green)
                    .symbol(.square)
                }
            }
            .frame(height: 200)
            .chartLegend(position: .bottom)
            
            // Legend
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 10, height: 10)
                    Text("Created")
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
                }
                
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.green)
                        .frame(width: 10, height: 10)
                    Text("Closed")
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Action Type Chart
    
    private func actionTypeChart(data: ConflictAnalyticsData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.primary)
                
                Text("Action Types Taken")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)
            }
            
            Chart(data.actionTypeBreakdown) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Action", item.displayName)
                )
                .foregroundStyle(colorForAction(item.actionType))
                .cornerRadius(4)
            }
            .frame(height: CGFloat(data.actionTypeBreakdown.count * 50))
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Closure Reasons Card
    
    private func closureReasonsCard(data: ConflictAnalyticsData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.primary)
                
                Text("Closure Reasons")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)
            }
            
            VStack(spacing: 12) {
                ForEach(data.closureReasonBreakdown) { item in
                    HStack {
                        Text(item.displayName)
                            .font(.system(size: 14))
                            .foregroundColor(textPrimary)
                        
                        Spacer()
                        
                        Text("\(item.count)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppColors.primary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    if item.id != data.closureReasonBreakdown.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Department Breakdown Card
    
    private func departmentBreakdownCard(data: ConflictAnalyticsData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.primary)
                
                Text("Cases by Department")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)
            }
            
            VStack(spacing: 12) {
                ForEach(data.departmentBreakdown.prefix(10)) { item in
                    VStack(spacing: 8) {
                        HStack {
                            Text(item.department)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(textPrimary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(item.total) total")
                                .font(.system(size: 12))
                                .foregroundColor(textSecondary)
                        }
                        
                        // Progress bar showing active vs closed
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)
                                
                                HStack(spacing: 1) {
                                    if item.closed > 0 {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.green)
                                            .frame(width: geometry.size.width * CGFloat(item.closed) / CGFloat(max(item.total, 1)), height: 8)
                                    }
                                    
                                    if item.active > 0 {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.orange)
                                            .frame(width: geometry.size.width * CGFloat(item.active) / CGFloat(max(item.total, 1)), height: 8)
                                    }
                                }
                            }
                        }
                        .frame(height: 8)
                        
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text("Closed: \(item.closed)")
                                    .font(.system(size: 11))
                                    .foregroundColor(textSecondary)
                            }
                            
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 8, height: 8)
                                Text("Active: \(item.active)")
                                    .font(.system(size: 11))
                                    .foregroundColor(textSecondary)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    if item.id != data.departmentBreakdown.prefix(10).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Last Updated Footer
    
    private func lastUpdatedFooter(data: ConflictAnalyticsData) -> some View {
        HStack {
            Spacer()
            
            if let lastFetch = analyticsService.lastFetchDate {
                Text("Last updated: \(lastFetch, style: .relative) ago")
                    .font(.system(size: 12))
                    .foregroundColor(textSecondary)
            }
            
            Spacer()
        }
        .padding(.top, 8)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading Analytics...")
                .font(.system(size: 16))
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Unable to Load Analytics")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                Task { await loadAnalytics() }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(textSecondary.opacity(0.5))
            
            Text("No Analytics Data")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Text("Create cases to start seeing analytics and insights")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                Task { await loadAnalytics() }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.primary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Helper Functions
    
    private func loadAnalytics() async {
        guard let organizationId = manager.currentOrganizationId else {
            print("❌ Cannot load analytics: organizationId not set")
            return
        }
        
        do {
            try await analyticsService.fetchAnalytics(
                organizationId: organizationId,
                startDate: selectedTimeRange.startDate,
                endDate: nil,
                facilityId: manager.currentFacilityId
            )
        } catch {
            print("❌ Failed to load analytics: \(error)")
        }
    }
    
    private func colorForStatus(_ status: String) -> Color {
        switch status {
        case "DRAFT": return .gray
        case "IN_PROGRESS": return .blue
        case "PENDING_REVIEW": return .orange
        case "AWAITING_ACTION": return .yellow
        case "CLOSED": return .green
        case "ESCALATED": return .red
        default: return .gray
        }
    }
    
    private func colorForType(_ type: String) -> Color {
        switch type {
        case "CONFLICT": return .blue
        case "CONDUCT": return .orange
        case "SAFETY": return .red
        case "OTHER": return .purple
        default: return .gray
        }
    }
    
    private func colorForAction(_ action: String?) -> Color {
        guard let action = action else { return .gray }
        switch action {
        case "COACHING": return .green
        case "COUNSELING": return .blue
        case "WRITTEN_WARNING": return .orange
        case "ESCALATE_TO_HR": return .red
        default: return .gray
        }
    }
}

// MARK: - Summary Card Component

struct AnalyticsSummaryCard: View {
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(textPrimary)
            
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(color)
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: color.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Preview

#Preview {
    ConflictAnalyticsView()
}
