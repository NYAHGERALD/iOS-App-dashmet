//
//  RegistrationSuccessView.swift
//  MeetingIntelligence
//
//  Success screen shown after successful registration
//

import SwiftUI

struct RegistrationSuccessView: View {
    let onLoginTapped: () -> Void
    
    @State private var showCheckmark = false
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.green.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Success Animation
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 160, height: 160)
                        .scaleEffect(showCheckmark ? 1 : 0.5)
                        .opacity(showCheckmark ? 1 : 0)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.green.opacity(0.3), radius: 25, x: 0, y: 15)
                        .scaleEffect(showCheckmark ? 1 : 0)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(showCheckmark ? 1 : 0)
                }
                
                // Content
                VStack(spacing: 16) {
                    Text("Registration Successful!")
                        .font(.title)
                        .fontWeight(.bold)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                    
                    Text("Your account has been created.\nYou can now sign in with your phone number.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                }
                
                Spacer()
                
                // Celebration elements
                VStack(spacing: 20) {
                    HStack(spacing: 24) {
                        FeatureCheckItem(icon: "person.crop.circle.fill", text: "Profile Created")
                        FeatureCheckItem(icon: "building.2.fill", text: "Facility Set")
                        FeatureCheckItem(icon: "shield.checkered", text: "Role Assigned")
                    }
                    .opacity(showContent ? 1 : 0)
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Login Button
                Button {
                    onLoginTapped()
                } label: {
                    HStack(spacing: 10) {
                        Text("Continue to Login")
                            .fontWeight(.semibold)
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 30)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showCheckmark = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                showContent = true
            }
        }
    }
}

// MARK: - Feature Check Item
struct FeatureCheckItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.green)
            }
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    RegistrationSuccessView {
        print("Login tapped")
    }
}
