//
//  DeferredMeetingDetailView.swift
//  MeetingIntelligence
//
//  Lightweight wrapper that defers heavy MeetingDetailTabbedView rendering
//  until after the sheet presentation animation completes.
//  This prevents "System gesture gate timed out" by keeping the main thread
//  free during the critical 300ms sheet animation window.
//

import SwiftUI

struct DeferredMeetingDetailView: View {
    let meeting: Meeting
    let meetingViewModel: MeetingViewModel
    
    @State private var isReady = false
    
    var body: some View {
        if isReady {
            MeetingDetailTabbedView(meeting: meeting, meetingViewModel: meetingViewModel)
                .transition(.identity) // No extra animation
        } else {
            // Lightweight placeholder shown during sheet animation
            meetingDetailPlaceholder
                .task {
                    // Wait for sheet animation to complete (~350ms),
                    // then swap in the real content
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    isReady = true
                    print("🔍 DEBUG [DeferredMeetingDetailView] isReady=true, loading full content")
                }
        }
    }
    
    // MARK: - Lightweight Placeholder
    // Mimics the MeetingDetailTabbedView layout so the transition is seamless
    private var meetingDetailPlaceholder: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab bar placeholder
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(MeetingTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: tab == .overview ? .semibold : .regular))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    tab == .overview
                                    ? AnyShapeStyle(AppGradients.primary)
                                    : AnyShapeStyle(Color.clear)
                                )
                                .foregroundColor(tab == .overview ? .white : AppColors.textSecondary)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(AppColors.surface)
                
                // Loading content
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading meeting details...")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(AppColors.background)
            .navigationTitle(meeting.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        // dismiss handled by parent
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
        }
    }
}
