//
//  DocumentSectionEditorSheet.swift
//  MeetingIntelligence
//
//  Phase 9: Document Section Editor
//  Enterprise-grade inline editing with AI-powered analysis
//

import SwiftUI

// MARK: - Document Section Editor Sheet
struct DocumentSectionEditorSheet: View {
    let section: DocumentSection
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    @State private var editedContent: String
    @State private var showAIAnalysis = false
    @State private var showToneAnalysis = false
    
    // AI Analysis State
    @StateObject private var analysisService = AITextAnalysisService.shared
    @State private var contentSuggestions: [AIContentSuggestion] = []
    @State private var toneResult: ToneAnalysisResult?
    
    // Text metrics
    @State private var wordCount: Int = 0
    @State private var characterCount: Int = 0
    @State private var sentenceCount: Int = 0
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    private var hasChanges: Bool {
        editedContent != section.content
    }
    
    init(section: DocumentSection, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.section = section
        self.onSave = onSave
        self.onCancel = onCancel
        _editedContent = State(initialValue: section.content)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    sectionHeader
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            textEditorSection
                            metricsBar
                            
                            if showAIAnalysis {
                                aiAnalysisSection
                            }
                            
                            formattingGuidelines
                        }
                        .padding()
                    }
                    
                    bottomToolbar
                }
                
                // Loading overlay
                if analysisService.isAnalyzing {
                    analysisLoadingOverlay
                }
            }
            .navigationTitle("Edit Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { onSave(editedContent) }
                        .fontWeight(.semibold)
                        .disabled(editedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: editedContent) { _, newValue in
                updateMetrics(newValue)
            }
            .onAppear {
                updateMetrics(editedContent)
            }
            .fullScreenCover(isPresented: $showToneAnalysis) {
                ToneAnalysisSheet(
                    toneResult: toneResult,
                    isLoading: analysisService.isAnalyzing,
                    analysisProgress: analysisService.analysisProgress,
                    currentStep: analysisService.currentAnalysisStep,
                    onApplySuggestion: { suggestion in
                        applyToneSuggestion(suggestion)
                    },
                    onDismiss: {
                        showToneAnalysis = false
                    }
                )
            }
        }
    }
    
    // MARK: - Section Header
    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textPrimary)
            
            HStack(spacing: 12) {
                if section.hasChanges {
                    Label("Modified", systemImage: "pencil.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
                
                if let result = toneResult {
                    Label(result.overallTone.rawValue, systemImage: result.overallTone.icon)
                        .font(.system(size: 12))
                        .foregroundColor(toneColor(result.overallTone))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
    }
    
    // MARK: - Text Editor
    private var textEditorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DisclosureGroup {
                Text(section.content)
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } label: {
                Label("Original Content", systemImage: "doc.text")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textSecondary)
            }
            
            TextEditor(text: $editedContent)
                .font(.system(size: 15))
                .frame(minHeight: 200)
                .padding(12)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Metrics Bar
    private var metricsBar: some View {
        HStack(spacing: 0) {
            metricItem(value: "\(wordCount)", label: "Words", color: .blue)
            Divider().frame(height: 30)
            metricItem(value: "\(characterCount)", label: "Characters", color: .purple)
            Divider().frame(height: 30)
            metricItem(value: "\(sentenceCount)", label: "Sentences", color: .teal)
            Divider().frame(height: 30)
            metricItem(value: hasChanges ? "Yes" : "No", label: "Changed", color: hasChanges ? .orange : .green)
        }
        .padding(.vertical, 12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func metricItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - AI Analysis Section
    private var aiAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("AI Content Analysis", systemImage: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.purple)
                
                Spacer()
                
                Button {
                    runContentAnalysis()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.purple)
                }
            }
            
            if contentSuggestions.isEmpty {
                emptyAnalysisState
            } else {
                ForEach(contentSuggestions) { suggestion in
                    suggestionCard(suggestion)
                }
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var emptyAnalysisState: some View {
        VStack(spacing: 14) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 36))
                .foregroundColor(.purple.opacity(0.4))
            
            Text("Analyze your content for professional HR documentation standards")
                .font(.system(size: 13))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                runContentAnalysis()
            } label: {
                Text("Run Analysis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.purple)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
    
    private func suggestionCard(_ suggestion: AIContentSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: suggestion.type.icon)
                    .font(.system(size: 12))
                    .foregroundColor(suggestionColor(suggestion.type))
                
                Text(suggestion.type.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(suggestionColor(suggestion.type))
                
                Spacer()
                
                // Impact badge
                Text(suggestion.impact.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(impactColor(suggestion.impact))
                    .clipShape(Capsule())
                
                // Confidence indicator
                Text("\(Int(suggestion.confidence * 100))%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(textSecondary)
            }
            
            Text(suggestion.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(textPrimary)
            
            Text(suggestion.description)
                .font(.system(size: 12))
                .foregroundColor(textSecondary)
            
            if let suggestedText = suggestion.suggestedText {
                HStack {
                    Spacer()
                    Button {
                        editedContent = suggestedText
                    } label: {
                        Label("Apply Fix", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(suggestionColor(suggestion.type))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Formatting Guidelines
    private var formattingGuidelines: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HR Documentation Standards")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(textSecondary)
            
            VStack(alignment: .leading, spacing: 8) {
                guidelineRow(icon: "target", text: "Be specific with dates, times, and observable behaviors")
                guidelineRow(icon: "doc.text.fill", text: "Reference applicable policy sections")
                guidelineRow(icon: "person.fill", text: "Focus on actions, not personal attributes")
                guidelineRow(icon: "clock.fill", text: "Include clear timeframes for corrective actions")
                guidelineRow(icon: "checkmark.shield.fill", text: "Ensure legal compliance and consistency")
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func guidelineRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(textSecondary)
        }
    }
    
    // MARK: - Bottom Toolbar
    private var bottomToolbar: some View {
        HStack(spacing: 20) {
            toolbarButton(icon: "arrow.uturn.backward", label: "Reset", isActive: hasChanges) {
                editedContent = section.content
            }
            .disabled(!hasChanges)
            
            Divider().frame(height: 32)
            
            toolbarButton(icon: "sparkles", label: "AI Help", isActive: showAIAnalysis) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showAIAnalysis.toggle()
                    if showAIAnalysis && contentSuggestions.isEmpty {
                        runContentAnalysis()
                    }
                }
            }
            
            Divider().frame(height: 32)
            
            toolbarButton(
                icon: "waveform",
                label: "Tone",
                isActive: toneResult != nil,
                activeColor: toneResult != nil ? toneColor(toneResult!.overallTone) : .gray
            ) {
                runToneAnalysis()
                showToneAnalysis = true
            }
            
            Spacer()
        }
        .padding()
        .background(cardBackground)
    }
    
    private func toolbarButton(icon: String, label: String, isActive: Bool, activeColor: Color = .blue, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(isActive ? activeColor : .gray)
        }
    }
    
    // MARK: - Loading Overlay
    private var analysisLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Animated progress ring
                ZStack {
                    Circle()
                        .stroke(Color.purple.opacity(0.2), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: analysisService.analysisProgress)
                        .stroke(Color.purple, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: analysisService.analysisProgress)
                    
                    Text("\(Int(analysisService.analysisProgress * 100))%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text(analysisService.currentAnalysisStep)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            .padding(30)
            .background(Color(UIColor.systemBackground).opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.2), radius: 20)
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateMetrics(_ text: String) {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        wordCount = words.count
        characterCount = text.count
        sentenceCount = sentences.count
    }
    
    private func runContentAnalysis() {
        let context = DocumentContext(
            documentType: .warning,
            sectionType: section.title,
            companyName: nil,
            employeeName: nil
        )
        
        Task {
            contentSuggestions = await analysisService.generateContentSuggestions(
                text: editedContent,
                sectionType: section.title,
                context: context
            )
        }
    }
    
    private func runToneAnalysis() {
        let context = DocumentContext(
            documentType: .warning,
            sectionType: section.title,
            companyName: nil,
            employeeName: nil
        )
        
        Task {
            toneResult = await analysisService.analyzeTone(text: editedContent, context: context)
        }
    }
    
    private func applyToneSuggestion(_ suggestion: ToneAnalysisResult.ToneSuggestion) {
        editedContent = editedContent.replacingOccurrences(
            of: suggestion.original,
            with: suggestion.suggested,
            options: .caseInsensitive
        )
        runToneAnalysis()
    }
    
    private func toneColor(_ tone: ToneAnalysisResult.ToneType) -> Color {
        switch tone.color {
        case "green": return .green
        case "blue": return .blue
        case "gray": return .gray
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "teal": return .teal
        default: return .gray
        }
    }
    
    private func suggestionColor(_ type: AIContentSuggestion.SuggestionType) -> Color {
        switch type.color {
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "green": return .green
        case "teal": return .teal
        case "pink": return .pink
        case "indigo": return .indigo
        case "cyan": return .cyan
        default: return .gray
        }
    }
    
    private func impactColor(_ impact: AIContentSuggestion.ImpactLevel) -> Color {
        switch impact {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .gray
        }
    }
}

// MARK: - Tone Analysis Sheet
struct ToneAnalysisSheet: View {
    let toneResult: ToneAnalysisResult?
    let isLoading: Bool
    let analysisProgress: Double
    let currentStep: String
    let onApplySuggestion: (ToneAnalysisResult.ToneSuggestion) -> Void
    let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6) }
    private var cardBackground: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.white }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if let result = toneResult {
                    analysisResultView(result)
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Tone Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { onDismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color.purple.opacity(0.2), lineWidth: 6)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: analysisProgress)
                    .stroke(Color.purple, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: analysisProgress)
                
                Text("\(Int(analysisProgress * 100))%")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)
            }
            
            VStack(spacing: 6) {
                Text("Analyzing Content")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Text(currentStep)
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
            }
        }
    }
    
    private func analysisResultView(_ result: ToneAnalysisResult) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                overallToneCard(result)
                metricsSection(result)
                scoresSection(result)
                
                if !result.suggestions.isEmpty {
                    suggestionsSection(result)
                }
                
                writingTipsSection
            }
            .padding()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.4))
            Text("No analysis available")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
        }
    }
    
    private func overallToneCard(_ result: ToneAnalysisResult) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(toneColor(result.overallTone).opacity(0.15))
                    .frame(width: 90, height: 90)
                
                Image(systemName: result.overallTone.icon)
                    .font(.system(size: 36))
                    .foregroundColor(toneColor(result.overallTone))
            }
            
            VStack(spacing: 6) {
                Text("Overall Tone")
                    .font(.system(size: 12))
                    .foregroundColor(textSecondary)
                
                Text(result.overallTone.rawValue)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(toneColor(result.overallTone))
            }
            
            Text(result.overallTone.description)
                .font(.system(size: 13))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func metricsSection(_ result: ToneAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Text Metrics")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textPrimary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metricCard(label: "Words", value: "\(result.metrics.wordCount)", icon: "textformat.abc")
                metricCard(label: "Sentences", value: "\(result.metrics.sentenceCount)", icon: "text.alignleft")
                metricCard(label: "Avg Words/Sentence", value: String(format: "%.1f", result.metrics.averageWordsPerSentence), icon: "chart.bar.fill")
                metricCard(label: "Reading Grade", value: String(format: "%.1f", result.metrics.fleschKincaidGrade), icon: "graduationcap.fill")
                metricCard(label: "Passive Voice", value: String(format: "%.0f%%", result.metrics.passiveVoicePercentage), icon: "arrow.left.arrow.right")
                metricCard(label: "Complex Words", value: String(format: "%.0f%%", result.metrics.complexWordPercentage), icon: "textformat.size")
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func metricCard(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textPrimary)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(textSecondary)
            }
            
            Spacer()
        }
        .padding(10)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func scoresSection(_ result: ToneAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quality Scores")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textPrimary)
            
            VStack(spacing: 14) {
                scoreBar(label: "Professionalism", score: result.professionalismScore, color: .blue)
                scoreBar(label: "Clarity", score: result.clarityScore, color: .green)
                scoreBar(label: "Objectivity", score: result.objectivityScore, color: .purple)
                scoreBar(label: "Readability", score: result.readabilityScore, color: .teal)
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func scoreBar(label: String, score: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
                Spacer()
                Text("\(Int(score))%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(scoreColor(score))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [scoreColor(score).opacity(0.7), scoreColor(score)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (score / 100), height: 8)
                        .animation(.easeOut(duration: 0.5), value: score)
                }
            }
            .frame(height: 8)
        }
    }
    
    private func suggestionsSection(_ result: ToneAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Improvement Suggestions", systemImage: "lightbulb.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.orange)
            
            ForEach(result.suggestions) { suggestion in
                toneSuggestionCard(suggestion)
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func toneSuggestionCard(_ suggestion: ToneAnalysisResult.ToneSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\"\(suggestion.original)\"")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .strikethrough()
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundColor(textSecondary)
                
                Text("\"\(suggestion.suggested)\"")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
                
                Spacer()
                
                Text("\(Int(suggestion.confidence * 100))%")
                    .font(.system(size: 10))
                    .foregroundColor(textSecondary)
            }
            
            HStack {
                Text(suggestion.reason)
                    .font(.system(size: 11))
                    .foregroundColor(textSecondary)
                
                Spacer()
                
                Button {
                    onApplySuggestion(suggestion)
                } label: {
                    Text("Apply")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.green)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var writingTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("HR Documentation Best Practices", systemImage: "info.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 10) {
                tipRow("Document observable behaviors, not attitudes or intentions")
                tipRow("Include specific dates, times, and locations")
                tipRow("Reference applicable policy sections by number")
                tipRow("Use objective, non-judgmental language")
                tipRow("State clear expectations and consequences")
                tipRow("Include deadlines for corrective actions")
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.green)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(textSecondary)
        }
    }
    
    private func toneColor(_ tone: ToneAnalysisResult.ToneType) -> Color {
        switch tone.color {
        case "green": return .green
        case "blue": return .blue
        case "gray": return .gray
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "teal": return .teal
        default: return .gray
        }
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .orange }
        return .red
    }
}

// MARK: - Supporting Views (Add Comment, Approval, Reject Sheets)

struct AddCommentSheet: View {
    let sections: [DocumentSection]
    let onAdd: (String, String) -> Void
    let onCancel: () -> Void
    
    @State private var selectedSection: String = "General"
    @State private var comment: String = ""
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Section") {
                    Picker("Select Section", selection: $selectedSection) {
                        Text("General").tag("General")
                        ForEach(sections) { section in
                            Text(section.title).tag(section.title)
                        }
                    }
                }
                
                Section("Comment") {
                    TextEditor(text: $comment)
                        .frame(minHeight: 100)
                }
                
                Section {
                    Text("Comments help track review feedback and required changes.")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                }
            }
            .navigationTitle("Add Comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") { onAdd(selectedSection, comment) }
                        .fontWeight(.semibold)
                        .disabled(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct ApprovalConfirmationSheet: View {
    let documentTitle: String
    let editCount: Int
    @Binding var notes: String
    let onApprove: () -> Void
    let onCancel: () -> Void
    
    @State private var confirmationChecked = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6) }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    ZStack {
                        Circle().fill(Color.green.opacity(0.15)).frame(width: 80, height: 80)
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 36)).foregroundColor(.green)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Approve Document").font(.system(size: 20, weight: .bold)).foregroundColor(textPrimary)
                        Text(documentTitle).font(.system(size: 14)).foregroundColor(textSecondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        summaryRow(label: "Edits Made", value: "\(editCount)")
                        summaryRow(label: "Status", value: "Ready for Finalization")
                        summaryRow(label: "Next Step", value: "Phase 10 - Case Finalization")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Approval Notes (Optional)").font(.system(size: 13, weight: .medium)).foregroundColor(textSecondary)
                        TextEditor(text: $notes).frame(height: 80).padding(8).background(Color.gray.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    Button { confirmationChecked.toggle() } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: confirmationChecked ? "checkmark.square.fill" : "square").font(.system(size: 20)).foregroundColor(confirmationChecked ? .green : .gray)
                            Text("I have reviewed this document and confirm it is ready for finalization.").font(.system(size: 13)).foregroundColor(textPrimary).multilineTextAlignment(.leading)
                        }
                    }
                    
                    Button { onApprove() } label: {
                        Text("Approve & Continue").font(.system(size: 15, weight: .semibold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14).background(confirmationChecked ? Color.green : Color.gray).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!confirmationChecked)
                }
                .padding()
            }
            .navigationTitle("Confirm Approval")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { onCancel() } }
            }
        }
    }
    
    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(textSecondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium)).foregroundColor(textPrimary)
        }
    }
}

struct RejectDocumentSheet: View {
    @Binding var reason: String
    let onReject: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6) }
    
    private let commonReasons = ["Inaccurate information", "Missing policy references", "Inappropriate tone", "Requires HR consultation", "Additional evidence needed"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    ZStack {
                        Circle().fill(Color.red.opacity(0.15)).frame(width: 80, height: 80)
                        Image(systemName: "xmark.seal.fill").font(.system(size: 36)).foregroundColor(.red)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Reject Document").font(.system(size: 20, weight: .bold)).foregroundColor(textPrimary)
                        Text("This will return the document for regeneration").font(.system(size: 14)).foregroundColor(textSecondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Common Reasons").font(.system(size: 13, weight: .medium)).foregroundColor(textSecondary)
                        EditorFlowLayout(spacing: 8) {
                            ForEach(commonReasons, id: \.self) { commonReason in
                                Button {
                                    reason = reason.isEmpty ? commonReason : reason + ", " + commonReason
                                } label: {
                                    Text(commonReason).font(.system(size: 12)).foregroundColor(.red).padding(.horizontal, 10).padding(.vertical, 6).background(Color.red.opacity(0.1)).clipShape(Capsule())
                                }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rejection Reason").font(.system(size: 13, weight: .medium)).foregroundColor(textSecondary)
                        TextEditor(text: $reason).frame(height: 120).padding(8).background(Color.gray.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    Button { onReject() } label: {
                        Text("Reject Document").font(.system(size: 15, weight: .semibold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14).background(reason.isEmpty ? Color.gray : Color.red).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .navigationTitle("Reject")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { onCancel() } }
            }
        }
    }
}

struct EditorFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }
            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}
