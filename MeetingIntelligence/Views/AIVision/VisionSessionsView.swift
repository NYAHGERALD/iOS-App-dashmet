//
//  VisionSessionsView.swift
//  MeetingIntelligence
//
//  View for browsing current and saved AI Vision sessions
//

import SwiftUI

struct VisionSessionsView: View {
    @StateObject private var sessionManager = VisionSessionManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showDeleteAlert = false
    @State private var sessionToDelete: VisionSession?
    @State private var selectedSession: VisionSession?
    @State private var showSessionDetail = false
    
    // Adaptive colors
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6)
    }
    
    private var textTertiary: Color {
        colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.4)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }
    
    private var cardBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Current Session (if exists)
                    if let currentSession = sessionManager.currentSession, !currentSession.messages.isEmpty {
                        currentSessionSection(currentSession)
                    }
                    
                    // Saved Sessions
                    savedSessionsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            .background(AppColors.background)
            .navigationTitle("Vision Sessions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showSessionDetail) {
                if let session = selectedSession {
                    VisionSessionDetailView(session: session)
                }
            }
            .alert("Delete Session?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let session = sessionToDelete {
                        sessionManager.deleteSession(session)
                    }
                }
            } message: {
                Text("This will permanently delete this session and all its conversation history.")
            }
        }
    }
    
    // MARK: - Current Session Section
    private func currentSessionSection(_ session: VisionSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Current Session", systemImage: "record.circle")
                    .font(.headline)
                    .foregroundColor(textPrimary)
                
                Spacer()
                
                Text("Unsaved")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange.opacity(0.2)))
            }
            
            SessionCardView(session: session, isCurrent: true, colorScheme: colorScheme) {
                selectedSession = session
                showSessionDetail = true
            }
        }
    }
    
    // MARK: - Saved Sessions Section
    private var savedSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Saved Sessions", systemImage: "folder.fill")
                    .font(.headline)
                    .foregroundColor(textPrimary)
                
                Spacer()
                
                Text("\(sessionManager.savedSessions.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(cardBorder))
            }
            
            if sessionManager.savedSessions.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(sessionManager.savedSessions) { session in
                        SessionCardView(session: session, isCurrent: false, colorScheme: colorScheme) {
                            selectedSession = session
                            showSessionDetail = true
                        }
                        .contextMenu {
                            Button {
                                selectedSession = session
                                showSessionDetail = true
                            } label: {
                                Label("View Details", systemImage: "eye")
                            }
                            
                            Button {
                                shareSession(session)
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                sessionToDelete = session
                                showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "eye.slash")
                .font(.system(size: 48))
                .foregroundColor(textTertiary)
            
            Text("No Saved Sessions")
                .font(.headline)
                .foregroundColor(textSecondary)
            
            Text("Your saved System Vision analysis sessions will appear here.")
                .font(.subheadline)
                .foregroundColor(textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(cardBorder, lineWidth: 1)
                )
        )
    }
    
    // MARK: - Share
    private func shareSession(_ session: VisionSession) {
        let text = sessionManager.exportSession(session)
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Session Card View
struct SessionCardView: View {
    let session: VisionSession
    let isCurrent: Bool
    let colorScheme: ColorScheme
    let onTap: () -> Void
    
    // Adaptive colors
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6)
    }
    
    private var textTertiary: Color {
        colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.4)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }
    
    private var cardBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    // Topic icon
                    Image(systemName: session.topicIcon)
                        .font(.title3)
                        .foregroundColor(topicColor)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(topicColor.opacity(0.2)))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.topic)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(textPrimary)
                        
                        Text(session.formattedDate)
                            .font(.caption)
                            .foregroundColor(textTertiary)
                    }
                    
                    Spacer()
                    
                    // Stats
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "message.fill")
                                .font(.caption2)
                            Text("\(session.messageCount)")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundColor(textSecondary)
                        
                        Text(session.duration)
                            .font(.caption)
                            .foregroundColor(textTertiary)
                    }
                }
                
                // Preview
                Text(session.previewText)
                    .font(.caption)
                    .foregroundColor(textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Summary badge (if exists)
                if session.summary != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.fill")
                            .font(.caption2)
                        Text("Summary available")
                            .font(.caption2)
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.green.opacity(0.2)))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isCurrent ? Color.orange.opacity(0.5) : cardBorder, lineWidth: isCurrent ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var topicColor: Color {
        // Map topic to color
        switch session.topic {
        case "Workplace Safety", "Fire Safety", "Electrical Safety":
            return .red
        case "Food Safety & Hygiene", "Sanitation & Cleanliness":
            return .orange
        case "Quality Control", "PPE Compliance":
            return .blue
        case "Environmental Compliance", "Agriculture & Farming":
            return .green
        case "Nursing & Healthcare", "Pharmacy & Medication":
            return .teal
        default:
            return .purple
        }
    }
}

// MARK: - Preview
#Preview {
    VisionSessionsView()
}
