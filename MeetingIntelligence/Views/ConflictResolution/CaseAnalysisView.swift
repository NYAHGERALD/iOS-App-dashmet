//
//  CaseAnalysisView.swift
//  MeetingIntelligence
//
//  AI Analysis Results View for Conflict Resolution
//  Phase 4: Initial AI Comparison
//

import SwiftUI

// MARK: - Case Analysis View
struct CaseAnalysisView: View {
    let analysisResult: AIComparisonResult
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab = 0
    
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
        ScrollView {
            VStack(spacing: 20) {
                // Analysis Header
                analysisHeader
                
                // Tab Selector
                tabSelector
                
                // Tab Content
                switch selectedTab {
                case 0:
                    summaryTab
                case 1:
                    comparisonTab
                case 2:
                    detailsTab
                default:
                    summaryTab
                }
            }
            .padding()
        }
    }
    
    // MARK: - Analysis Header
    private var analysisHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundColor(AppColors.primary)
            
            Text("System Analysis Complete")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(textPrimary)
            
            Text("Generated \(formattedDate(analysisResult.generatedAt))")
                .font(.system(size: 13))
                .foregroundColor(textSecondary)
            
            // Stats row
            HStack(spacing: 20) {
                statBadge(
                    count: analysisResult.agreementPoints.count,
                    label: "Agreements",
                    color: .green
                )
                statBadge(
                    count: analysisResult.contradictions.count,
                    label: "Contradictions",
                    color: .red
                )
                statBadge(
                    count: analysisResult.missingDetails.count,
                    label: "Unclear",
                    color: .orange
                )
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func statBadge(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(textSecondary)
        }
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(title: "Summary", index: 0)
            tabButton(title: "Compare", index: 1)
            tabButton(title: "Details", index: 2)
        }
        .background(Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func tabButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: selectedTab == index ? .semibold : .regular))
                .foregroundColor(selectedTab == index ? .white : textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selectedTab == index ? AppColors.primary : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    // MARK: - Summary Tab
    private var summaryTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Neutral Summary
            VStack(alignment: .leading, spacing: 12) {
                Label("Incident Summary", systemImage: "doc.text.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Text(analysisResult.neutralSummary)
                    .font(.system(size: 14))
                    .foregroundColor(textSecondary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            
            // Agreement Points
            if !analysisResult.agreementPoints.isEmpty {
                analysisSection(
                    title: "Agreement Points",
                    icon: "checkmark.circle.fill",
                    iconColor: .green,
                    items: analysisResult.agreementPoints,
                    itemColor: .green
                )
            }
            
            // Contradictions
            if !analysisResult.contradictions.isEmpty {
                analysisSection(
                    title: "Contradictions",
                    icon: "xmark.circle.fill",
                    iconColor: .red,
                    items: analysisResult.contradictions,
                    itemColor: .red
                )
            }
            
            // Missing Details
            if !analysisResult.missingDetails.isEmpty {
                analysisSection(
                    title: "Missing/Unclear Details",
                    icon: "questionmark.circle.fill",
                    iconColor: .orange,
                    items: analysisResult.missingDetails,
                    itemColor: .orange
                )
            }
        }
    }
    
    private func analysisSection(title: String, icon: String, iconColor: Color, items: [String], itemColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(iconColor)
            
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(itemColor.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                    
                    Text(item)
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - Comparison Tab (Side-by-Side)
    private var comparisonTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Party Headers
            HStack {
                Text(analysisResult.partyAName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "3B82F6"))
                    .frame(maxWidth: .infinity)
                
                Text("vs")
                    .font(.system(size: 12))
                    .foregroundColor(textSecondary)
                
                Text(analysisResult.partyBName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "8B5CF6"))
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)
            
            if analysisResult.sideBySideComparison.isEmpty {
                emptyComparisonState
            } else {
                ForEach(analysisResult.sideBySideComparison) { item in
                    comparisonCard(item)
                }
            }
        }
    }
    
    private var emptyComparisonState: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.split.2x1")
                .font(.system(size: 32))
                .foregroundColor(textSecondary)
            
            Text("No comparison data available")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private func comparisonCard(_ item: SideBySideComparisonItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Topic & Status
            HStack {
                Text(item.topic)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: item.status.icon)
                        .font(.system(size: 12))
                    Text(item.status.displayName)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(item.status.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(item.status.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Side by Side Versions
            HStack(alignment: .top, spacing: 12) {
                // Party A Version
                VStack(alignment: .leading, spacing: 6) {
                    Text(analysisResult.partyAName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "3B82F6"))
                    
                    Text(item.partyAVersion)
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "3B82F6").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Party B Version
                VStack(alignment: .leading, spacing: 6) {
                    Text(analysisResult.partyBName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "8B5CF6"))
                    
                    Text(item.partyBVersion)
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "8B5CF6").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - Details Tab
    private var detailsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Timeline Differences
            if !analysisResult.timelineDifferences.isEmpty {
                analysisSection(
                    title: "Timeline Differences",
                    icon: "clock.arrow.2.circlepath",
                    iconColor: .blue,
                    items: analysisResult.timelineDifferences,
                    itemColor: .blue
                )
            }
            
            // Emotional Language
            if !analysisResult.emotionalLanguage.isEmpty {
                analysisSection(
                    title: "Emotional Language",
                    icon: "heart.text.square.fill",
                    iconColor: .pink,
                    items: analysisResult.emotionalLanguage,
                    itemColor: .pink
                )
            }
            
            // Disclaimer
            disclaimerCard
        }
    }
    
    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("System Notice", systemImage: "info.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.blue)
            
            Text("This analysis is provided as a neutral comparison tool. The System does not make accusations or determine fault. All findings should be verified through proper investigation procedures.")
                .font(.system(size: 12))
                .foregroundColor(textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - Helpers
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Analysis Loading View
struct AnalysisLoadingView: View {
    @State private var animationPhase = 0
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated Brain Icon
            ZStack {
                Circle()
                    .stroke(AppColors.primary.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(AppColors.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(Double(animationPhase)))
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.primary)
            }
            
            Text("Analyzing Statements...")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                Text("System is comparing both complaints")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Text("This may take up to 30 seconds")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            // Progress steps
            VStack(alignment: .leading, spacing: 12) {
                AnalysisStepRow(title: "Reading statements", isActive: animationPhase < 400, isComplete: animationPhase >= 400)
                AnalysisStepRow(title: "Identifying differences", isActive: animationPhase >= 400 && animationPhase < 800, isComplete: animationPhase >= 800)
                AnalysisStepRow(title: "Generating summary", isActive: animationPhase >= 800, isComplete: false)
            }
            .padding()
            .background(Color.gray.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(32)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                animationPhase = 1080
            }
        }
    }
}

struct AnalysisStepRow: View {
    let title: String
    let isActive: Bool
    let isComplete: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if isActive {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray.opacity(0.4))
                }
            }
            .frame(width: 20, height: 20)
            
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(isComplete ? .green : (isActive ? .primary : .secondary))
        }
    }
}

// MARK: - Preview
#Preview {
    let sampleResult = AIComparisonResult(
        timelineDifferences: [
            "Party A claims incident occurred at 10:30 AM, Party B states it was around 11:00 AM",
            "Party A mentions a brief conversation before the incident, Party B does not recall this"
        ],
        agreementPoints: [
            "Both parties confirm the incident occurred in the warehouse area",
            "Both acknowledge other employees were present nearby"
        ],
        contradictions: [
            "Party A claims Party B raised their voice first; Party B claims they were responding to Party A's tone",
            "Party A states boxes were knocked over accidentally; Party B believes it was intentional"
        ],
        emotionalLanguage: [
            "Party A uses phrases like 'always does this to me' suggesting frustration",
            "Party B describes feeling 'targeted' and 'singled out'"
        ],
        missingDetails: [
            "Specific words exchanged during the confrontation",
            "Names of nearby witnesses who may have observed the incident"
        ],
        neutralSummary: "According to the statements provided, an incident occurred in the warehouse area involving both parties. There is agreement that the incident took place during work hours and that other employees were nearby. However, there are differing accounts regarding the sequence of events, who initiated the verbal exchange, and whether physical contact with nearby boxes was accidental. Further investigation may be needed to clarify these discrepancies.",
        sideBySideComparison: [
            SideBySideComparisonItem(topic: "Time of Incident", partyAVersion: "10:30 AM", partyBVersion: "Around 11:00 AM", status: .contradiction),
            SideBySideComparisonItem(topic: "Location", partyAVersion: "Warehouse near loading dock", partyBVersion: "Warehouse area", status: .agreement),
            SideBySideComparisonItem(topic: "Who spoke first", partyAVersion: "Party B raised voice first", partyBVersion: "Was responding to Party A", status: .contradiction)
        ],
        partyAName: "Carmen More",
        partyBName: "John Smith",
        generatedAt: Date()
    )
    
    NavigationStack {
        CaseAnalysisView(analysisResult: sampleResult)
            .navigationTitle("Analysis")
    }
}
