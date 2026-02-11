//
//  ComplianceAudioDeletionView.swift
//  MeetingIntelligence
//
//  Compliance Audio Deletion Notification View
//  Shows notification that audio has been/is being deleted after transcript saved
//  NOTE: Deletion happens IMMEDIATELY when transcript is saved (even if phone turns off)
//  This modal is just a notification - the deletion already started in the background
//  We only keep AI Summary audio (TTS-generated), NOT the original recording
//

import SwiftUI

struct ComplianceAudioDeletionView: View {
    let meetingId: String
    let userId: String
    let onComplete: () -> Void
    
    @StateObject private var complianceService = ComplianceService.shared
    @State private var showSuccessModal = false
    @State private var progressCheckTimer: Timer?
    @State private var autoShowSuccessTimer: Timer?
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            if showSuccessModal {
                // Success Modal (Green)
                successModal
            } else {
                // Deletion In Progress Modal (Orange/Warning)
                deletionInProgressModal
            }
        }
        .onAppear {
            startProgressCheck()
        }
        .onDisappear {
            progressCheckTimer?.invalidate()
            autoShowSuccessTimer?.invalidate()
        }
    }
    
    // MARK: - Deletion In Progress Modal (Orange - Notification Only)
    private var deletionInProgressModal: some View {
        VStack(spacing: 24) {
            // Shield Icon with animation
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "shield.checkered")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                    .symbolEffect(.pulse)
            }
            
            // Title
            Text("Deleting Original Audio")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Message
            VStack(spacing: 8) {
                Text("For privacy compliance, the original audio")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                
                Text("recording is being permanently deleted.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
            .multilineTextAlignment(.center)
            
            // Deletion in progress indicator
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                
                Text(complianceService.deletionState.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.vertical, 8)
            
            // What's being kept
            VStack(alignment: .leading, spacing: 8) {
                Text("Data retained:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.7))
                
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Transcript saved")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("System Summary audio (narration)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text("Original recording (deleting...)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Info text
            Text("Deletion continues even if you close the app")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(32)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.orange.opacity(0.9))
                .shadow(color: .orange.opacity(0.5), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Success Modal (Green)
    private var successModal: some View {
        VStack(spacing: 24) {
            // Success Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            
            // Title
            Text("Audio Deleted Successfully")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Message
            VStack(spacing: 8) {
                Text("The original audio recording has been")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                
                Text("permanently removed for privacy compliance.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
            .multilineTextAlignment(.center)
            
            // What's retained summary
            VStack(alignment: .leading, spacing: 8) {
                Text("Your data:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.9))
                
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.white)
                        .font(.caption)
                    Text("Full transcript with speakers")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .foregroundColor(.white)
                        .font(.caption)
                    Text("System Summary audio available")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.white)
                        .font(.caption)
                    Text("System-generated summary")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Compliance badge
            HStack(spacing: 6) {
                Image(systemName: "shield.checkered")
                    .font(.caption)
                Text("Privacy Compliant")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.2))
            .clipShape(Capsule())
            
            // OK Button
            Button {
                onComplete()
            } label: {
                Text("OK, Continue")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 8)
        }
        .padding(32)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 0.2, green: 0.7, blue: 0.3))
                .shadow(color: .green.opacity(0.5), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Progress Check
    
    private func startProgressCheck() {
        // Check if deletion is already complete
        if complianceService.isAudioDeletedForCompliance(meetingId: meetingId) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showSuccessModal = true
            }
            return
        }
        
        // Check periodically if deletion completed
        progressCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if complianceService.deletionState == .completed ||
               complianceService.isAudioDeletedForCompliance(meetingId: meetingId) {
                progressCheckTimer?.invalidate()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showSuccessModal = true
                }
            }
        }
        
        // Auto-show success after 4 seconds max (deletion happens in background anyway)
        autoShowSuccessTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            progressCheckTimer?.invalidate()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showSuccessModal = true
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ComplianceAudioDeletionView(
        meetingId: "test-meeting-123",
        userId: "test-user-456",
        onComplete: {}
    )
}
