//
//  TranscriptTab.swift
//  MeetingIntelligence
//
//  Phase 2 - Transcript Viewer with search, timestamps, and speaker blocks
//

import SwiftUI

struct TranscriptTab: View {
    @ObservedObject var viewModel: MeetingDetailViewModel
    @State private var selectedSpeaker: String?
    @State private var showSpeakerFilter = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and Filter Bar
            searchBar
            
            if viewModel.transcript.isEmpty {
                emptyState
            } else {
                transcriptList
            }
        }
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
            
            // Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    // All Speakers Pill
                    TranscriptFilterPill(
                        title: "All",
                        isSelected: selectedSpeaker == nil,
                        count: viewModel.transcript.count
                    ) {
                        selectedSpeaker = nil
                    }
                    
                    // Speaker Pills
                    ForEach(viewModel.uniqueSpeakers, id: \.self) { speaker in
                        let count = viewModel.transcript.filter { $0.speakerLabel == speaker }.count
                        TranscriptFilterPill(
                            title: speaker,
                            isSelected: selectedSpeaker == speaker,
                            count: count
                        ) {
                            selectedSpeaker = speaker
                        }
                    }
                }
            }
            
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
            
            if viewModel.meeting.status == .processing {
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
        var blocks = viewModel.filteredTranscript
        
        if let speaker = selectedSpeaker {
            blocks = blocks.filter { $0.speakerLabel == speaker }
        }
        
        return blocks
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
        HStack(alignment: .top, spacing: AppSpacing.md) {
            // Speaker Avatar
            speakerAvatar
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                // Header Row
                HStack(alignment: .center, spacing: AppSpacing.sm) {
                    Text(block.speakerLabel)
                        .font(AppTypography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(speakerColor)
                    
                    Spacer()
                    
                    // Timestamp
                    Button {
                        onTimestampTap?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.caption2)
                            Text(block.formattedStartTime)
                                .font(AppTypography.caption)
                        }
                        .foregroundColor(AppColors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.primary.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                
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
