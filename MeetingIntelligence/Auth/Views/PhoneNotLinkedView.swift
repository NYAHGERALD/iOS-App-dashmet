//
//  PhoneNotLinkedView.swift
//  MeetingIntelligence
//
//  Shown when a user tries to log in with a phone number
//  that isn't associated with any account in the system.
//

import SwiftUI

struct PhoneNotLinkedView: View {
    let onGoBack: () -> Void
    
    // MARK: - Animation State
    @State private var iconAppeared = false
    @State private var pulseRing = false
    @State private var titleAppeared = false
    @State private var messageAppeared = false
    @State private var stepsRevealed: [Bool] = [false, false, false, false]
    @State private var buttonAppeared = false
    @State private var buttonPressed = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 28) {
                // MARK: - Animated Icon
                ZStack {
                    // Outer pulse ring
                    Circle()
                        .stroke(Color.orange.opacity(0.2), lineWidth: 2)
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulseRing ? 1.3 : 1.0)
                        .opacity(pulseRing ? 0 : 0.6)
                    
                    // Second pulse ring (offset timing)
                    Circle()
                        .stroke(Color.orange.opacity(0.15), lineWidth: 1.5)
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulseRing ? 1.5 : 1.0)
                        .opacity(pulseRing ? 0 : 0.4)
                    
                    // Background circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.12), Color.orange.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 110, height: 110)
                        .scaleEffect(iconAppeared ? 1.0 : 0.3)
                    
                    // Icon
                    Image(systemName: "phone.badge.waveform")
                        .font(.system(size: 46, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, Color(red: 0.95, green: 0.5, blue: 0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(iconAppeared ? 1.0 : 0.1)
                        .rotationEffect(.degrees(iconAppeared ? 0 : -15))
                }
                
                // MARK: - Title
                Text("Phone Number Not Linked")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .opacity(titleAppeared ? 1 : 0)
                    .offset(y: titleAppeared ? 0 : 12)
                
                // MARK: - Message
                VStack(spacing: 10) {
                    Text("This phone number is not associated with any account.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("Add your phone number through the web portal to get started.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 12)
                .opacity(messageAppeared ? 1 : 0)
                .offset(y: messageAppeared ? 0 : 10)
                
                // MARK: - Steps Card
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<4, id: \.self) { index in
                        stepRow(
                            number: index + 1,
                            icon: stepIcon(for: index),
                            text: stepText(for: index),
                            isLast: index == 3
                        )
                        .opacity(stepsRevealed[index] ? 1 : 0)
                        .offset(x: stepsRevealed[index] ? 0 : -20)
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
                        .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
                )
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // MARK: - Button
            Button {
                withAnimation(.easeIn(duration: 0.1)) { buttonPressed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.easeOut(duration: 0.1)) { buttonPressed = false }
                    onGoBack()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Try a Different Number")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .scaleEffect(buttonPressed ? 0.97 : 1.0)
            .opacity(buttonAppeared ? 1 : 0)
            .offset(y: buttonAppeared ? 0 : 20)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear { runEntryAnimations() }
    }
    
    // MARK: - Entry Animations
    private func runEntryAnimations() {
        // Icon bounces in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.65, blendDuration: 0)) {
            iconAppeared = true
        }
        
        // Pulse rings start
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false).delay(0.5)) {
            pulseRing = true
        }
        
        // Title slides up
        withAnimation(.easeOut(duration: 0.45).delay(0.25)) {
            titleAppeared = true
        }
        
        // Message slides up
        withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
            messageAppeared = true
        }
        
        // Steps cascade in one by one
        for i in 0..<4 {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75).delay(0.55 + Double(i) * 0.12)) {
                stepsRevealed[i] = true
            }
        }
        
        // Button rises up
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(1.1)) {
            buttonAppeared = true
        }
    }
    
    // MARK: - Step Data
    private func stepIcon(for index: Int) -> String {
        switch index {
        case 0: return "globe"
        case 1: return "gearshape"
        case 2: return "phone.fill"
        case 3: return "arrow.clockwise"
        default: return "circle"
        }
    }
    
    private func stepText(for index: Int) -> String {
        switch index {
        case 0: return "Log in to the DashMet web portal"
        case 1: return "Go to Settings → Profile"
        case 2: return "Add your phone number"
        case 3: return "Come back here and try again"
        default: return ""
        }
    }
    
    // MARK: - Step Row
    private func stepRow(number: Int, icon: String, text: String, isLast: Bool) -> some View {
        HStack(alignment: .center, spacing: 14) {
            // Step indicator
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, isLast ? 0 : 10)
        .overlay(alignment: .leading) {
            if !isLast {
                Rectangle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 2, height: 20)
                    .offset(x: 15, y: 26)
            }
        }
    }
}
