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
    let caseId: String  // Backend database ID
    let initialEdits: [DocumentEdit]  // Session edits passed in
    let onDismiss: () -> Void
    
    @State private var edits: [DocumentEdit] = []
    @State private var selectedEdit: DocumentEdit?
    @State private var showDiffView = false
    @State private var isLoading = false
    @State private var loadError: String?
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Convenience initializer for backwards compatibility
    init(edits: [DocumentEdit], onDismiss: @escaping () -> Void) {
        self.caseId = "" // Empty - won't load from DB
        self.initialEdits = edits
        self.onDismiss = onDismiss
    }
    
    // Full initializer with caseId for database loading
    init(caseId: String, sessionEdits: [DocumentEdit] = [], onDismiss: @escaping () -> Void) {
        self.caseId = caseId
        self.initialEdits = sessionEdits
        self.onDismiss = onDismiss
    }
    
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
                
                if isLoading {
                    ProgressView("Loading edit history...")
                } else if let error = loadError {
                    errorView(error)
                } else if edits.isEmpty {
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
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isLoading {
                        Button(action: loadEditsFromDatabase) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
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
            .onAppear {
                // Start with session edits, then load full history from database
                edits = initialEdits
                if !caseId.isEmpty {
                    loadEditsFromDatabase()
                }
            }
        }
    }
    
    // MARK: - Load Edits from Database
    private func loadEditsFromDatabase() {
        guard !caseId.isEmpty else {
            // No backend ID - just use session edits
            edits = initialEdits
            return
        }
        
        isLoading = true
        loadError = nil
        
        Task {
            do {
                let dbEdits = try await EditTrackingService.shared.getEdits(for: caseId)
                await MainActor.run {
                    // Merge database edits with any session edits not yet saved
                    let dbEditIds = Set(dbEdits.map { $0.id })
                    let unsavedSessionEdits = initialEdits.filter { !dbEditIds.contains($0.id) }
                    self.edits = dbEdits + unsavedSessionEdits
                    self.edits.sort { $0.editedAt > $1.editedAt }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    // Fall back to session edits on error
                    self.edits = initialEdits
                    self.loadError = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Error View
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("Failed to load edit history")
                .font(.headline)
            
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                loadEditsFromDatabase()
            }
            .buttonStyle(.bordered)
        }
        .padding()
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
    
    private let baseURL = "https://dashmet-rca-api.onrender.com/api/conflict-cases"
    
    @Published var currentSessionEdits: [DocumentEdit] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private init() {}
    
    // MARK: - Track Edit (Save to Database)
    func trackEdit(
        caseId: String,
        sectionId: String,
        sectionTitle: String,
        originalContent: String,
        newContent: String,
        editedBy: String
    ) async throws -> DocumentEdit {
        guard let url = URL(string: "\(baseURL)/\(caseId)/document-edits") else {
            throw EditTrackingError.invalidURL
        }
        
        let requestBody: [String: Any] = [
            "sectionId": sectionId,
            "sectionTitle": sectionTitle,
            "originalContent": originalContent,
            "newContent": newContent,
            "editedBy": editedBy
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EditTrackingError.invalidResponse
        }
        
        guard httpResponse.statusCode == 201 else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                throw EditTrackingError.apiError(errorMessage)
            }
            throw EditTrackingError.apiError("Failed to save edit: HTTP \(httpResponse.statusCode)")
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any] else {
            throw EditTrackingError.parsingError
        }
        
        let edit = parseDocumentEdit(from: dataObj)
        
        await MainActor.run {
            self.currentSessionEdits.append(edit)
        }
        
        return edit
    }
    
    // MARK: - Get Edits for Case (From Database)
    func getEdits(for caseId: String) async throws -> [DocumentEdit] {
        guard let url = URL(string: "\(baseURL)/\(caseId)/document-edits") else {
            throw EditTrackingError.invalidURL
        }
        
        await MainActor.run { self.isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EditTrackingError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw EditTrackingError.apiError("Failed to fetch edits: HTTP \(httpResponse.statusCode)")
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let editsData = json["data"] as? [[String: Any]] else {
            throw EditTrackingError.parsingError
        }
        
        return editsData.map { parseDocumentEdit(from: $0) }
    }
    
    // MARK: - Synchronous wrapper for backwards compatibility
    func getEdits(for caseId: String) -> [DocumentEdit] {
        // Return cached session edits for current session
        // Full history should be fetched async
        return currentSessionEdits.filter { _ in true } // Placeholder - use async version
    }
    
    // MARK: - Clear Session
    func clearSession() {
        currentSessionEdits = []
    }
    
    // MARK: - Undo Last Edit (Delete from Database)
    func undoLastEdit(for caseId: String) async throws -> DocumentEdit? {
        let edits = try await getEdits(for: caseId)
        guard let lastEdit = edits.first else { return nil } // edits are ordered desc
        
        guard let url = URL(string: "\(baseURL)/\(caseId)/document-edits/\(lastEdit.id.uuidString)") else {
            throw EditTrackingError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw EditTrackingError.apiError("Failed to undo edit")
        }
        
        await MainActor.run {
            if let index = self.currentSessionEdits.firstIndex(where: { $0.id == lastEdit.id }) {
                self.currentSessionEdits.remove(at: index)
            }
        }
        
        return lastEdit
    }
    
    // MARK: - Export Edit History
    func exportEditHistory(for caseId: String) async throws -> Data {
        let edits = try await getEdits(for: caseId)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        return try encoder.encode(edits)
    }
    
    // MARK: - Calculate Total Changes
    func calculateTotalChanges(for edits: [DocumentEdit]) -> (added: Int, removed: Int) {
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
    
    // MARK: - Parse Document Edit from JSON
    private func parseDocumentEdit(from data: [String: Any]) -> DocumentEdit {
        let id = UUID(uuidString: data["id"] as? String ?? "") ?? UUID()
        let sectionId = data["sectionId"] as? String ?? ""
        let sectionTitle = data["sectionTitle"] as? String ?? ""
        let originalContent = data["originalContent"] as? String ?? ""
        let newContent = data["newContent"] as? String ?? ""
        let editedBy = data["editedBy"] as? String ?? ""
        
        var editedAt = Date()
        if let createdAtString = data["createdAt"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            editedAt = formatter.date(from: createdAtString) ?? Date()
        }
        
        return DocumentEdit(
            id: id,
            sectionId: sectionId,
            sectionTitle: sectionTitle,
            originalContent: originalContent,
            newContent: newContent,
            editedBy: editedBy,
            editedAt: editedAt
        )
    }
}

// MARK: - Edit Tracking Errors
enum EditTrackingError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .apiError(let message): return message
        case .parsingError: return "Failed to parse response"
        }
    }
}
