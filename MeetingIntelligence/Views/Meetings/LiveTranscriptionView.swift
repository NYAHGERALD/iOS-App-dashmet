//
//  LiveTranscriptionView.swift
//  MeetingIntelligence
//
//  Professional Real-time Transcription Display
//  Features: Continuous text per speaker, speaker chips at top, maximized space
//

import SwiftUI

// MARK: - Pulsing Animation Modifier
struct LivePulsingAnimation: ViewModifier {
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

// MARK: - Continuous Transcript Model
struct ContinuousTranscript: Identifiable {
    let id = UUID()
    let speakerId: Int
    var text: String
    var startTime: TimeInterval
    var endTime: TimeInterval
    var isActive: Bool = false
    
    mutating func appendText(_ newText: String, at time: TimeInterval) {
        // Clean up text - remove duplicates and merge smoothly
        let trimmedNew = newText.trimmingCharacters(in: .whitespaces)
        let trimmedExisting = text.trimmingCharacters(in: .whitespaces)
        
        // If new text starts with existing, just replace
        if trimmedNew.hasPrefix(trimmedExisting) {
            text = trimmedNew
        } else if !trimmedNew.isEmpty {
            // Append with space
            if !text.isEmpty && !text.hasSuffix(" ") {
                text += " "
            }
            text += trimmedNew
        }
        
        endTime = time
    }
}

// MARK: - Live Transcription View
struct LiveTranscriptionView: View {
    @ObservedObject var speechService: SpeechRecognitionService
    @StateObject private var diarizationService = VoiceDiarizationService.shared
    
    @State private var continuousTranscripts: [ContinuousTranscript] = []
    @State private var currentTranscript: ContinuousTranscript?
    @State private var showSpeakerEditor = false
    @State private var selectedSpeakerId: Int?
    @State private var autoScroll = true
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Speakers Panel (top)
                speakersPanel
                    .frame(height: 80)
                
                // Main Transcript Area (maximized)
                mainTranscriptArea
                    .frame(maxHeight: .infinity)
                
                // Status Bar (minimal)
                statusBar
                    .frame(height: 44)
            }
            .background(Color.black.opacity(0.95))
        }
        .onChange(of: speechService.transcript) { _, newTranscripts in
            updateContinuousTranscripts(from: newTranscripts)
        }
        .onChange(of: speechService.currentSegment) { _, newSegment in
            updateCurrentSegment(newSegment)
        }
        .sheet(isPresented: $showSpeakerEditor) {
            SpeakerManagementSheet(
                diarizationService: diarizationService,
                selectedSpeakerId: $selectedSpeakerId
            )
        }
    }
    
    // MARK: - Speakers Panel
    private var speakersPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SPEAKERS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1.5)
                
                Spacer()
                
                Button {
                    showSpeakerEditor = true
                } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Speaker chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(diarizationService.speakers) { speaker in
                        SpeakerChipView(
                            speaker: speaker,
                            isActive: speaker.id == diarizationService.currentSpeakerId,
                            confidence: speaker.id == diarizationService.currentSpeakerId ? diarizationService.speakerConfidence : speaker.confidence,
                            onTap: {
                                selectedSpeakerId = speaker.id
                                showSpeakerEditor = true
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
        }
        .background(Color.black.opacity(0.3))
    }
    
    // MARK: - Main Transcript Area
    private var mainTranscriptArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    // Completed transcripts
                    ForEach(continuousTranscripts) { transcript in
                        LiveTranscriptBlockView(
                            transcript: transcript,
                            speaker: diarizationService.getSpeaker(for: transcript.speakerId)
                        )
                        .id(transcript.id)
                    }
                    
                    // Current active transcript
                    if let current = currentTranscript {
                        LiveTranscriptBlockView(
                            transcript: current,
                            speaker: diarizationService.getSpeaker(for: current.speakerId),
                            isLive: true
                        )
                        .id("current")
                    } else if speechService.isRecognizing && continuousTranscripts.isEmpty {
                        // Empty state - listening
                        listeningIndicator
                            .id("listening")
                    }
                    
                    Color.clear.frame(height: 20)
                        .id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .onChange(of: currentTranscript?.text) { _, _ in
                if autoScroll {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("current", anchor: .bottom)
                    }
                }
            }
            .onChange(of: continuousTranscripts.count) { _, _ in
                if autoScroll {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Listening Indicator
    private var listeningIndicator: some View {
        HStack(spacing: 12) {
            // Animated waveform
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.primary.opacity(0.6))
                        .frame(width: 3, height: CGFloat.random(in: 8...20))
                        .animation(
                            .easeInOut(duration: 0.4)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1),
                            value: speechService.isRecognizing
                        )
                }
            }
            
            Text("Listening...")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            if let language = speechService.currentLanguage {
                Text(language.flag)
                    .font(.title3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }
    
    // MARK: - Status Bar
    private var statusBar: some View {
        HStack(spacing: 16) {
            // Language
            if let language = speechService.currentLanguage {
                HStack(spacing: 4) {
                    Text(language.flag)
                    Text(language.name.components(separatedBy: " (").first ?? "")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Divider()
                .frame(height: 16)
                .background(Color.white.opacity(0.2))
            
            // Recognition status
            HStack(spacing: 6) {
                Circle()
                    .fill(speechService.isRecognizing ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
                
                Text(speechService.recognizerStatus)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Auto-scroll toggle
            Button {
                autoScroll.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle")
                        .font(.caption)
                    Text("Auto-scroll")
                        .font(.caption)
                }
                .foregroundColor(autoScroll ? AppColors.primary : .white.opacity(0.5))
            }
            
            // Segment count
            Text("\(continuousTranscripts.count + (currentTranscript != nil ? 1 : 0)) blocks")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .background(Color.black.opacity(0.5))
    }
    
    // MARK: - Update Logic
    private func updateContinuousTranscripts(from segments: [LiveTranscriptSegment]) {
        guard !segments.isEmpty else { return }
        
        var newTranscripts: [ContinuousTranscript] = []
        var currentBlock: ContinuousTranscript?
        
        for segment in segments where segment.isFinal {
            if let block = currentBlock {
                if block.speakerId == segment.speakerId {
                    // Same speaker - append to existing block
                    currentBlock?.appendText(segment.displayText, at: segment.timestamp)
                } else {
                    // Different speaker - save current and start new
                    newTranscripts.append(block)
                    currentBlock = ContinuousTranscript(
                        speakerId: segment.speakerId,
                        text: segment.displayText,
                        startTime: segment.timestamp,
                        endTime: segment.timestamp
                    )
                }
            } else {
                // First block
                currentBlock = ContinuousTranscript(
                    speakerId: segment.speakerId,
                    text: segment.displayText,
                    startTime: segment.timestamp,
                    endTime: segment.timestamp
                )
            }
        }
        
        // Add last block if exists
        if let block = currentBlock {
            newTranscripts.append(block)
        }
        
        continuousTranscripts = newTranscripts
    }
    
    private func updateCurrentSegment(_ segment: LiveTranscriptSegment?) {
        guard let segment = segment else {
            currentTranscript = nil
            return
        }
        
        // Check if same speaker as current
        if var current = currentTranscript, current.speakerId == segment.speakerId {
            current.text = segment.displayText
            current.endTime = segment.timestamp
            current.isActive = true
            currentTranscript = current
        } else {
            // New speaker or first segment
            currentTranscript = ContinuousTranscript(
                speakerId: segment.speakerId,
                text: segment.displayText,
                startTime: segment.timestamp,
                endTime: segment.timestamp,
                isActive: true
            )
        }
    }
}

// MARK: - Speaker Chip View
struct SpeakerChipView: View {
    let speaker: VoiceProfile
    let isActive: Bool
    let confidence: Float
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // Avatar with activity indicator
                ZStack {
                    Circle()
                        .fill(Color(hex: speaker.color))
                        .frame(width: 36, height: 36)
                    
                    Text(speakerInitial)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Active ring
                    if isActive {
                        Circle()
                            .stroke(Color.green, lineWidth: 2)
                            .frame(width: 42, height: 42)
                            .modifier(LivePulsingAnimation())
                    }
                }
                
                // Name
                Text(speaker.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isActive ? .white : .white.opacity(0.7))
                    .lineLimit(1)
                
                // Confidence bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 3)
                        
                        Capsule()
                            .fill(confidenceColor)
                            .frame(width: geo.size.width * CGFloat(confidence), height: 3)
                    }
                }
                .frame(width: 40, height: 3)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? Color.white.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var speakerInitial: String {
        let name = speaker.label
        if name.hasPrefix("Speaker ") {
            return String(name.dropFirst(8).prefix(1))
        }
        return String(name.prefix(1)).uppercased()
    }
    
    private var confidenceColor: Color {
        switch confidence {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        default: return .orange
        }
    }
}

// MARK: - Live Transcript Block View
struct LiveTranscriptBlockView: View {
    let transcript: ContinuousTranscript
    let speaker: VoiceProfile?
    var isLive: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Speaker header
            HStack(spacing: 8) {
                // Color indicator
                Circle()
                    .fill(Color(hex: speaker?.color ?? "6366F1"))
                    .frame(width: 8, height: 8)
                
                Text(speaker?.label ?? "Speaker \(transcript.speakerId + 1)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: speaker?.color ?? "6366F1"))
                
                // Timestamp
                Text(formatTimestamp(transcript.startTime))
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                
                if isLive {
                    // Live indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                            .modifier(LivePulsingAnimation())
                        
                        Text("LIVE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(4)
                }
                
                Spacer()
            }
            
            // Transcript text
            Text(transcript.text)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(isLive ? 1.0 : 0.9))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            // Duration if long enough
            if transcript.endTime - transcript.startTime > 5 {
                Text("\(formatDuration(transcript.endTime - transcript.startTime))")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: speaker?.color ?? "6366F1").opacity(isLive ? 0.15 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isLive ? Color(hex: speaker?.color ?? "6366F1").opacity(0.4) : Color.clear,
                    lineWidth: 1
                )
        )
    }
    
    private func formatTimestamp(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return "\(Int(duration))s"
        }
        return "\(Int(duration / 60))m \(Int(duration) % 60)s"
    }
}

// MARK: - Speaker Management Sheet
struct SpeakerManagementSheet: View {
    @ObservedObject var diarizationService: VoiceDiarizationService
    @Binding var selectedSpeakerId: Int?
    @Environment(\.dismiss) private var dismiss
    
    @State private var editingName: String = ""
    @State private var showMergeOptions = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(diarizationService.speakers) { speaker in
                        SpeakerRowView(
                            speaker: speaker,
                            isSelected: speaker.id == selectedSpeakerId,
                            onSelect: { selectedSpeakerId = speaker.id },
                            onRename: { newName in
                                diarizationService.renameSpeaker(id: speaker.id, name: newName)
                            }
                        )
                    }
                } header: {
                    Text("Identified Speakers")
                } footer: {
                    Text("Tap a speaker to rename. The system learns voice patterns over time for better accuracy.")
                }
                
                if diarizationService.speakers.count > 1 {
                    Section {
                        Button {
                            showMergeOptions = true
                        } label: {
                            Label("Merge Speakers", systemImage: "arrow.triangle.merge")
                        }
                    } header: {
                        Text("Actions")
                    } footer: {
                        Text("If the same person was identified as multiple speakers, merge them to combine their voice profiles.")
                    }
                }
            }
            .navigationTitle("Manage Speakers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showMergeOptions) {
                MergeSpeakersSheet(diarizationService: diarizationService)
            }
        }
    }
}

// MARK: - Speaker Row View
struct SpeakerRowView: View {
    let speaker: VoiceProfile
    let isSelected: Bool
    var onSelect: () -> Void
    var onRename: (String) -> Void
    
    @State private var isEditing = false
    @State private var editedName: String = ""
    
    var body: some View {
        HStack(spacing: 12) {
            // Color dot
            Circle()
                .fill(Color(hex: speaker.color))
                .frame(width: 12, height: 12)
            
            if isEditing {
                TextField("Speaker name", text: $editedName, onCommit: {
                    onRename(editedName)
                    isEditing = false
                })
                .textFieldStyle(.roundedBorder)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(speaker.label)
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        Text("\(speaker.sampleCount) samples")
                        Text("•")
                        Text(formatDuration(speaker.totalDuration))
                        Text("•")
                        Text("\(Int(speaker.confidence * 100))% confidence")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                editedName = speaker.label
                isEditing = true
            } label: {
                Image(systemName: "pencil.circle")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return "\(Int(duration))s"
        }
        return "\(Int(duration / 60))m \(Int(duration) % 60)s"
    }
}

// MARK: - Merge Speakers Sheet
struct MergeSpeakersSheet: View {
    @ObservedObject var diarizationService: VoiceDiarizationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var sourceSpeaker: Int?
    @State private var targetSpeaker: Int?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Select two speakers to merge")
                    .font(.headline)
                    .padding(.top)
                
                // Source speaker selection
                VStack(alignment: .leading) {
                    Text("MERGE THIS SPEAKER")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(diarizationService.speakers) { speaker in
                                SpeakerSelectionButton(
                                    speaker: speaker,
                                    isSelected: sourceSpeaker == speaker.id
                                ) {
                                    sourceSpeaker = speaker.id
                                    if targetSpeaker == speaker.id {
                                        targetSpeaker = nil
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Image(systemName: "arrow.down")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                // Target speaker selection
                VStack(alignment: .leading) {
                    Text("INTO THIS SPEAKER")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(diarizationService.speakers.filter { $0.id != sourceSpeaker }) { speaker in
                                SpeakerSelectionButton(
                                    speaker: speaker,
                                    isSelected: targetSpeaker == speaker.id
                                ) {
                                    targetSpeaker = speaker.id
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // Merge button
                Button {
                    if let source = sourceSpeaker, let target = targetSpeaker {
                        diarizationService.mergeSpeakers(from: source, to: target)
                        dismiss()
                    }
                } label: {
                    Text("Merge Speakers")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            (sourceSpeaker != nil && targetSpeaker != nil) ? Color.blue : Color.gray
                        )
                        .cornerRadius(12)
                }
                .disabled(sourceSpeaker == nil || targetSpeaker == nil)
                .padding()
            }
            .navigationTitle("Merge Speakers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Speaker Selection Button
struct SpeakerSelectionButton: View {
    let speaker: VoiceProfile
    let isSelected: Bool
    var onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: speaker.color))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                    )
                
                Text(speaker.label)
                    .font(.caption)
                    .foregroundColor(isSelected ? .blue : .primary)
            }
            .padding(8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    LiveTranscriptionView(speechService: SpeechRecognitionService.shared)
        .preferredColorScheme(.dark)
}
