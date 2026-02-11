//
//  SummaryTab.swift
//  MeetingIntelligence
//
//  Phase 2 - AI Summary View (Read-Only)
//  Displays Key Points, Decisions, Risks, Topics, and Sentiment
//

import SwiftUI

// MARK: - Speaker Stat Model (for parsing JSON speakerStats)
struct SpeakerStat: Codable, Hashable {
    let speakerLabel: String
    let speakingDuration: Int
    let wordCount: Int
    let turnCount: Int
}

struct SummaryTab: View {
    @ObservedObject var viewModel: MeetingDetailViewModel
    @State private var expandedSections: Set<SummarySection> = Set(SummarySection.allCases)
    
    // Parsed speaker stats
    private var parsedSpeakerStats: [SpeakerStat] {
        guard let jsonString = viewModel.summary?.speakerStats else { return [] }
        guard let data = jsonString.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([SpeakerStat].self, from: data)) ?? []
    }
    
    var body: some View {
        if let summary = viewModel.summary {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Overview Card
                    overviewCard(summary)
                    
                    // Engagement Score
                    if let score = summary.engagementScore {
                        engagementScoreCard(score)
                    }
                    
                    // Sentiment Card
                    if let sentiment = summary.sentiment {
                        sentimentCard(sentiment)
                    }
                    
                    // Key Points Section
                    if !summary.allKeyPoints.isEmpty {
                        collapsibleSection(.keyPoints) {
                            keyPointsContent(summary.allKeyPoints)
                        }
                    }
                    
                    // Decisions Section
                    if !summary.allDecisions.isEmpty {
                        collapsibleSection(.decisions) {
                            decisionsContent(summary.allDecisions)
                        }
                    }
                    
                    // Next Steps Section (renamed from Topics)
                    if !summary.allNextSteps.isEmpty {
                        collapsibleSection(.topics) {
                            topicsContent(summary.allNextSteps)
                        }
                    }
                    
                    // Speaker Stats
                    if !parsedSpeakerStats.isEmpty {
                        collapsibleSection(.speakerStats) {
                            speakerStatsContent(parsedSpeakerStats)
                        }
                    }
                }
                .padding(AppSpacing.md)
            }
            .background(AppColors.background)
            .refreshable {
                await viewModel.refreshMeeting()
            }
        } else {
            emptyState
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(AppColors.textTertiary)
            
            Text("No Summary Available")
                .font(AppTypography.title3)
                .foregroundColor(AppColors.textPrimary)
            
            Text("System-generated insights will appear here once the meeting has been processed.")
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            
            if viewModel.meeting.status == .processing {
                HStack(spacing: AppSpacing.sm) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                    Text("Generating summary...")
                        .font(AppTypography.footnote)
                        .foregroundColor(AppColors.primary)
                }
                .padding(.top, AppSpacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
    }
    
    // MARK: - Overview Card
    private func overviewCard(_ summary: MeetingSummary) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(AppColors.primary)
                Text("Overview")
                    .font(AppTypography.headline)
                
                Spacer()
                
                Image(systemName: "sparkles")
                    .foregroundColor(AppColors.primary)
                    .font(.caption)
            }
            
            // Use displaySummary which checks executiveSummary first, then overview
            let summaryText = summary.displaySummary
            if summaryText != "No summary available" {
                Text(summaryText)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(4)
            } else {
                Text("No overview available.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textTertiary)
                    .italic()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(
            LinearGradient(
                colors: [AppColors.primary.opacity(0.08), AppColors.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large))
    }
    
    // MARK: - Engagement Score Card
    private func engagementScoreCard(_ score: Double) -> some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(AppColors.accent)
                Text("Engagement Score")
                    .font(AppTypography.headline)
                
                Spacer()
            }
            
            HStack(alignment: .bottom, spacing: AppSpacing.sm) {
                Text("\(Int(score * 100))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(engagementColor(score))
                
                Text("%")
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.bottom, 8)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(engagementLevel(score))
                        .font(AppTypography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(engagementColor(score))
                    
                    Text("engagement")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.surfaceSecondary)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(engagementColor(score))
                        .frame(width: geometry.size.width * CGFloat(score), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(AppSpacing.lg)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large))
    }
    
    private func engagementColor(_ score: Double) -> Color {
        switch score {
        case 0..<0.4: return AppColors.error
        case 0.4..<0.7: return AppColors.warning
        default: return AppColors.success
        }
    }
    
    private func engagementLevel(_ score: Double) -> String {
        switch score {
        case 0..<0.4: return "Low"
        case 0.4..<0.7: return "Moderate"
        case 0.7..<0.85: return "High"
        default: return "Excellent"
        }
    }
    
    // MARK: - Sentiment Card
    private func sentimentCard(_ sentiment: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Circle()
                .fill(sentimentGradient(sentiment))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: sentimentIcon(sentiment))
                        .font(.title2)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Overall Sentiment")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                
                Text(sentiment.capitalized)
                    .font(AppTypography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(sentimentColor(sentiment))
            }
            
            Spacer()
        }
        .padding(AppSpacing.lg)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large))
    }
    
    private func sentimentIcon(_ sentiment: String) -> String {
        switch sentiment.lowercased() {
        case "positive": return "face.smiling"
        case "negative": return "face.frowning"
        case "mixed": return "face.uncertain"
        default: return "minus.circle"
        }
    }
    
    private func sentimentColor(_ sentiment: String) -> Color {
        switch sentiment.lowercased() {
        case "positive": return AppColors.success
        case "negative": return AppColors.error
        case "mixed": return AppColors.warning
        default: return AppColors.textSecondary
        }
    }
    
    private func sentimentGradient(_ sentiment: String) -> LinearGradient {
        let color = sentimentColor(sentiment)
        return LinearGradient(
            colors: [color, color.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Collapsible Section
    @ViewBuilder
    private func collapsibleSection<Content: View>(
        _ section: SummarySection,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if expandedSections.contains(section) {
                        expandedSections.remove(section)
                    } else {
                        expandedSections.insert(section)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: section.icon)
                        .foregroundColor(section.color)
                        .frame(width: 24)
                    
                    Text(section.title)
                        .font(AppTypography.headline)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: expandedSections.contains(section) ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(AppSpacing.lg)
            }
            .buttonStyle(.plain)
            
            // Content
            if expandedSections.contains(section) {
                Divider()
                    .padding(.horizontal, AppSpacing.lg)
                
                content()
                    .padding(AppSpacing.lg)
                    .padding(.top, 0)
            }
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large))
    }
    
    // MARK: - Key Points Content
    private func keyPointsContent(_ points: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    Text("\(index + 1)")
                        .font(AppTypography.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(AppColors.primary)
                        .clipShape(Circle())
                    
                    Text(point)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Decisions Content
    private func decisionsContent(_ decisions: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ForEach(Array(decisions.enumerated()), id: \.offset) { _, decision in
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(AppColors.success)
                        .font(.title3)
                    
                    Text(decision)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Topics Content
    private func topicsContent(_ topics: [String]) -> some View {
        FlowLayout(spacing: AppSpacing.sm) {
            ForEach(topics, id: \.self) { topic in
                TopicTag(topic: topic)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Speaker Stats Content
    private func speakerStatsContent(_ stats: [SpeakerStat]) -> some View {
        VStack(spacing: AppSpacing.md) {
            ForEach(stats, id: \.speakerLabel) { stat in
                SpeakerStatRow(stat: stat, totalDuration: totalSpeakingTime(stats))
            }
        }
    }
    
    private func totalSpeakingTime(_ stats: [SpeakerStat]) -> Int {
        stats.reduce(0) { $0 + $1.speakingDuration }
    }
}

// MARK: - Summary Section Enum
enum SummarySection: String, CaseIterable {
    case keyPoints
    case decisions
    case topics
    case speakerStats
    
    var title: String {
        switch self {
        case .keyPoints: return "Key Points"
        case .decisions: return "Decisions Made"
        case .topics: return "Topics Discussed"
        case .speakerStats: return "Speaker Statistics"
        }
    }
    
    var icon: String {
        switch self {
        case .keyPoints: return "lightbulb.fill"
        case .decisions: return "checkmark.seal.fill"
        case .topics: return "tag.fill"
        case .speakerStats: return "person.wave.2.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .keyPoints: return AppColors.warning
        case .decisions: return AppColors.success
        case .topics: return AppColors.info
        case .speakerStats: return AppColors.secondary
        }
    }
}

// MARK: - Topic Tag
struct TopicTag: View {
    let topic: String
    
    var body: some View {
        Text(topic)
            .font(AppTypography.footnote)
            .fontWeight(.medium)
            .foregroundColor(AppColors.info)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppColors.info.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Speaker Stat Row
struct SpeakerStatRow: View {
    let stat: SpeakerStat
    let totalDuration: Int
    
    private var percentage: Double {
        guard totalDuration > 0 else { return 0 }
        return Double(stat.speakingDuration) / Double(totalDuration)
    }
    
    private var speakerColor: Color {
        let colors: [Color] = [
            AppColors.primary,
            AppColors.secondary,
            AppColors.accent,
            Color.purple,
            Color.orange
        ]
        let hash = abs(stat.speakerLabel.hashValue)
        return colors[hash % colors.count]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Circle()
                    .fill(speakerColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(stat.speakerLabel.prefix(1)).uppercased())
                            .font(AppTypography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(speakerColor)
                    )
                
                Text(stat.speakerLabel)
                    .font(AppTypography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(percentage * 100))%")
                        .font(AppTypography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(speakerColor)
                    
                    Text(formatDuration(stat.speakingDuration))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppColors.surfaceSecondary)
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(speakerColor)
                        .frame(width: geometry.size.width * CGFloat(percentage), height: 6)
                }
            }
            .frame(height: 6)
            
            // Word count
            Text("\(stat.wordCount) words • \(stat.turnCount) turns")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%dm %02ds", minutes, secs)
    }
}

// MARK: - Flow Layout (for Topics)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subviews: subviews, proposal: proposal)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, proposal: proposal)
        
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }
    
    private func layout(subviews: Subviews, proposal: ProposedViewSize) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var frames: [CGRect] = []
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
        
        return (CGSize(width: maxWidth, height: currentY + lineHeight), frames)
    }
}

// MARK: - Preview
#Preview {
    Text("Summary Tab Preview")
}
