//
//  EditHistoryView.swift
//  MeetingIntelligence
//
//  Phase 9: Edit History View
//  Visual diff display showing all changes made during review
//

import SwiftUI
import Combine

struct EditHistoryView: View {
    let edits: [DocumentEdit]
    let onDismiss: () -> Void
    
    @State private var selectedEdit: DocumentEdit?
    @State private var showDiffView = false
    
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
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if edits.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Summary card
                            summaryCard
                            
                            // Timeline
                            editTimeline
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Edit History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
            .sheet(isPresented: $showDiffView) {
                if let edit = selectedEdit {
                    DiffDetailView(edit: edit, onDismiss: { showDiffView = false })
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.green)
            }
            
            Text("No Edits Made")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Text("The document has not been modified during this review session.")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Summary Card
    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(edits.count)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.blue)
                    Text("Total Edits")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(uniqueSectionsEdited)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.orange)
                    Text("Sections Modified")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                }
            }
            
            Divider()
            
            // Most recent edit
            if let latestEdit = edits.last {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(textSecondary)
                    
                    Text("Last edit: \(latestEdit.editedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var uniqueSectionsEdited: Int {
        Set(edits.map { $0.sectionId }).count
    }
    
    // MARK: - Edit Timeline
    private var editTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Edit Timeline")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(textPrimary)
                .padding(.bottom, 16)
            
            ForEach(Array(edits.enumerated()), id: \.element.id) { index, edit in
                editTimelineItem(edit: edit, isLast: index == edits.count - 1)
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func editTimelineItem(edit: DocumentEdit, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline line and dot
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 12, height: 12)
                
                if !isLast {
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 2)
                        .frame(minHeight: 60)
                }
            }
            
            // Edit content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(edit.sectionTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    Spacer()
                    
                    Text(edit.editedAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundColor(textSecondary)
                }
                
                // Change preview
                VStack(alignment: .leading, spacing: 4) {
                    changePreview(label: "Before", text: edit.originalContent, color: .red)
                    changePreview(label: "After", text: edit.newContent, color: .green)
                }
                
                // View diff button
                Button {
                    selectedEdit = edit
                    showDiffView = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 10))
                        Text("View Diff")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.blue)
                }
                .padding(.top, 4)
            }
            .padding(.bottom, isLast ? 0 : 16)
        }
    }
    
    private func changePreview(label: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(color)
                .frame(width: 40, alignment: .leading)
            
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(textSecondary)
                .lineLimit(2)
        }
    }
}

// MARK: - Diff Detail View
struct DiffDetailView: View {
    let edit: DocumentEdit
    let onDismiss: () -> Void
    
    @State private var viewMode: DiffViewMode = .sideBySide
    
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
    
    enum DiffViewMode: String, CaseIterable {
        case sideBySide = "Side by Side"
        case unified = "Unified"
        case inline = "Inline"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Section info
                        sectionInfoCard
                        
                        // View mode picker
                        Picker("View Mode", selection: $viewMode) {
                            ForEach(DiffViewMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        // Diff content
                        switch viewMode {
                        case .sideBySide:
                            sideBySideView
                        case .unified:
                            unifiedView
                        case .inline:
                            inlineView
                        }
                        
                        // Stats
                        diffStats
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Section Info Card
    private var sectionInfoCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(edit.sectionTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Text("Edited by \(edit.editedBy)")
                    .font(.system(size: 12))
                    .foregroundColor(textSecondary)
            }
            
            Spacer()
            
            Text(edit.editedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 12))
                .foregroundColor(textSecondary)
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Side by Side View
    private var sideBySideView: some View {
        HStack(alignment: .top, spacing: 12) {
            // Original
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Original")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                }
                
                Text(edit.originalContent)
                    .font(.system(size: 13))
                    .foregroundColor(textPrimary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(maxWidth: .infinity)
            
            // New
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Updated")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                }
                
                Text(edit.newContent)
                    .font(.system(size: 13))
                    .foregroundColor(textPrimary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Unified View
    private var unifiedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Removed lines
            VStack(alignment: .leading, spacing: 4) {
                ForEach(edit.originalContent.components(separatedBy: "\n"), id: \.self) { line in
                    if !line.isEmpty {
                        HStack(spacing: 8) {
                            Text("-")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.red)
                            Text(line)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                    }
                }
            }
            
            // Added lines
            VStack(alignment: .leading, spacing: 4) {
                ForEach(edit.newContent.components(separatedBy: "\n"), id: \.self) { line in
                    if !line.isEmpty {
                        HStack(spacing: 8) {
                            Text("+")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.green)
                            Text(line)
                                .font(.system(size: 13))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                    }
                }
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Inline View
    private var inlineView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Original:")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.red)
            
            Text(edit.originalContent)
                .font(.system(size: 13))
                .strikethrough(true, color: .red)
                .foregroundColor(.red.opacity(0.7))
            
            Divider()
                .padding(.vertical, 8)
            
            Text("Updated:")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.green)
            
            Text(edit.newContent)
                .font(.system(size: 13))
                .foregroundColor(.green)
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Diff Stats
    private var diffStats: some View {
        HStack(spacing: 24) {
            statItem(label: "Characters", before: edit.originalContent.count, after: edit.newContent.count)
            statItem(label: "Words", before: wordCount(edit.originalContent), after: wordCount(edit.newContent))
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func statItem(label: String, before: Int, after: Int) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(textSecondary)
            
            HStack(spacing: 8) {
                Text("\(before)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundColor(textSecondary)
                
                Text("\(after)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.green)
            }
            
            let diff = after - before
            Text(diff >= 0 ? "+\(diff)" : "\(diff)")
                .font(.system(size: 10))
                .foregroundColor(diff >= 0 ? .green : .red)
        }
    }
    
    private func wordCount(_ text: String) -> Int {
        text.split(separator: " ").count
    }
}

// MARK: - Edit Tracking Service
class EditTrackingService: ObservableObject {
    static let shared = EditTrackingService()
    
    @Published var currentSessionEdits: [DocumentEdit] = []
    @Published var allCaseEdits: [UUID: [DocumentEdit]] = [:] // caseId: edits
    
    private init() {}
    
    // MARK: - Track Edit
    func trackEdit(
        caseId: UUID,
        sectionId: String,
        sectionTitle: String,
        originalContent: String,
        newContent: String,
        editedBy: String
    ) {
        let edit = DocumentEdit(
            sectionId: sectionId,
            sectionTitle: sectionTitle,
            originalContent: originalContent,
            newContent: newContent,
            editedBy: editedBy
        )
        
        currentSessionEdits.append(edit)
        
        if allCaseEdits[caseId] == nil {
            allCaseEdits[caseId] = []
        }
        allCaseEdits[caseId]?.append(edit)
    }
    
    // MARK: - Get Edits for Case
    func getEdits(for caseId: UUID) -> [DocumentEdit] {
        return allCaseEdits[caseId] ?? []
    }
    
    // MARK: - Clear Session
    func clearSession() {
        currentSessionEdits = []
    }
    
    // MARK: - Undo Last Edit
    func undoLastEdit(for caseId: UUID) -> DocumentEdit? {
        guard var edits = allCaseEdits[caseId], !edits.isEmpty else { return nil }
        let removed = edits.removeLast()
        allCaseEdits[caseId] = edits
        
        if let sessionIndex = currentSessionEdits.firstIndex(where: { $0.id == removed.id }) {
            currentSessionEdits.remove(at: sessionIndex)
        }
        
        return removed
    }
    
    // MARK: - Export Edit History
    func exportEditHistory(for caseId: UUID) -> Data? {
        guard let edits = allCaseEdits[caseId] else { return nil }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        return try? encoder.encode(edits)
    }
    
    // MARK: - Calculate Total Changes
    func calculateTotalChanges(for caseId: UUID) -> (added: Int, removed: Int) {
        guard let edits = allCaseEdits[caseId] else { return (0, 0) }
        
        var added = 0
        var removed = 0
        
        for edit in edits {
            let originalWords = edit.originalContent.split(separator: " ").count
            let newWords = edit.newContent.split(separator: " ").count
            
            if newWords > originalWords {
                added += newWords - originalWords
            } else {
                removed += originalWords - newWords
            }
        }
        
        return (added, removed)
    }
}
