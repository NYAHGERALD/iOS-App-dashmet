//
//  RecordingView.swift
//  MeetingIntelligence
//
//  Professional Recording UI - Audio Only
//  Transcript generation happens post-recording for better quality
//

import SwiftUI
import Speech

// MARK: - Pulsing Animation Modifier
struct PulsingAnimation: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Scale Button Style for Press Animation
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Recording Tab
enum RecordingTab: String, CaseIterable {
    case recording = "Recording"
    case notes = "Notes"
    
    var icon: String {
        switch self {
        case .recording: return "waveform.circle.fill"
        case .notes: return "note.text"
        }
    }
}

struct RecordingView: View {
    @StateObject private var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: RecordingTab = .recording
    @State private var showCancelConfirmation = false
    @State private var showStopConfirmation = false
    @State private var showBookmarkSheet = false
    @State private var bookmarkNote: String = ""
    @State private var showTranscriptGeneration = false  // Post-recording transcript generation
    @State private var showRecordingPreview = false  // Recording preview after stop
    @State private var recordingURL: URL?
    @State private var meetingNotes: String = ""  // User's manual notes during recording
    
    private let meetingViewModel: MeetingViewModel
    var onRecordingComplete: ((URL) -> Void)?
    
    init(meeting: Meeting, meetingViewModel: MeetingViewModel, onRecordingComplete: ((URL) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: RecordingViewModel(meeting: meeting, meetingViewModel: meetingViewModel))
        self.meetingViewModel = meetingViewModel
        self.onRecordingComplete = onRecordingComplete
    }
    
    var body: some View {
        GeometryReader { geometry in
            let safeAreaBottom = geometry.safeAreaInsets.bottom
            let bottomBarHeight: CGFloat = 260 + safeAreaBottom
            
            ZStack(alignment: .top) {
                // Background gradient
                backgroundGradient
                
                // Main content VStack - aligned to top
                VStack(spacing: 0) {
                    // Top bar with Cancel and Timer
                    topControlBar
                    
                    // Main Content Area
                    mainContentArea(geometry: geometry, bottomBarHeight: bottomBarHeight)
                    
                    Spacer(minLength: 0)
                }
                
                // Fixed Bottom Control Bar
                VStack {
                    Spacer()
                    bottomTabBar
                }
                .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        .alert("Cancel Recording?", isPresented: $showCancelConfirmation) {
            Button("Keep Recording", role: .cancel) {}
            Button("Discard", role: .destructive) {
                viewModel.cancelRecording()
                dismiss()
            }
        } message: {
            Text("This will discard your current recording. This cannot be undone.")
        }
                
        .alert("Stop Recording?", isPresented: $showStopConfirmation) {
            Button("Continue Recording", role: .cancel) {}
            Button("Stop & Save") {
                Task {
                    // Complete audio recording and get URL
                    if let url = await viewModel.completeRecording() {
                        recordingURL = url
                        
                        // Save any meeting notes
                        await saveMeetingNotes()
                        
                        // Show recording preview with transcript generation option
                        showRecordingPreview = true
                    }
                }
            }
        } message: {
            Text("Your recording will be saved. You can then generate a transcript from the audio.")
        }
        .fullScreenCover(isPresented: $showRecordingPreview) {
                if let url = recordingURL {
                    PostRecordingView(
                        meeting: viewModel.meeting,
                        recordingURL: url,
                        bookmarks: viewModel.bookmarks,
                        meetingNotes: meetingNotes,
                        meetingViewModel: meetingViewModel,
                        onComplete: {
                            onRecordingComplete?(url)
                            dismiss()
                        },
                        onDiscard: {
                            dismiss()
                        }
                )
                }
            }
        .sheet(isPresented: $showBookmarkSheet) {
            bookmarkSheet
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .alert("Microphone Access Required", isPresented: $viewModel.showPermissionAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Open Settings") {
                viewModel.openSettings()
            }
        } message: {
            Text("Please enable microphone access in Settings to record meetings.")
        }
        .task {
            // Auto-start recording when view appears (audio only, no transcription)
            if viewModel.canStartRecording {
                await viewModel.startRecording()
            }
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
    
    // MARK: - Save Meeting Notes
    private func saveMeetingNotes() async {
        guard !meetingNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let notesData: [String: Any] = [
            "notes": meetingNotes,
            "timestamp": Date().timeIntervalSince1970,
            "meetingId": viewModel.meeting.id
        ]
        
        UserDefaults.standard.set(try? JSONSerialization.data(withJSONObject: notesData), forKey: "meetingNotes_\(viewModel.meeting.id)")
        print("📝 Meeting notes saved (\(meetingNotes.count) characters)")
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(hex: "0f0c29"),
                Color(hex: "302b63"),
                Color(hex: "24243e")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Top Control Bar
    private var topControlBar: some View {
        VStack(spacing: 0) {
            // Recording compliance banner
            if viewModel.isRecording || viewModel.isPaused {
                HStack(spacing: 8) {
                    RecordingIndicatorView(isCompact: true)
                    
                    Spacer()
                    
                    // Compliance badge
                    HStack(spacing: 4) {
                        Image(systemName: "shield.checkered")
                            .font(.caption2)
                        Text("Consent Verified")
                            .font(.caption2)
                    }
                    .foregroundColor(.green.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.5))
            }
            
            // Main control bar
            HStack(spacing: 12) {
                // Cancel button
                Button {
                    if viewModel.isActive {
                        showCancelConfirmation = true
                    } else {
                        dismiss()
                    }
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(20)
                }
                
                Spacer()
                
                // Recording status and time (center)
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.isRecording ? Color.red : (viewModel.isPaused ? Color.orange : Color.gray))
                        .frame(width: 10, height: 10)
                        .modifier(viewModel.isRecording ? PulsingAnimation() : PulsingAnimation())
                    
                    Text(viewModel.formattedTime)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // AI badge
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                    Text("System")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Main Content Area
    private func mainContentArea(geometry: GeometryProxy, bottomBarHeight: CGFloat) -> some View {
        let safeAreaTop = geometry.safeAreaInsets.top
        let topBarHeight: CGFloat = 60 // Approximate top bar height
        let availableHeight = geometry.size.height - bottomBarHeight - safeAreaTop - topBarHeight
        
        return Group {
            switch selectedTab {
            case .recording:
                recordingTabContent(availableHeight: max(availableHeight, 300))
            case .notes:
                notesTabContent(availableHeight: max(availableHeight, 300))
            }
        }
    }
    
    // MARK: - Recording Tab Content
    private func recordingTabContent(availableHeight: CGFloat) -> some View {
        let visualizerSize = min(availableHeight * 0.40, 180.0) // Slightly smaller visualizer
        
        return VStack(spacing: 12) {
            // Timer Display - moved up
            VStack(spacing: 8) {
                // Recording status
                HStack(spacing: 10) {
                    Circle()
                        .fill(viewModel.isRecording ? Color.red : (viewModel.isPaused ? Color.orange : Color.gray))
                        .frame(width: 12, height: 12)
                        .modifier(viewModel.isRecording ? PulsingAnimation() : PulsingAnimation())
                    
                    Text(statusText)
                        .font(AppTypography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(statusColor.opacity(0.15))
                .clipShape(Capsule())
                    
                    // Time display - responsive font size
                    Text(viewModel.formattedTime)
                        .font(.system(size: min(availableHeight * 0.12, 64), weight: .ultraLight, design: .monospaced))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: viewModel.formattedTime)
                }
                
                // Audio Visualizer - responsive size
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    AppColors.primary.opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: visualizerSize * 0.4,
                                endRadius: visualizerSize * 0.9
                            )
                        )
                        .frame(width: visualizerSize * 1.6, height: visualizerSize * 1.6)
                        .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: viewModel.isRecording)
                    
                    // Audio level ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AppColors.primary,
                                    AppColors.accent,
                                    AppColors.primary
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 4
                        )
                        .frame(width: visualizerSize, height: visualizerSize)
                        .scaleEffect(1.0 + CGFloat(min(Double(viewModel.audioLevel), 1.0)) * 0.2)
                        .animation(.linear(duration: 0.1), value: viewModel.audioLevel)
                    
                    VStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.system(size: visualizerSize * 0.25))
                            .foregroundColor(AppColors.primary)
                        
                        Text("Recording Audio")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.vertical, 8)
                
                // Info banner about post-recording transcript
                transcriptInfoBanner
                
                Spacer() // Push content up, fill remaining space
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 8)
    }
    
    // MARK: - Transcript Info Banner
    private var transcriptInfoBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 20))
                .foregroundColor(AppColors.accent)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("System Transcript Generation")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text("Generate high-quality transcript after recording")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                colors: [AppColors.accent.opacity(0.15), AppColors.primary.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    // MARK: - Notes Tab Content
    private func notesTabContent(availableHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(AppColors.primary)
                Text("Meeting Notes")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                
                Text("\(meetingNotes.count) chars")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Notes text editor - takes remaining space
            TextEditor(text: $meetingNotes)
                .font(.body)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .frame(maxHeight: .infinity)
                .overlay(
                    Group {
                        if meetingNotes.isEmpty {
                            VStack {
                                HStack {
                                    Text("Jot down key points, action items, or observations...")
                                        .font(.body)
                                        .foregroundColor(.white.opacity(0.3))
                                        .padding(.horizontal, 20)
                                        .padding(.top, 24)
                                    Spacer()
                                }
                                Spacer()
                            }
                        }
                    }
                )
            
            // Quick note suggestions - fixed horizontal scroll
            quickNoteSuggestions
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
    }
    
    // MARK: - Quick Note Suggestions (Fixed Horizontal Scroll)
    private var quickNoteSuggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                quickNoteButton("📌 Action Item:")
                quickNoteButton("❓ Question:")
                quickNoteButton("💡 Idea:")
                quickNoteButton("⚠️ Important:")
                quickNoteButton("📅 Follow-up:")
            }
            .padding(.horizontal)
        }
        .frame(height: 40)
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
        .scrollBounceBehavior(.basedOnSize)
    }
    
    private func quickNoteButton(_ text: String) -> some View {
        Button {
            meetingNotes += (meetingNotes.isEmpty ? "" : "\n\n") + text + " "
        } label: {
            Text(text)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
        }
    }
    
    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.2), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    // MARK: - Bottom Tab Bar with Glassmorphism
    private var bottomTabBar: some View {
        VStack(spacing: 16) {
            // Decorative top edge with glow
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.primary.opacity(0.6), AppColors.accent.opacity(0.4), AppColors.primary.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .blur(radius: 1)
                .shadow(color: AppColors.primary.opacity(0.5), radius: 8, y: -2)
            
            // Recording Control Buttons - Always visible and prominent
            recordingControlButtons
                .padding(.top, 4)
            
            // Quick stats row with glassmorphism cards
            HStack(spacing: 10) {
                statItem(icon: "clock.fill", value: viewModel.formattedTime, label: "Duration")
                statItem(icon: "waveform", value: String(format: "%.0f%%", viewModel.audioLevel * 100), label: "Audio Level")
                statItem(icon: "bookmark.fill", value: "\(viewModel.bookmarks.count)", label: "Bookmarks")
            }
            .padding(.horizontal, 16)
            
            // Tab selector at bottom with animated indicator
            HStack(spacing: 0) {
                ForEach(RecordingTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                // Glow effect for selected tab
                                if selectedTab == tab {
                                    Circle()
                                        .fill(AppColors.primary.opacity(0.3))
                                        .frame(width: 44, height: 44)
                                        .blur(radius: 8)
                                }
                                
                                Image(systemName: tab.icon)
                                    .font(.system(size: 22, weight: .medium))
                                    .symbolEffect(.bounce, value: selectedTab == tab)
                            }
                            
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(selectedTab == tab ? AppColors.primary : .white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(
            ZStack {
                // Glassmorphism background
                Rectangle()
                    .fill(.ultraThinMaterial)
                
                // Gradient overlay for depth
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.5),
                        Color.black.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Subtle animated gradient shimmer
                LinearGradient(
                    colors: [
                        AppColors.primary.opacity(0.05),
                        AppColors.accent.opacity(0.03),
                        AppColors.primary.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
    }
    
    // MARK: - Recording Control Buttons with Animations
    @State private var bookmarkPulse = false
    @State private var controlsAppeared = false
    
    private var recordingControlButtons: some View {
        HStack(spacing: 16) {
            // Bookmark button with pulse animation
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    bookmarkPulse = true
                }
                showBookmarkSheet = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    bookmarkPulse = false
                }
            } label: {
                VStack(spacing: 6) {
                    ZStack {
                        // Outer glow ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 54, height: 54)
                        
                        // Glass background
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.8))
                            .frame(width: 50, height: 50)
                        
                        // Inner gradient
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.2), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .symbolEffect(.bounce, value: bookmarkPulse)
                    }
                    .scaleEffect(bookmarkPulse ? 1.15 : 1.0)
                    
                    Text("Bookmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Pause/Resume Button - Large and prominent
            Button {
                if viewModel.isPaused {
                    viewModel.resumeRecording()
                } else {
                    viewModel.pauseRecording()
                }
            } label: {
                VStack(spacing: 6) {
                    ZStack {
                        // Animated glow ring
                        Circle()
                            .stroke(
                                AngularGradient(
                                    colors: viewModel.isPaused ? 
                                        [.green.opacity(0.8), .green.opacity(0.3), .green.opacity(0.8)] :
                                        [.orange.opacity(0.8), .yellow.opacity(0.5), .orange.opacity(0.8)],
                                    center: .center
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 72, height: 72)
                            .rotationEffect(.degrees(controlsAppeared ? 360 : 0))
                            .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: controlsAppeared)
                        
                        // Button background with gradient
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: viewModel.isPaused ? 
                                        [Color.green, Color.green.opacity(0.8)] :
                                        [Color.orange, Color.orange.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                            .shadow(color: viewModel.isPaused ? .green.opacity(0.5) : .orange.opacity(0.5), radius: 12, y: 4)
                        
                        // Icon with animation
                        Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    
                    Text(viewModel.isPaused ? "Resume" : "Pause")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(viewModel.isPaused ? .green : .orange)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Stop Button - Large and prominent
            Button {
                showStopConfirmation = true
            } label: {
                VStack(spacing: 6) {
                    ZStack {
                        // Pulsing danger ring
                        Circle()
                            .stroke(Color.red.opacity(0.4), lineWidth: 3)
                            .frame(width: 72, height: 72)
                            .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
                            .opacity(viewModel.isRecording ? 0.5 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: viewModel.isRecording)
                        
                        // Button background
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.red, Color.red.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                            .shadow(color: .red.opacity(0.5), radius: 12, y: 4)
                        
                        // Stop icon
                        Image(systemName: "stop.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text("Stop")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Notes button with badge
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = .notes
                }
            } label: {
                VStack(spacing: 6) {
                    ZStack {
                        // Outer glow ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: selectedTab == .notes ? 
                                        [AppColors.primary.opacity(0.6), AppColors.accent.opacity(0.3)] :
                                        [.white.opacity(0.3), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 54, height: 54)
                        
                        // Glass background
                        Circle()
                            .fill(
                                selectedTab == .notes ?
                                    AnyShapeStyle(LinearGradient(
                                        colors: [AppColors.primary.opacity(0.3), AppColors.accent.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )) :
                                    AnyShapeStyle(.ultraThinMaterial.opacity(0.8))
                            )
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "note.text")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(selectedTab == .notes ? AppColors.primary : .white)
                            .symbolEffect(.bounce, value: selectedTab == .notes)
                        
                        // Notes badge
                        if !meetingNotes.isEmpty {
                            Circle()
                                .fill(AppColors.primary)
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 2)
                                )
                                .offset(x: 16, y: -16)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    
                    Text("Notes")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(selectedTab == .notes ? AppColors.primary : .white.opacity(0.8))
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
        .onAppear {
            controlsAppeared = true
        }
    }
    
    // MARK: - Meeting Header (Legacy - kept for compatibility)
    private var meetingHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.meeting.meetingType.icon)
                    .font(.subheadline)
                    .foregroundColor(AppColors.accent)
                Text(viewModel.meeting.meetingType.displayName)
                    .font(AppTypography.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
            }
            
            Text(viewModel.meeting.displayTitle)
                .font(AppTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }
    
    // MARK: - Tab Switcher
    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(RecordingTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.subheadline)
                            Text(tab.rawValue)
                                .font(AppTypography.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                    .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == tab ?
                        Color.white.opacity(0.15) :
                        Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.2))
    }
    
    // MARK: - Timer Display
    private var timerDisplay: some View {
        VStack(spacing: 16) {
            // Recording status
            HStack(spacing: 10) {
                Circle()
                    .fill(viewModel.isRecording ? Color.red : (viewModel.isPaused ? Color.orange : Color.gray))
                    .frame(width: 12, height: 12)
                    .modifier(viewModel.isRecording ? PulsingAnimation() : PulsingAnimation())
                
                Text(statusText)
                    .font(AppTypography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(statusColor.opacity(0.15))
            .clipShape(Capsule())
            
            // Time display
            Text(viewModel.formattedTime)
                .font(.system(size: 64, weight: .ultraLight, design: .monospaced))
                .foregroundColor(.white)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: viewModel.formattedTime)
        }
    }
    
    private var statusText: String {
        if viewModel.isRecording {
            return "Recording"
        } else if viewModel.isPaused {
            return "Paused"
        } else {
            return "Ready"
        }
    }
    
    private var statusColor: Color {
        if viewModel.isRecording {
            return .red
        } else if viewModel.isPaused {
            return .orange
        } else {
            return .gray
        }
    }
    
    // MARK: - Circular Audio Visualizer
    private var circularAudioVisualizer: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            AppColors.primary.opacity(0.3),
                            AppColors.accent.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 220, height: 220)
                .blur(radius: viewModel.isRecording ? 8 : 2)
                .animation(.easeInOut(duration: 0.5), value: viewModel.isRecording)
            
            // Audio level ring
            Circle()
                .trim(from: 0, to: CGFloat(viewModel.audioLevel))
                .stroke(
                    AngularGradient(
                        colors: [AppColors.primary, AppColors.accent, AppColors.primary],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.1), value: viewModel.audioLevel)
            
            // Center waveform
            HStack(spacing: 3) {
                ForEach(0..<12, id: \.self) { index in
                    ModernAudioBar(
                        level: viewModel.audioLevel,
                        index: index,
                        isRecording: viewModel.isRecording
                    )
                }
            }
            .frame(width: 120, height: 60)
            
            // Peak indicator
            if viewModel.peakLevel > 0.9 {
                Circle()
                    .fill(Color.red)
                    .frame(width: 16, height: 16)
                    .offset(y: -110)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Bookmarks List
    private var bookmarksList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bookmark.fill")
                    .foregroundColor(.yellow)
                Text("Bookmarks")
                    .font(AppTypography.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(viewModel.bookmarks.count)")
                    .font(AppTypography.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .foregroundColor(.white.opacity(0.7))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.bookmarks) { bookmark in
                        ModernBookmarkChip(bookmark: bookmark)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Bottom Controls
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Main controls row
            HStack(spacing: 32) {
                // Bookmark button
                ModernControlButton(
                    icon: "bookmark.fill",
                    label: "Bookmark",
                    color: .yellow,
                    isEnabled: viewModel.isActive
                ) {
                    if viewModel.isActive {
                        showBookmarkSheet = true
                    }
                }
                
                // Main record/pause button
                mainRecordButton
                
                // Stop button
                ModernControlButton(
                    icon: "stop.fill",
                    label: "Stop",
                    color: .white,
                    isEnabled: viewModel.isActive
                ) {
                    showStopConfirmation = true
                }
            }
            
            // Quick actions
            if viewModel.isActive {
                HStack(spacing: 24) {
                    Button {
                        viewModel.addBookmark()
                    } label: {
                        Label("Quick Mark", systemImage: "bolt.fill")
                            .font(AppTypography.caption)
                            .foregroundColor(.yellow.opacity(0.8))
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.8),
                    Color.black.opacity(0.4),
                    Color.clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        )
    }
    
    // MARK: - Main Record Button
    private var mainRecordButton: some View {
        Group {
            if viewModel.canStartRecording {
                ModernRecordButton(state: .ready) {
                    Task {
                        await viewModel.startRecording()
                    }
                }
            } else if viewModel.isRecording {
                ModernRecordButton(state: .recording) {
                    viewModel.pauseRecording()
                }
            } else if viewModel.isPaused {
                ModernRecordButton(state: .paused) {
                    viewModel.resumeRecording()
                }
            }
        }
    }
    
    // MARK: - Bookmark Sheet
    private var bookmarkSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Note (optional)", text: $bookmarkNote, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    HStack {
                        Image(systemName: "bookmark.fill")
                            .foregroundColor(.yellow)
                        Text("Bookmark at \(viewModel.formattedTime)")
                    }
                } footer: {
                    Text("Add a note to help you remember this moment")
                }
            }
            .navigationTitle("Add Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        bookmarkNote = ""
                        showBookmarkSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.addBookmark(note: bookmarkNote.isEmpty ? nil : bookmarkNote)
                        bookmarkNote = ""
                        showBookmarkSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Modern Audio Bar
struct ModernAudioBar: View {
    let level: Float
    let index: Int
    let isRecording: Bool
    
    @State private var animatedHeight: CGFloat = 4
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: barColors,
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 4, height: animatedHeight)
            .animation(.spring(response: 0.15, dampingFraction: 0.6), value: animatedHeight)
            .onChange(of: level) { _, newLevel in
                updateHeight(level: newLevel)
            }
            .onAppear {
                updateHeight(level: level)
            }
    }
    
    private func updateHeight(level: Float) {
        guard isRecording else {
            animatedHeight = 4
            return
        }
        
        let phase = Double(index) * 0.3
        let wave = sin(Date().timeIntervalSince1970 * 3 + phase)
        let variation = 0.3 + wave * 0.2
        
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = 50
        let targetHeight = minHeight + (maxHeight - minHeight) * CGFloat(level) * CGFloat(variation + 0.5)
        
        animatedHeight = max(minHeight, min(maxHeight, targetHeight))
    }
    
    private var barColors: [Color] {
        if !isRecording {
            return [Color.white.opacity(0.2), Color.white.opacity(0.3)]
        }
        
        if level > 0.8 {
            return [AppColors.error, AppColors.warning]
        } else if level > 0.5 {
            return [AppColors.warning, AppColors.accent]
        } else {
            return [AppColors.primary, AppColors.accent]
        }
    }
}

// MARK: - Modern Control Button
struct ModernControlButton: View {
    let icon: String
    let label: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(isEnabled ? 0.2 : 0.1))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(color.opacity(isEnabled ? 1 : 0.4))
                }
                
                Text(label)
                    .font(AppTypography.caption)
                    .foregroundColor(.white.opacity(isEnabled ? 0.8 : 0.4))
            }
        }
        .disabled(!isEnabled)
    }
}

// MARK: - Modern Record Button
enum RecordButtonState {
    case ready
    case recording
    case paused
}

struct ModernRecordButton: View {
    let state: RecordButtonState
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer ring with gradient
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                ringColor.opacity(0.3),
                                ringColor,
                                ringColor.opacity(0.3)
                            ],
                            center: .center
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 88, height: 88)
                
                // Inner button
                Circle()
                    .fill(
                        RadialGradient(
                            colors: innerColors,
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 72, height: 72)
                    .overlay(innerIcon)
                    .scaleEffect(isPressed ? 0.92 : 1)
            }
        }
        .buttonStyle(.plain)
        .pressEvents {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
        } onRelease: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = false
            }
        }
    }
    
    private var ringColor: Color {
        switch state {
        case .ready: return .red
        case .recording: return AppColors.primary
        case .paused: return .orange
        }
    }
    
    private var innerColors: [Color] {
        switch state {
        case .ready: return [Color.red.opacity(0.8), Color.red]
        case .recording: return [AppColors.primary.opacity(0.8), AppColors.primary]
        case .paused: return [Color.orange.opacity(0.8), Color.orange]
        }
    }
    
    @ViewBuilder
    private var innerIcon: some View {
        switch state {
        case .ready:
            Circle()
                .fill(Color.white)
                .frame(width: 24, height: 24)
        case .recording:
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .frame(width: 24, height: 24)
        case .paused:
            Image(systemName: "play.fill")
                .font(.system(size: 28))
                .foregroundColor(.white)
                .offset(x: 2)
        }
    }
}

// MARK: - Press Events Modifier
struct PressEventsModifier: ViewModifier {
    var onPress: () -> Void
    var onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEventsModifier(onPress: onPress, onRelease: onRelease))
    }
}

// MARK: - Modern Bookmark Chip
struct ModernBookmarkChip: View {
    let bookmark: RecordingBookmark
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bookmark.fill")
                .font(.caption)
                .foregroundColor(.yellow)
            
            Text(bookmark.formattedTimestamp)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
            
            if let note = bookmark.note, !note.isEmpty {
                Text("•")
                    .foregroundColor(.white.opacity(0.4))
                Text(note)
                    .font(AppTypography.caption)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
        .foregroundColor(.white)
    }
}

// MARK: - Legacy Components (kept for compatibility)

// MARK: - Audio Bar (Legacy)
struct AudioBar: View {
    let level: Float
    let index: Int
    let isRecording: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(barColor)
            .frame(width: 6, height: barHeight)
            .animation(.easeOut(duration: 0.1), value: level)
    }
    
    private var barHeight: CGFloat {
        guard isRecording else { return 4 }
        
        let variation = sin(Double(index) * 0.5) * 0.3
        let adjustedLevel = CGFloat(level) + CGFloat(variation) * CGFloat(level)
        
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = 60
        
        return minHeight + (maxHeight - minHeight) * min(1, max(0, adjustedLevel))
    }
    
    private var barColor: Color {
        if !isRecording {
            return Color.white.opacity(0.3)
        }
        
        if level > 0.8 {
            return .red
        } else if level > 0.5 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Control Button (Legacy)
struct ControlButton: View {
    let icon: String
    let label: String
    let color: Color
    let size: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: size * 0.4))
                    .foregroundColor(color)
                    .frame(width: size, height: size)
                    .background(color.opacity(0.2))
                    .clipShape(Circle())
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - Record Button (Legacy)
struct RecordButton: View {
    var isRecording: Bool
    var isPaused: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                if isRecording && !isPaused {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 24, height: 30)
                } else if isPaused {
                    Image(systemName: "play.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 60, height: 60)
                }
            }
        }
    }
}

// MARK: - Bookmark Chip (Legacy)
struct BookmarkChip: View {
    let bookmark: RecordingBookmark
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "bookmark.fill")
                .font(.caption)
                .foregroundColor(.yellow)
            
            Text(bookmark.formattedTimestamp)
                .font(.caption)
                .fontWeight(.medium)
            
            if let note = bookmark.note, !note.isEmpty {
                Text("•")
                Text(note)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.15))
        .foregroundColor(.white)
        .clipShape(Capsule())
    }
}

// MARK: - Preview
#Preview {
    let meeting = Meeting(
        id: "test-123",
        title: "Team Standup",
        meetingType: .standup,
        status: .draft,
        location: "Conference Room A",
        tags: [],
        language: "en",
        recordingUrl: nil,
        duration: nil,
        recordedAt: nil,
        processingStartedAt: nil,
        processingCompletedAt: nil,
        processingError: nil,
        creatorId: "user-1",
        creator: nil,
        organizationId: "org-1",
        facilityId: nil,
        createdAt: Date(),
        updatedAt: Date(),
        publishedAt: nil,
        participants: nil,
        bookmarks: nil,
        transcript: nil,
        summary: nil,
        actionItems: nil,
        attachments: nil,
        _count: nil
    )
    
    return RecordingView(meeting: meeting, meetingViewModel: MeetingViewModel())
}
