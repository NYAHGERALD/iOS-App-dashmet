//
//  RecordingIndicatorView.swift
//  MeetingIntelligence
//
//  Recording Indicator
//  Shows visual indicator that meeting is being recorded
//  Includes pulsing animation for visibility
//

import SwiftUI

struct RecordingIndicatorView: View {
    @State private var isPulsing = false
    var isCompact: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Pulsing red dot
            Circle()
                .fill(Color.red)
                .frame(width: isCompact ? 8 : 12, height: isCompact ? 8 : 12)
                .overlay(
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                        .scaleEffect(isPulsing ? 1.8 : 1.0)
                        .opacity(isPulsing ? 0 : 1)
                )
                .animation(
                    Animation.easeOut(duration: 1.0)
                        .repeatForever(autoreverses: false),
                    value: isPulsing
                )
            
            if !isCompact {
                Text("REC")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, isCompact ? 8 : 12)
        .padding(.vertical, isCompact ? 4 : 6)
        .background(
            Capsule()
                .fill(Color.red.opacity(0.15))
        )
        .overlay(
            Capsule()
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - Recording Status Bar

struct RecordingStatusBar: View {
    let duration: TimeInterval
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Recording indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(0.5), lineWidth: 2)
                            .scaleEffect(isPulsing ? 1.5 : 1.0)
                            .opacity(isPulsing ? 0 : 1)
                    )
                    .animation(
                        Animation.easeOut(duration: 1.0)
                            .repeatForever(autoreverses: false),
                        value: isPulsing
                    )
                
                Text("Recording")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }
            
            // Duration
            Text(formatDuration(duration))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
            
            Spacer()
            
            // Shield icon for compliance
            HStack(spacing: 4) {
                Image(systemName: "shield.checkered")
                    .font(.caption2)
                Text("Consent Verified")
                    .font(.caption2)
            }
            .foregroundColor(.green.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.8))
        .onAppear {
            isPulsing = true
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}

// MARK: - Floating Recording Badge

struct FloatingRecordingBadge: View {
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(0.5), lineWidth: 2)
                            .scaleEffect(isPulsing ? 2.0 : 1.0)
                            .opacity(isPulsing ? 0 : 1)
                    )
                    .animation(
                        Animation.easeOut(duration: 1.0)
                            .repeatForever(autoreverses: false),
                        value: isPulsing
                    )
                
                Text("RECORDING")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.9))
            .clipShape(Capsule())
            .shadow(color: .red.opacity(0.5), radius: 8, x: 0, y: 4)
        }
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - Previews

#Preview("Recording Indicator") {
    VStack(spacing: 20) {
        RecordingIndicatorView()
        RecordingIndicatorView(isCompact: true)
    }
    .padding()
    .background(Color.black)
}

#Preview("Recording Status Bar") {
    VStack {
        RecordingStatusBar(duration: 125)
        RecordingStatusBar(duration: 3725)
    }
}

#Preview("Floating Badge") {
    ZStack {
        Color.gray.opacity(0.3)
        FloatingRecordingBadge()
    }
}
