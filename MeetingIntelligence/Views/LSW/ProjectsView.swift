//
//  ProjectsView.swift
//  MeetingIntelligence
//
//  Improvement Projects and Updates
//

import SwiftUI

// MARK: - Projects List (Main Screen)

struct ProjectsView: View {
    @StateObject private var lswService = LSWService.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedProject: LSWProject?
    @State private var showNewProjectAlert = false
    @State private var newProjectName = ""
    @State private var showDeleteConfirm = false
    @State private var deleteTargetId: String?
    @State private var currentWeekOffset = 0
    
    private let accentColor = Color(hex: "8B5CF6")
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6) }
    private var textTertiary: Color { colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4) }
    private var cardBackground: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.white }
    private var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08) }
    
    private var referenceDate: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: currentWeekOffset, to: Date())!
    }
    private var currentWeekNumber: Int { lswService.orgWeekNumber(for: referenceDate) }
    private var currentYear: Int { lswService.orgYear(for: referenceDate) }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                WeekNavigatorView(currentWeekOffset: $currentWeekOffset, lswService: lswService)
                Divider()
                
                if lswService.isLoadingProjects {
                    Spacer()
                    loadingView
                    Spacer()
                } else if lswService.projects.isEmpty {
                    Spacer()
                    emptyStateView
                    Spacer()
                } else {
                    projectsList
                }
            }
            
            // Floating add button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    addProjectButton
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Projects")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await lswService.fetchProjects(weekNumber: currentWeekNumber, year: currentYear)
            lswService.connectProjectWebSocket()
        }
        .onChange(of: currentWeekOffset) { _, _ in
            Task { await lswService.fetchProjects(weekNumber: currentWeekNumber, year: currentYear) }
        }
        .alert("New Project", isPresented: $showNewProjectAlert) {
            TextField("Project name", text: $newProjectName)
            Button("Cancel", role: .cancel) { newProjectName = "" }
            Button("Create") {
                let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                newProjectName = ""
                guard !name.isEmpty else { return }
                Task { await handleAddProject(name: name) }
            }
        } message: {
            Text("Enter a name for your new project.")
        }
        .alert("Delete Project", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let id = deleteTargetId {
                    Task { await handleDeleteProject(id) }
                }
            }
        } message: {
            Text("This will permanently delete this project and all its updates.")
        }
        .sheet(item: $selectedProject) { project in
            ProjectUpdatesSheet(project: project)
        }
    }
    
    // MARK: - Loading
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading projects...")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 32))
                    .foregroundColor(accentColor)
            }
            
            Text("No Projects Yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Text("Tap the + button to add your first improvement project.")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Projects List
    
    private var projectsList: some View {
        List {
            ForEach(Array(lswService.projects.enumerated()), id: \.element.id) { index, project in
                Button {
                    selectedProject = project
                } label: {
                    projectRowContent(project: project, number: index + 1)
                }
                .buttonStyle(.plain)
                .listRowBackground(cellBackground(hex: project.cellColor, intensity: project.cellColorIntensity).opacity(1) == .clear.opacity(1) ? cardBackground : cellBackground(hex: project.cellColor, intensity: project.cellColorIntensity))
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await handleDeleteProject(project.id) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button {
                        selectedProject = project
                    } label: {
                        Label("View Updates", systemImage: "doc.text")
                    }
                    Button(role: .destructive) {
                        deleteTargetId = project.id
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Project", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Project Row Content
    
    private func projectRowContent(project: LSWProject, number: Int) -> some View {
        HStack(spacing: 12) {
            // Number badge
            Text("\(number)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            
            // Project info
            VStack(alignment: .leading, spacing: 3) {
                Text(project.name.isEmpty ? "Untitled Project" : project.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(project.name.isEmpty ? textTertiary : textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                    Text("\(project.updates.count) update\(project.updates.count == 1 ? "" : "s")")
                        .font(.system(size: 12))
                }
                .foregroundColor(textTertiary)
            }
            
            Spacer()
            
            // Update count badge
            Text("\(project.updates.count)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(accentColor.opacity(0.8))
                .clipShape(Circle())
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(textTertiary.opacity(0.5))
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - Add Project Button
    
    private var addProjectButton: some View {
        Button {
            showNewProjectAlert = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(accentColor)
                .clipShape(Circle())
                .shadow(color: accentColor.opacity(0.3), radius: 8, y: 4)
        }
    }
    
    // MARK: - Actions
    
    private func handleAddProject(name: String) async {
        if let created = await lswService.createProject(name: name, weekNumber: currentWeekNumber, year: currentYear) {
            await MainActor.run {
                if !lswService.projects.contains(where: { $0.id == created.id }) {
                    lswService.projects.append(created)
                }
                // Auto-update the name if it was created empty on the backend
                if created.name != name {
                    Task { _ = await lswService.updateProject(id: created.id, data: ["name": name]) }
                }
            }
        }
    }
    
    private func handleDeleteProject(_ id: String) async {
        await MainActor.run {
            lswService.projects.removeAll { $0.id == id }
            if selectedProject?.id == id { selectedProject = nil }
        }
        _ = await lswService.deleteProject(id: id)
    }
    
    // MARK: - Helpers
    
    private func cellBackground(hex: String?, intensity: Int?) -> Color {
        guard let hex = hex, !hex.isEmpty else { return .clear }
        let alpha = Double(intensity ?? 20) / 100.0
        return Color(hex: String(hex.dropFirst())).opacity(alpha)
    }
}

// MARK: - Project Updates Sheet

struct ProjectUpdatesSheet: View {
    let project: LSWProject
    @StateObject private var lswService = LSWService.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var newUpdateText = ""
    @State private var editingUpdateId: String?
    @State private var editingUpdateText = ""
    @State private var showDeleteConfirm = false
    @State private var deleteTargetUpdateId: String?
    @FocusState private var isNewUpdateFocused: Bool
    
    private let accentColor = Color(hex: "8B5CF6")
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6) }
    private var textTertiary: Color { colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4) }
    private var cardBackground: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.white }
    private var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08) }
    
    // Live project from service (reflects WebSocket updates)
    private var liveProject: LSWProject {
        lswService.projects.first { $0.id == project.id } ?? project
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Updates list
                    if liveProject.updates.isEmpty {
                        emptyUpdatesView
                    } else {
                        updatesList
                    }
                    
                    // Add update input bar
                    addUpdateBar
                }
            }
            .navigationTitle(liveProject.name.isEmpty ? "Untitled Project" : liveProject.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
            .alert("Delete Update", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let id = deleteTargetUpdateId {
                        Task { await handleDeleteUpdate(id) }
                    }
                }
            } message: {
                Text("This update will be permanently deleted.")
            }
        }
    }
    
    // MARK: - Empty Updates
    
    private var emptyUpdatesView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "text.badge.plus")
                .font(.system(size: 36))
                .foregroundColor(textTertiary)
            Text("No updates yet")
                .font(.system(size: 15))
                .foregroundColor(textSecondary)
            Text("Add the first update below.")
                .font(.system(size: 13))
                .foregroundColor(textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Updates List
    
    private var updatesList: some View {
        List {
            ForEach(Array(liveProject.updates.enumerated()), id: \.element.id) { index, update in
                updateRow(update: update, number: index + 1)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(cellBackground(hex: update.cellColor, intensity: update.cellColorIntensity).opacity(1) == .clear.opacity(1) ? cardBackground : cellBackground(hex: update.cellColor, intensity: update.cellColorIntensity))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await handleDeleteUpdate(update.id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button {
                            editingUpdateId = update.id
                            editingUpdateText = update.text
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deleteTargetUpdateId = update.id
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Update Row
    
    private func updateRow(update: LSWProjectUpdate, number: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Number
            Text("\(number)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(accentColor)
                .frame(width: 22, height: 22)
                .background(accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            
            if editingUpdateId == update.id {
                // Editing
                HStack(spacing: 8) {
                    TextField("Update text", text: $editingUpdateText, axis: .vertical)
                        .font(.system(size: 14))
                        .lineLimit(1...6)
                        .textFieldStyle(.plain)
                    
                    Button {
                        saveUpdateText(update: update)
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                    }
                }
                .padding(10)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(accentColor.opacity(0.3), lineWidth: 1.5)
                )
            } else {
                // Display
                Text(update.text.isEmpty ? "Empty update" : update.text)
                    .font(.system(size: 14))
                    .italic(update.fontItalic == true)
                    .foregroundColor(update.text.isEmpty ? textTertiary : colorFromHex(update.fontColor))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture {
                        editingUpdateId = update.id
                        editingUpdateText = update.text
                    }
            }
        }
    }
    
    // MARK: - Add Update Bar
    
    private var addUpdateBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                TextField("Add an update...", text: $newUpdateText, axis: .vertical)
                    .font(.system(size: 14))
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(cardBorder, lineWidth: 1)
                    )
                    .focused($isNewUpdateFocused)
                
                Button {
                    let text = newUpdateText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    newUpdateText = ""
                    Task { await handleAddUpdate(text: text) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(newUpdateText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? textTertiary : accentColor)
                }
                .disabled(newUpdateText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppColors.background)
        }
    }
    
    // MARK: - Actions
    
    private func handleAddUpdate(text: String) async {
        if let created = await lswService.addProjectUpdate(projectId: project.id, text: text) {
            await MainActor.run {
                if let idx = lswService.projects.firstIndex(where: { $0.id == project.id }) {
                    let p = lswService.projects[idx]
                    var newUpdates = p.updates
                    if !newUpdates.contains(where: { $0.id == created.id }) {
                        newUpdates.append(created)
                    }
                    lswService.projects[idx] = LSWProject(
                        id: p.id, name: p.name, updates: newUpdates,
                        fontColor: p.fontColor, fontFamily: p.fontFamily,
                        fontBold: p.fontBold, fontItalic: p.fontItalic,
                        cellColor: p.cellColor, cellColorIntensity: p.cellColorIntensity,
                        defaultUpdateFontColor: p.defaultUpdateFontColor,
                        defaultUpdateFontItalic: p.defaultUpdateFontItalic,
                        defaultUpdateCellColor: p.defaultUpdateCellColor,
                        defaultUpdateCellColorIntensity: p.defaultUpdateCellColorIntensity,
                        sortOrder: p.sortOrder, isActive: p.isActive
                    )
                }
            }
        }
    }
    
    private func saveUpdateText(update: LSWProjectUpdate) {
        let trimmed = editingUpdateText.trimmingCharacters(in: .whitespacesAndNewlines)
        editingUpdateId = nil
        guard trimmed != update.text else { return }
        
        Task {
            await MainActor.run {
                if let pIdx = lswService.projects.firstIndex(where: { $0.id == project.id }),
                   let uIdx = lswService.projects[pIdx].updates.firstIndex(where: { $0.id == update.id }) {
                    var newUpdates = lswService.projects[pIdx].updates
                    newUpdates[uIdx] = LSWProjectUpdate(
                        id: update.id, text: trimmed,
                        fontColor: update.fontColor, fontItalic: update.fontItalic,
                        cellColor: update.cellColor, cellColorIntensity: update.cellColorIntensity,
                        sortOrder: update.sortOrder
                    )
                    let p = lswService.projects[pIdx]
                    lswService.projects[pIdx] = LSWProject(
                        id: p.id, name: p.name, updates: newUpdates,
                        fontColor: p.fontColor, fontFamily: p.fontFamily,
                        fontBold: p.fontBold, fontItalic: p.fontItalic,
                        cellColor: p.cellColor, cellColorIntensity: p.cellColorIntensity,
                        defaultUpdateFontColor: p.defaultUpdateFontColor,
                        defaultUpdateFontItalic: p.defaultUpdateFontItalic,
                        defaultUpdateCellColor: p.defaultUpdateCellColor,
                        defaultUpdateCellColorIntensity: p.defaultUpdateCellColorIntensity,
                        sortOrder: p.sortOrder, isActive: p.isActive
                    )
                }
            }
            _ = await lswService.updateProjectUpdate(updateId: update.id, data: ["text": trimmed])
        }
    }
    
    private func handleDeleteUpdate(_ updateId: String) async {
        await MainActor.run {
            if let idx = lswService.projects.firstIndex(where: { $0.id == project.id }) {
                let p = lswService.projects[idx]
                let newUpdates = p.updates.filter { $0.id != updateId }
                lswService.projects[idx] = LSWProject(
                    id: p.id, name: p.name, updates: newUpdates,
                    fontColor: p.fontColor, fontFamily: p.fontFamily,
                    fontBold: p.fontBold, fontItalic: p.fontItalic,
                    cellColor: p.cellColor, cellColorIntensity: p.cellColorIntensity,
                    defaultUpdateFontColor: p.defaultUpdateFontColor,
                    defaultUpdateFontItalic: p.defaultUpdateFontItalic,
                    defaultUpdateCellColor: p.defaultUpdateCellColor,
                    defaultUpdateCellColorIntensity: p.defaultUpdateCellColorIntensity,
                    sortOrder: p.sortOrder, isActive: p.isActive
                )
            }
        }
        _ = await lswService.deleteProjectUpdate(updateId: updateId)
    }
    
    // MARK: - Helpers
    
    private func colorFromHex(_ hex: String?) -> Color {
        guard let hex = hex, !hex.isEmpty else { return textPrimary }
        return Color(hex: String(hex.dropFirst()))
    }
    
    private func cellBackground(hex: String?, intensity: Int?) -> Color {
        guard let hex = hex, !hex.isEmpty else { return .clear }
        let alpha = Double(intensity ?? 20) / 100.0
        return Color(hex: String(hex.dropFirst())).opacity(alpha)
    }
}
