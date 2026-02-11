//
//  RecordingConsentView.swift
//  MeetingIntelligence
//
//  Recording Consent Modal
//  Professional GDPR/Legal compliant consent modal for meeting recordings
//  Shows policy, requires explicit consent, and plays audio announcement
//

import SwiftUI
import AVFoundation

struct RecordingConsentView: View {
    let meetingId: String
    let userInfo: ConsentUserInfo
    let onConsent: () -> Void
    let onDecline: () -> Void
    
    @StateObject private var consentService = RecordingConsentService.shared
    @State private var policy: ConsentPolicy?
    @State private var isLoadingPolicy = true
    @State private var hasAgreedToPolicy = false
    @State private var hasConfirmedParticipants = false
    @State private var isProcessingConsent = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var expandedSection: PolicySection?
    @State private var showAnnouncementPreview = false
    
    enum PolicySection: String, CaseIterable {
        case purpose = "Purpose of Recording"
        case retention = "Data Retention"
        case security = "Data Security"
        case sharing = "Data Sharing"
        case rights = "Your Rights"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(hex: "1a1a2e"),
                        Color(hex: "16213e"),
                        Color(hex: "0f0f1a")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Policy Sections
                        if let policy = policy {
                            policyContent(policy)
                        } else if isLoadingPolicy {
                            loadingView
                        }
                        
                        // Audio Announcement Notice
                        audioAnnouncementNotice
                        
                        // Consent Checkboxes
                        consentCheckboxes
                        
                        // Action Buttons
                        actionButtons
                        
                        // Legal Footer
                        legalFooter
                    }
                    .padding()
                }
            }
            .navigationTitle("Recording Consent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDecline()
                    }
                    .foregroundColor(.red)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadPolicy()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Shield icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "shield.checkered")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }
            
            Text("Meeting Recording Consent")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Please review and accept the recording policy before proceeding")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            if let policy = policy {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.blue)
                    Text("Policy Version: \(policy.version)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            Text("Loading policy...")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Policy Content
    
    private func policyContent(_ policy: ConsentPolicy) -> some View {
        VStack(spacing: 16) {
            policySectionCard(
                section: .purpose,
                icon: "mic.fill",
                color: .purple,
                content: policy.purposeOfRecording
            )
            
            policySectionCard(
                section: .retention,
                icon: "clock.badge.checkmark",
                color: .orange,
                content: policy.dataRetentionPolicy
            )
            
            policySectionCard(
                section: .security,
                icon: "lock.shield",
                color: .green,
                content: policy.dataSecurityPolicy
            )
            
            policySectionCard(
                section: .sharing,
                icon: "person.2.slash",
                color: .blue,
                content: policy.dataSharingPolicy
            )
            
            policySectionCard(
                section: .rights,
                icon: "person.badge.shield.checkmark",
                color: .teal,
                content: policy.userRights
            )
        }
    }
    
    private func policySectionCard(section: PolicySection, icon: String, color: Color, content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header (always visible)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if expandedSection == section {
                        expandedSection = nil
                    } else {
                        expandedSection = section
                    }
                }
            } label: {
                HStack {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: icon)
                            .foregroundColor(color)
                    }
                    
                    Text(section.rawValue)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: expandedSection == section ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.caption)
                }
            }
            
            // Content (expandable)
            if expandedSection == section {
                Text(content)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(expandedSection == section ? color.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
    
    // MARK: - Audio Announcement Notice
    
    private var audioAnnouncementNotice: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.yellow)
                
                Text("Audio Announcement")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Text("When recording begins, a natural voice announcement will notify all participants that the meeting is being recorded. Recording will start after the announcement completes.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            Button {
                showAnnouncementPreview = true
                consentService.previewAnnouncement()
                
                // Auto-reset after announcement (max 10 seconds)
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    if showAnnouncementPreview {
                        consentService.stopAnnouncement()
                        showAnnouncementPreview = false
                    }
                }
            } label: {
                HStack {
                    if consentService.isPlayingAnnouncement {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .yellow))
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: showAnnouncementPreview ? "speaker.wave.3.fill" : "play.circle")
                    }
                    Text(showAnnouncementPreview ? "Playing..." : "Preview Announcement")
                }
                .font(.caption)
                .foregroundColor(.yellow)
            }
            .disabled(showAnnouncementPreview || consentService.isPlayingAnnouncement)
            
            // Voice quality notice
            HStack(spacing: 4) {
                Image(systemName: "waveform")
                Text("Powered by OpenAI natural voice synthesis")
            }
            .font(.caption2)
            .foregroundColor(.white.opacity(0.5))
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
        .onChange(of: consentService.isPlayingAnnouncement) { _, isPlaying in
            if !isPlaying {
                showAnnouncementPreview = false
            }
        }
    }
    
    // MARK: - Consent Checkboxes
    
    private var consentCheckboxes: some View {
        VStack(spacing: 16) {
            // Policy Agreement
            Button {
                hasAgreedToPolicy.toggle()
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: hasAgreedToPolicy ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundColor(hasAgreedToPolicy ? .green : .white.opacity(0.5))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("I have read and agree to the Recording Policy")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        Text("I understand that this meeting will be recorded, transcribed, and processed by the System for summary generation.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                }
            }
            
            // Participant Confirmation
            Button {
                hasConfirmedParticipants.toggle()
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: hasConfirmedParticipants ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundColor(hasConfirmedParticipants ? .green : .white.opacity(0.5))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("All meeting participants have been notified")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        Text("I confirm that all participants have been informed about this recording or will be notified by the audio announcement.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Agree Button
            Button {
                Task {
                    await processConsent()
                }
            } label: {
                HStack {
                    if isProcessingConsent {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.shield.fill")
                    }
                    Text("I Agree - Start Recording")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    canProceed
                        ? LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canProceed || isProcessingConsent)
            
            // Decline Button
            Button {
                onDecline()
            } label: {
                Text("Decline - Do Not Record")
                    .font(.subheadline)
                    .foregroundColor(.red.opacity(0.8))
            }
        }
    }
    
    private var canProceed: Bool {
        hasAgreedToPolicy && hasConfirmedParticipants && policy != nil
    }
    
    // MARK: - Legal Footer
    
    private var legalFooter: some View {
        VStack(spacing: 8) {
            Text("Your consent is recorded with a timestamp and cryptographic hash for compliance purposes.")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
            
            HStack {
                Image(systemName: "lock.fill")
                Text("Consent ID will be generated upon agreement")
            }
            .font(.caption2)
            .foregroundColor(.white.opacity(0.3))
        }
        .padding(.top, 8)
    }
    
    // MARK: - Actions
    
    private func loadPolicy() async {
        isLoadingPolicy = true
        do {
            policy = try await consentService.fetchCurrentPolicy()
        } catch {
            // Use default policy if fetch fails
            policy = ConsentPolicy(
                id: nil,
                version: "1.0.0",
                title: "Meeting Recording Consent Policy",
                purposeOfRecording: "This meeting is being recorded for transcription, System summary generation, action item extraction, and important details capture.",
                dataRetentionPolicy: "Audio recordings are permanently deleted after transcription. Only text transcripts and System summaries are retained.",
                dataSecurityPolicy: "All data is encrypted in transit (TLS 1.3) and at rest (AES-256). Access is controlled by role-based permissions.",
                dataSharingPolicy: "Meeting data is not shared with third parties. Access is limited to meeting participants and authorized administrators.",
                userRights: "You have the right to access, correct, or request deletion of your meeting data. Contact your administrator for data requests.",
                effectiveDate: nil
            )
        }
        isLoadingPolicy = false
    }
    
    private func processConsent() async {
        guard let policy = policy else { return }
        
        isProcessingConsent = true
        
        do {
            // Step 1: Record consent in the backend
            let consentRecord = try await consentService.recordConsent(
                meetingId: meetingId,
                user: userInfo,
                policy: policy,
                allParticipantsNotified: hasConfirmedParticipants
            )
            
            // Step 2: Cache consent locally
            consentService.cacheConsentLocally(meetingId: meetingId, consentRecord: consentRecord)
            
            // Step 3: Play announcement and WAIT for it to complete
            // Recording should NOT start until this finishes
            print("🎙️ Playing recording announcement...")
            do {
                try await consentService.playRecordingAnnouncement()
                print("✅ Announcement finished, now starting recording...")
            } catch {
                // If TTS fails, log it but continue with recording
                print("⚠️ Announcement failed: \(error.localizedDescription), continuing without audio")
            }
            
            // Step 4: Mark announcement as played
            await consentService.markAnnouncementPlayed(consentId: consentRecord.id, meetingId: meetingId)
            
            // Step 5: NOW proceed with recording (after announcement completed or failed)
            isProcessingConsent = false
            onConsent()
            
        } catch {
            isProcessingConsent = false
            errorMessage = "Failed to record consent: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Preview

#Preview {
    RecordingConsentView(
        meetingId: "test-meeting-123",
        userInfo: ConsentUserInfo(
            uid: "test-user",
            email: "test@example.com",
            firstName: "John",
            lastName: "Doe",
            phoneNumber: nil
        ),
        onConsent: { print("Consent given") },
        onDecline: { print("Declined") }
    )
}
