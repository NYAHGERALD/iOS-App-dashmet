//
//  DocumentSectionEditorSheet.swift
//  MeetingIntelligence
//
//  Phase 9: Document Section Editor
//  Inline editing for individual document sections
//

import SwiftUI

struct DocumentSectionEditorSheet: View {
    let section: DocumentSection
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    @State private var editedContent: String
    @State private var showAISuggestions = false
    @State private var aiSuggestions: [String] = []
    @State private var isLoadingSuggestions = false
    @State private var wordCount: Int = 0
    @State private var characterCount: Int = 0
    
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
                    // Section header
                    sectionHeader
                    
                    // Editor
                    ScrollView {
                        VStack(spacing: 16) {
                            // Text editor
                            textEditorSection
                            
                            // Stats bar
                            statsBar
                            
                            // AI Suggestions
                            if showAISuggestions {
                                aiSuggestionsSection
                            }
                            
                            // Formatting tips
                            formattingTips
                        }
                        .padding()
                    }
                    
                    // Bottom toolbar
                    bottomToolbar
                }
            }
            .navigationTitle("Edit Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(editedContent)
                    }
                    .fontWeight(.semibold)
                    .disabled(editedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: editedContent) { _, newValue in
                updateCounts(newValue)
            }
            .onAppear {
                updateCounts(editedContent)
            }
        }
    }
    
    // MARK: - Section Header
    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(section.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(textPrimary)
            
            if section.hasChanges {
                HStack(spacing: 4) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    Text("Modified")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
    }
    
    // MARK: - Text Editor Section
    private var textEditorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Original content reference
            DisclosureGroup {
                Text(section.content)
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 12))
                    Text("Original Content")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(textSecondary)
            }
            
            // Editor
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
    
    // MARK: - Stats Bar
    private var statsBar: some View {
        HStack(spacing: 16) {
            statItem(label: "Words", value: "\(wordCount)")
            Divider().frame(height: 20)
            statItem(label: "Characters", value: "\(characterCount)")
            Divider().frame(height: 20)
            statItem(label: "Changed", value: hasChanges ? "Yes" : "No", color: hasChanges ? .orange : .green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func statItem(label: String, value: String, color: Color = .blue) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(textSecondary)
        }
    }
    
    private var hasChanges: Bool {
        editedContent != section.content
    }
    
    // MARK: - AI Suggestions Section
    private var aiSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI Suggestions")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Spacer()
                
                if isLoadingSuggestions {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if aiSuggestions.isEmpty && !isLoadingSuggestions {
                Button {
                    loadAISuggestions()
                } label: {
                    Text("Get AI suggestions for improvement")
                        .font(.system(size: 13))
                        .foregroundColor(.purple)
                }
            } else {
                ForEach(aiSuggestions, id: \.self) { suggestion in
                    suggestionCard(suggestion)
                }
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func suggestionCard(_ suggestion: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14))
                .foregroundColor(.purple)
            
            Text(suggestion)
                .font(.system(size: 13))
                .foregroundColor(textPrimary)
            
            Spacer()
            
            Button {
                applySuggestion(suggestion)
            } label: {
                Text("Apply")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.purple)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Formatting Tips
    private var formattingTips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Formatting Tips")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(textSecondary)
            
            VStack(alignment: .leading, spacing: 6) {
                tipRow(icon: "text.justify", tip: "Use clear, concise language")
                tipRow(icon: "list.bullet", tip: "Break long paragraphs into bullet points")
                tipRow(icon: "checkmark.circle", tip: "Avoid subjective or emotional language")
                tipRow(icon: "doc.text", tip: "Reference specific policies when applicable")
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func tipRow(icon: String, tip: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(tip)
                .font(.system(size: 12))
                .foregroundColor(textSecondary)
        }
    }
    
    // MARK: - Bottom Toolbar
    private var bottomToolbar: some View {
        HStack(spacing: 16) {
            // Undo button
            Button {
                editedContent = section.content
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 18))
                    Text("Reset")
                        .font(.system(size: 10))
                }
                .foregroundColor(hasChanges ? .blue : .gray)
            }
            .disabled(!hasChanges)
            
            Divider().frame(height: 30)
            
            // AI Suggestions toggle
            Button {
                withAnimation {
                    showAISuggestions.toggle()
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                    Text("AI Help")
                        .font(.system(size: 10))
                }
                .foregroundColor(showAISuggestions ? .purple : .gray)
            }
            
            Divider().frame(height: 30)
            
            // Tone check
            Button {
                // Check tone
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "waveform")
                        .font(.system(size: 18))
                    Text("Tone")
                        .font(.system(size: 10))
                }
                .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding()
        .background(cardBackground)
    }
    
    // MARK: - Helper Methods
    
    private func updateCounts(_ text: String) {
        characterCount = text.count
        wordCount = text.split(separator: " ").count
    }
    
    private func loadAISuggestions() {
        isLoadingSuggestions = true
        
        // Simulate AI suggestions (would call API in production)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            aiSuggestions = [
                "Consider using more specific language to describe the behavior.",
                "Add a reference to the relevant policy section for clarity.",
                "Rephrase to focus on observable actions rather than intentions."
            ]
            isLoadingSuggestions = false
        }
    }
    
    private func applySuggestion(_ suggestion: String) {
        // In production, this would intelligently apply the suggestion
        // For now, just append a note
        editedContent += "\n\n[Applied suggestion: \(suggestion)]"
    }
}

// MARK: - Add Comment Sheet
struct AddCommentSheet: View {
    let sections: [DocumentSection]
    let onAdd: (String, String) -> Void
    let onCancel: () -> Void
    
    @State private var selectedSection: String = ""
    @State private var comment: String = ""
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
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
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onAdd(selectedSection.isEmpty ? "General" : selectedSection, comment)
                    }
                    .fontWeight(.semibold)
                    .disabled(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if selectedSection.isEmpty {
                    selectedSection = "General"
                }
            }
        }
    }
}

// MARK: - Approval Confirmation Sheet
struct ApprovalConfirmationSheet: View {
    let documentTitle: String
    let editCount: Int
    @Binding var notes: String
    let onApprove: () -> Void
    let onCancel: () -> Void
    
    @State private var confirmationChecked = false
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Success icon
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.green)
                    }
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("Approve Document")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(textPrimary)
                        
                        Text(documentTitle)
                            .font(.system(size: 14))
                            .foregroundColor(textSecondary)
                    }
                    
                    // Summary
                    VStack(alignment: .leading, spacing: 12) {
                        summaryRow(label: "Edits Made", value: "\(editCount)")
                        summaryRow(label: "Status", value: "Ready for Finalization")
                        summaryRow(label: "Next Step", value: "Phase 10 - Case Finalization")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Approval Notes (Optional)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(textSecondary)
                        
                        TextEditor(text: $notes)
                            .frame(height: 80)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // Confirmation checkbox
                    Button {
                        confirmationChecked.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: confirmationChecked ? "checkmark.square.fill" : "square")
                                .font(.system(size: 20))
                                .foregroundColor(confirmationChecked ? .green : .gray)
                            
                            Text("I have reviewed this document and confirm it is ready for finalization.")
                                .font(.system(size: 13))
                                .foregroundColor(textPrimary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    
                    // Approve button
                    Button {
                        onApprove()
                    } label: {
                        Text("Approve & Continue")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(confirmationChecked ? Color.green : Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!confirmationChecked)
                }
                .padding()
            }
            .navigationTitle("Confirm Approval")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
    
    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(textPrimary)
        }
    }
}

// MARK: - Reject Document Sheet
struct RejectDocumentSheet: View {
    @Binding var reason: String
    let onReject: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private let commonReasons = [
        "Inaccurate information",
        "Missing policy references",
        "Inappropriate tone",
        "Requires HR consultation",
        "Additional evidence needed"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Warning icon
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "xmark.seal.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.red)
                    }
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("Reject Document")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(textPrimary)
                        
                        Text("This will return the document for regeneration")
                            .font(.system(size: 14))
                            .foregroundColor(textSecondary)
                    }
                    
                    // Common reasons
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Common Reasons")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(textSecondary)
                        
                        EditorFlowLayout(spacing: 8) {
                            ForEach(commonReasons, id: \.self) { commonReason in
                                Button {
                                    if reason.isEmpty {
                                        reason = commonReason
                                    } else {
                                        reason += ", \(commonReason)"
                                    }
                                } label: {
                                    Text(commonReason)
                                        .font(.system(size: 12))
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.red.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    
                    // Reason text
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rejection Reason")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(textSecondary)
                        
                        TextEditor(text: $reason)
                            .frame(height: 120)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // Reject button
                    Button {
                        onReject()
                    } label: {
                        Text("Reject Document")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(reason.isEmpty ? Color.gray : Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .navigationTitle("Reject")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}

// MARK: - Flow Layout
struct EditorFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
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
