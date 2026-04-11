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
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Image(systemName: "phone.badge.waveform")
                        .font(.system(size: 44))
                        .foregroundColor(.orange)
                }
                
                // Title
                Text("Phone Number Not Linked")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                // Message
                VStack(spacing: 12) {
                    Text("This phone number is not associated with any account.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("To use this app, you need to add your phone number to your profile through the web portal first.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                
                // Steps
                VStack(alignment: .leading, spacing: 16) {
                    stepRow(number: 1, text: "Log in to the DashMet web portal")
                    stepRow(number: 2, text: "Go to Settings → Profile")
                    stepRow(number: 3, text: "Add your phone number")
                    stepRow(number: 4, text: "Come back here and try again")
                }
                .padding(20)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Back button
            Button(action: onGoBack) {
                HStack {
                    Image(systemName: "arrow.left")
                    Text("Try a Different Number")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}
