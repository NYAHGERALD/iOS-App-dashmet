//
//  LSWView.swift
//  MeetingIntelligence
//
//  Leader Standard Work
//

import SwiftUI

// MARK: - LSW Section Model
enum LSWSection: String, CaseIterable, Identifiable {
    case dailyWeekly = "Daily & Weekly Standard Tasks/Meetings"
    case improvementProjects = "Improvement Projects and Updates"
    case followUps = "Follow Ups"
    case rcaTriggers = "Plant Specific Cause RCA Triggers"
    case scheduledTasks = "Scheduled Tasks/Meetings"
    case meetingRails = "Level 1, 2 & 3 Meeting Rails"
    case personalObjectives = "Personal Objectives/Goals"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .dailyWeekly: return "calendar.badge.clock"
        case .improvementProjects: return "arrow.triangle.2.circlepath"
        case .followUps: return "bell.badge"
        case .rcaTriggers: return "exclamationmark.triangle"
        case .scheduledTasks: return "clock.badge.checkmark"
        case .meetingRails: return "person.3"
        case .personalObjectives: return "target"
        }
    }
    
    var color: Color {
        switch self {
        case .dailyWeekly: return Color(hex: "0EA5E9")
        case .improvementProjects: return Color(hex: "8B5CF6")
        case .followUps: return Color(hex: "F97316")
        case .rcaTriggers: return Color(hex: "EF4444")
        case .scheduledTasks: return Color(hex: "10B981")
        case .meetingRails: return Color(hex: "6366F1")
        case .personalObjectives: return Color(hex: "F59E0B")
        }
    }
}

struct LSWView: View {
    @Environment(\.colorScheme) private var colorScheme
    var onMenuTap: () -> Void
    
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
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(LSWSection.allCases.enumerated()), id: \.element.id) { index, section in
                        NavigationLink(destination: LSWSectionDetailView(section: section)) {
                            lswRow(section)
                        }
                        .buttonStyle(.plain)
                        
                        if index < LSWSection.allCases.count - 1 {
                            Divider()
                                .padding(.leading, 68)
                        }
                    }
                }
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(cardBorder, lineWidth: 1)
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("LSW")
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
            }
        }
    }
    
    private func lswRow(_ section: LSWSection) -> some View {
        HStack(spacing: 14) {
            Image(systemName: section.icon)
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(section.color)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            Text(section.rawValue)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(textSecondary.opacity(0.5))
        }
        .padding(14)
    }
}

// MARK: - Section Detail Router
struct LSWSectionDetailView: View {
    let section: LSWSection
    
    var body: some View {
        switch section {
        case .dailyWeekly:
            DailyWeeklyView()
        default:
            LSWPlaceholderView(section: section)
        }
    }
}

// MARK: - Placeholder for other sections
struct LSWPlaceholderView: View {
    let section: LSWSection
    @Environment(\.colorScheme) private var colorScheme
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(section.color.opacity(0.1))
                        .frame(width: 90, height: 90)
                    
                    Image(systemName: section.icon)
                        .font(.system(size: 36))
                        .foregroundColor(section.color)
                }
                
                Text(section.rawValue)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Text("This section is under development.")
                    .font(.system(size: 14))
                    .foregroundColor(textSecondary)
            }
        }
        .navigationTitle(shortTitle(section))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func shortTitle(_ section: LSWSection) -> String {
        switch section {
        case .dailyWeekly: return "Daily & Weekly"
        case .improvementProjects: return "Improvements"
        case .followUps: return "Follow Ups"
        case .rcaTriggers: return "RCA Triggers"
        case .scheduledTasks: return "Scheduled"
        case .meetingRails: return "Meeting Rails"
        case .personalObjectives: return "Objectives"
        }
    }
}
