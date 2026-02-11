//
//  VisionSessionDetailView.swift
//  MeetingIntelligence
//
//  View for displaying full conversation details of a session
//  with options to summarize, share, and delete
//

import SwiftUI

struct VisionSessionDetailView: View {
    let session: VisionSession
    @StateObject private var sessionManager = VisionSessionManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showDeleteAlert = false
    @State private var isGeneratingSummary = false
    @State private var summaryText: String?
    @State private var showSummary = false
    @State private var showShareSheet = false
    
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
                VStack(spacing: 20) {
                    // Header Card
                    headerCard
                    
                    // Summary Section (if exists or generating)
                    if showSummary || session.summary != nil || isGeneratingSummary {
                        summarySection
                    }
                    
                    // Conversation Section
                    conversationSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            .background(AppColors.background)
            .navigationTitle("Session Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            generateSummary()
                        } label: {
                            Label("Generate Summary", systemImage: "text.badge.star")
                        }
                        .disabled(isGeneratingSummary)
                        
                        Button {
                            shareSession()
                        } label: {
                            Label("Share Conversation", systemImage: "square.and.arrow.up")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Delete Session", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(textPrimary)
                    }
                }
            }
            .alert("Delete Session?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    sessionManager.deleteSession(session)
                    dismiss()
                }
            } message: {
                Text("This will permanently delete this session.")
            }
        }
    }
    
    // MARK: - Header Card
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                // Topic icon
                Image(systemName: session.topicIcon)
                    .font(.title2)
                    .foregroundColor(topicColor)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(topicColor.opacity(0.2)))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.topic)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(textPrimary)
                    
                    Text(session.formattedDate)
                        .font(.subheadline)
                        .foregroundColor(textSecondary)
                }
                
                Spacer()
            }
            
            Divider()
                .background(cardBorder)
            
            // Stats row
            HStack(spacing: 24) {
                SessionStatItem(icon: "message.fill", value: "\(session.messageCount)", label: "Messages", colorScheme: colorScheme)
                SessionStatItem(icon: "clock.fill", value: session.duration, label: "Duration", colorScheme: colorScheme)
                SessionStatItem(icon: session.isSaved ? "checkmark.seal.fill" : "clock.badge.questionmark", 
                        value: session.isSaved ? "Saved" : "Temp", 
                        label: "Status", colorScheme: colorScheme)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(cardBorder, lineWidth: 1)
                )
        )
    }
    
    // MARK: - Summary Section
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("System Summary", systemImage: "text.badge.star")
                    .font(.headline)
                    .foregroundColor(textPrimary)
                
                Spacer()
                
                if isGeneratingSummary {
                    ProgressView()
                        .tint(textPrimary)
                }
            }
            
            if isGeneratingSummary {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(textPrimary)
                    Text("Generating summary...")
                        .font(.subheadline)
                        .foregroundColor(textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardBackground)
                )
            } else if let summary = summaryText ?? session.summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                    .lineSpacing(4)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.green.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
        }
    }
    
    // MARK: - Conversation Section
    private var conversationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Conversation", systemImage: "bubble.left.and.bubble.right.fill")
                .font(.headline)
                .foregroundColor(textPrimary)
            
            LazyVStack(spacing: 12) {
                ForEach(session.messages) { message in
                    MessageBubbleView(message: message, colorScheme: colorScheme)
                }
            }
        }
    }
    
    // MARK: - Helpers
    private var topicColor: Color {
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
    
    private func generateSummary() {
        isGeneratingSummary = true
        showSummary = true
        
        // Use backend AI summary if user is logged in, otherwise local summary
        Task {
            do {
                if sessionManager.userId != nil {
                    // Use backend AI summary
                    let summary = try await sessionManager.generateAISummary(for: session)
                    await MainActor.run {
                        summaryText = summary
                        isGeneratingSummary = false
                    }
                } else {
                    // Fallback to local summary
                    let summary = generateLocalSummary()
                    await MainActor.run {
                        summaryText = summary
                        isGeneratingSummary = false
                        sessionManager.updateSessionSummary(sessionId: session.id, summary: summary)
                    }
                }
            } catch {
                await MainActor.run {
                    // Fallback to local summary on error
                    summaryText = generateLocalSummary()
                    isGeneratingSummary = false
                }
            }
        }
    }
    
    private func generateLocalSummary() -> String {
        let messageCount = session.messages.count
        let userMessages = session.messages.filter { $0.role == .user }.count
        
        return """
        📋 Session Summary for \(session.topic)
        
        • \(messageCount) total exchanges (\(userMessages) questions)
        • Duration: \(session.duration)
        • Date: \(session.formattedDate)
        
        Key topics discussed in this session involved \(session.topic.lowercased()) analysis and recommendations based on visual inspection.
        """
    }
    
    private func shareSession() {
        let text = sessionManager.exportSession(session)
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Session Stat Item
struct SessionStatItem: View {
    let icon: String
    let value: String
    let label: String
    let colorScheme: ColorScheme
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(textPrimary)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(textSecondary)
        }
    }
}

// MARK: - Message Bubble View
struct MessageBubbleView: View {
    let message: VisionMessage
    let colorScheme: ColorScheme
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6)
    }
    
    private var textTertiary: Color {
        colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.4)
    }
    
    private var bubbleBackground: Color {
        if message.role == .user {
            return Color.blue.opacity(colorScheme == .dark ? 0.3 : 0.15)
        } else {
            return colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
        }
    }
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if message.role == .assistant {
                        Image(systemName: "eye.circle.fill")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                    
                    Text(message.role == .user ? "You" : "System Vision")
                        .font(.caption.weight(.medium))
                        .foregroundColor(textSecondary)
                    
                    if message.role == .user {
                        Image(systemName: "person.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Text(message.content)
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.9))
                    .multilineTextAlignment(message.role == .user ? .trailing : .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(bubbleBackground)
                    )
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(textTertiary)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.role == .user ? .trailing : .leading)
            
            if message.role == .assistant {
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    VisionSessionDetailView(session: VisionSession(
        topic: "Workplace Safety",
        topicIcon: "exclamationmark.shield.fill"
    ))
}
