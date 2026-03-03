//
//  TranscriptTab.swift
//  MeetingIntelligence
//
//  Phase 2 - Transcript Viewer with search, timestamps, and speaker blocks
//

import SwiftUI

struct TranscriptTab: View {
    @ObservedObject var viewModel: MeetingDetailViewModel
    @Binding var rawTranscript: String
    
    // Action Items Extraction
    @StateObject private var taskViewModel = TaskViewModel()
    @State private var isExtracting = false
    @State private var extractionMessage: String?
    @State private var showExtractionResult = false
    @State private var extractedCount: Int = 0
    
    /// Whether transcript content is available for extraction
    private var hasTranscriptContent: Bool {
        !viewModel.transcript.isEmpty || !rawTranscript.isEmpty
    }
    
    /// Best available transcript text for AI extraction
    private var transcriptForExtraction: String {
        if !viewModel.transcript.isEmpty {
            return viewModel.transcript
                .sorted { $0.startTime < $1.startTime }
                .map { "\($0.speakerLabel): \($0.content)" }
                .joined(separator: "\n")
        }
        return rawTranscript
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Search and Filter Bar
                searchBar
                
                if !viewModel.transcript.isEmpty {
                    transcriptList
                } else if !rawTranscript.isEmpty {
                    rawTranscriptView
                } else {
                    emptyState
                }
            }
            
            // Floating Extract Action Items Button
            if hasTranscriptContent {
                extractActionItemsButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .onAppear {
            taskViewModel.configure(
                userId: viewModel.userId ?? "",
                organizationId: viewModel.meeting.organizationId
            )
        }
        .alert("Action Items Extracted", isPresented: $showExtractionResult) {
            Button("OK") {
                showExtractionResult = false
            }
        } message: {
            Text(extractionMessage ?? "")
        }
    }
    
    /// Whether action items have already been extracted for this meeting
    private var hasExistingActionItems: Bool {
        !viewModel.actionItems.isEmpty
    }
    
    // MARK: - Extract Action Items FAB
    private var extractActionItemsButton: some View {
        Button {
            if !hasExistingActionItems {
                Task { await extractActionItems() }
            }
        } label: {
            HStack(spacing: 8) {
                if isExtracting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else if hasExistingActionItems {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                }
                Text(isExtracting ? "Extracting Action Items..." : hasExistingActionItems ? "Action Items Extracted" : "Extract Action Items")
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                if !isExtracting && !hasExistingActionItems {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: hasExistingActionItems
                        ? [Color(hex: "6B7280"), Color(hex: "4B5563")]
                        : [Color(hex: "8B5CF6"), Color(hex: "6366F1")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: hasExistingActionItems ? Color.clear : Color(hex: "8B5CF6").opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isExtracting && !hasExistingActionItems)
    }
    
    // MARK: - Extraction Logic
    private func extractActionItems() async {
        let transcriptText = transcriptForExtraction
        guard !transcriptText.isEmpty else { return }
        
        isExtracting = true
        
        let extracted = await taskViewModel.extractActionItems(
            meetingId: viewModel.meeting.id,
            transcript: transcriptText
        )
        
        isExtracting = false
        
        if let tasks = extracted, !tasks.isEmpty {
            extractedCount = tasks.count
            extractionMessage = "Successfully extracted \(tasks.count) action item\(tasks.count == 1 ? "" : "s") from the transcript."
            await viewModel.refreshMeeting()
        } else {
            extractionMessage = "No action items could be identified from this transcript."
        }
        showExtractionResult = true
    }
    
    // MARK: - Raw Transcript View (fallback when no structured blocks)
    private var rawTranscriptView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(AppColors.primary)
                    Text("Full Transcript")
                        .font(AppTypography.headline)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text("\(rawTranscript.split(separator: " ").count) words")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(.bottom, 4)
                
                // Transcript text
                Text(filteredRawTranscript)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textPrimary)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.background)
    }
    
    private var filteredRawTranscript: String {
        if viewModel.transcriptSearchText.isEmpty {
            return rawTranscript
        }
        return rawTranscript
            .components(separatedBy: "\n")
            .filter { $0.localizedCaseInsensitiveContains(viewModel.transcriptSearchText) }
            .joined(separator: "\n")
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        VStack(spacing: AppSpacing.sm) {
            // Search Field
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.textTertiary)
                
                TextField("Search transcript...", text: $viewModel.transcriptSearchText)
                    .textFieldStyle(.plain)
                    .font(AppTypography.body)
                
                if !viewModel.transcriptSearchText.isEmpty {
                    Button {
                        viewModel.transcriptSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            .padding(AppSpacing.sm)
            .background(AppColors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
            
            // Search Results Info
            if !viewModel.transcriptSearchText.isEmpty {
                HStack {
                    Text("\(filteredBlocks.count) results")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 60))
                .foregroundColor(AppColors.textTertiary)
            
            Text("No Transcript Available")
                .font(AppTypography.title3)
                .foregroundColor(AppColors.textPrimary)
            
            Text("The transcript will appear here once the recording has been processed.")
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            
            if viewModel.meeting.safeStatus == .processing {
                HStack(spacing: AppSpacing.sm) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                    Text("Processing audio...")
                        .font(AppTypography.footnote)
                        .foregroundColor(AppColors.primary)
                }
                .padding(.top, AppSpacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
    }
    
    // MARK: - Transcript List
    private var transcriptList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppSpacing.md) {
                    ForEach(Array(filteredBlocks.enumerated()), id: \.element.id) { index, block in
                        TranscriptBlockView(
                            block: block,
                            searchText: viewModel.transcriptSearchText,
                            isHighlighted: false,
                            onTimestampTap: {
                                viewModel.playFromTimestamp(block.startTime)
                            }
                        )
                        .id(block.id)
                    }
                }
                .padding(AppSpacing.md)
            }
            .background(AppColors.background)
        }
    }
    
    // MARK: - Computed Properties
    private var filteredBlocks: [TranscriptBlock] {
        return viewModel.filteredTranscript
    }
}

// MARK: - Transcript Filter Pill
struct TranscriptFilterPill: View {
    let title: String
    let isSelected: Bool
    var count: Int? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(AppTypography.footnote)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if let count = count {
                    Text("\(count)")
                        .font(AppTypography.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            isSelected ? Color.white.opacity(0.2) : AppColors.surfaceSecondary
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        AppGradients.primary
                    } else {
                        AppColors.surfaceSecondary
                    }
                }
            )
            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Transcript Block View
struct TranscriptBlockView: View {
    let block: TranscriptBlock
    let searchText: String
    var isHighlighted: Bool = false
    var onTimestampTap: (() -> Void)?
    
    private var speakerColor: Color {
        // Generate consistent color based on speaker label hash
        let colors: [Color] = [
            AppColors.primary,
            AppColors.secondary,
            AppColors.accent,
            Color.purple,
            Color.orange,
            AppColors.info
        ]
        let hash = abs(block.speakerLabel.hashValue)
        return colors[hash % colors.count]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            // Speaker Label
            Text(block.speakerLabel)
                .font(AppTypography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(speakerColor)
            
            // Content
            highlightedText(block.content, searchText: searchText)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textPrimary)
                .lineSpacing(4)
            
            // Confidence Badge (if low)
            if let confidence = block.confidence, confidence < 0.8 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text("Low confidence (\(Int(confidence * 100))%)")
                        .font(AppTypography.caption2)
                }
                .foregroundColor(AppColors.warning)
                .padding(.top, 4)
            }
        }
        .padding(AppSpacing.md)
        .background(isHighlighted ? AppColors.primary.opacity(0.08) : AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                .stroke(isHighlighted ? AppColors.primary.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    private var speakerAvatar: some View {
        Circle()
            .fill(speakerColor.opacity(0.15))
            .frame(width: 40, height: 40)
            .overlay(
                Text(String(block.speakerLabel.prefix(1)).uppercased())
                    .font(AppTypography.headline)
                    .foregroundColor(speakerColor)
            )
    }
    
    @ViewBuilder
    private func highlightedText(_ text: String, searchText: String) -> some View {
        if searchText.isEmpty {
            Text(text)
        } else {
            Text(highlightMatches(in: text, searchText: searchText))
        }
    }
    
    private func highlightMatches(in text: String, searchText: String) -> AttributedString {
        var result = AttributedString(text)
        
        guard !searchText.isEmpty else { return result }
        
        // Find all ranges and highlight them
        let lowercaseText = text.lowercased()
        let lowercaseSearch = searchText.lowercased()
        
        var searchStart = lowercaseText.startIndex
        
        while let foundRange = lowercaseText.range(of: lowercaseSearch, range: searchStart..<lowercaseText.endIndex) {
            // Convert String.Index to AttributedString range
            let startDistance = lowercaseText.distance(from: lowercaseText.startIndex, to: foundRange.lowerBound)
            let endDistance = lowercaseText.distance(from: lowercaseText.startIndex, to: foundRange.upperBound)
            
            let attrStartIndex = result.index(result.startIndex, offsetByCharacters: startDistance)
            let attrEndIndex = result.index(result.startIndex, offsetByCharacters: endDistance)
            
            result[attrStartIndex..<attrEndIndex].backgroundColor = AppColors.warning.opacity(0.3)
            result[attrStartIndex..<attrEndIndex].foregroundColor = AppColors.textPrimary
            
            searchStart = foundRange.upperBound
        }
        
        return result
    }
}

// MARK: - Duration Formatter
struct TranscriptDurationFormatter {
    static func format(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Preview
#Preview {
    Text("Transcript Tab Preview")
}
