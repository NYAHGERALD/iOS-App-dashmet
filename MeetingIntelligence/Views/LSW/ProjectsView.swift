//
//  ProjectsView.swift
//  MeetingIntelligence
//
//  Improvement Projects and Updates
//

import SwiftUI

struct ProjectsView: View {
    @StateObject private var lswService = LSWService.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var editingProjectId: String?
    @State private var editingProjectName: String = ""
    @State private var editingUpdateId: String?
    @State private var editingUpdateText: String = ""
    @State private var showDeleteProjectAlert = false
    @State private var deleteTargetProjectId: String?
    @State private var showDeleteUpdateAlert = false
    @State private var deleteTargetUpdateId: String?
    @State private var deleteTargetUpdateProjectId: String?
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6) }
    private var textTertiary: Color { colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4) }
    private var cardBackground: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.white }
    private var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08) }
    private var sectionHeader: Color { colorScheme == .dark ? Color.white.opacity(0.04) : Color(hex: "F9FAFB") }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    if lswService.isLoadingProjects {
                        loadingView
                    } else if lswService.projects.isEmpty {
                        emptyStateView
                    } else {
                        projectsList
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 100)
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
            await lswService.fetchProjects()
            lswService.connectProjectWebSocket()
        }
        .alert("Delete Project", isPresented: $showDeleteProjectAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let id = deleteTargetProjectId {
                    Task { await handleDeleteProject(id) }
                }
            }
        } message: {
            Text("This will permanently delete this project and all its updates.")
        }
        .alert("Delete Update", isPresented: $showDeleteUpdateAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let updateId = deleteTargetUpdateId, let projectId = deleteTargetUpdateProjectId {
                    Task { await handleDeleteUpdate(projectId: projectId, updateId: updateId) }
                }
            }
        } message: {
            Text("This update will be permanently deleted.")
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading projects...")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: "8B5CF6").opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 32))
                    .foregroundColor(Color(hex: "8B5CF6"))
            }
            
            Text("No Projects Yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Text("Tap the + button to add your first improvement project.")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    // MARK: - Projects List
    
    private var projectsList: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("#")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(textTertiary)
                    .frame(width: 28, alignment: .center)
                
                Text("PROJECT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(textTertiary)
                    .tracking(0.5)
                
                Spacer()
                
                Text("UPDATES")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(textTertiary)
                    .tracking(0.5)
                    .frame(width: 120, alignment: .center)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(sectionHeader)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Project rows
            ForEach(Array(lswService.projects.enumerated()), id: \.element.id) { index, project in
                projectCard(project: project, number: index + 1)
            }
        }
    }
    
    // MARK: - Project Card
    
    private func projectCard(project: LSWProject, number: Int) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                // Number column
                Text("\(number)")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(textTertiary)
                    .frame(width: 28, alignment: .center)
                    .padding(.top, 14)
                
                // Project name column
                projectNameColumn(project: project)
                
                // Divider
                Rectangle()
                    .fill(cardBorder)
                    .frame(width: 1)
                
                // Updates column
                updatesColumn(project: project)
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(cardBorder, lineWidth: 1)
        )
    }
    
    // MARK: - Project Name Column
    
    private func projectNameColumn(project: LSWProject) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if editingProjectId == project.id {
                // Editing mode
                HStack(spacing: 8) {
                    TextField("Project name", text: $editingProjectName)
                        .font(.system(size: 14, weight: project.fontBold == true ? .bold : .regular))
                        .foregroundColor(colorFromHex(project.fontColor))
                        .textFieldStyle(.plain)
                        .onSubmit { saveProjectName(project: project) }
                    
                    Button { saveProjectName(project: project) } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.green)
                    }
                }
                .padding(12)
            } else {
                // Display mode
                HStack(spacing: 8) {
                    Text(project.name.isEmpty ? "Untitled Project" : project.name)
                        .font(.system(size: 14, weight: project.fontBold == true ? .bold : .regular))
                        .italic(project.fontItalic == true)
                        .foregroundColor(project.name.isEmpty ? textTertiary : colorFromHex(project.fontColor))
                        .lineLimit(3)
                        .onTapGesture {
                            editingProjectId = project.id
                            editingProjectName = project.name
                        }
                    
                    Spacer()
                    
                    // Update count badge
                    Text("\(project.updates.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "8B5CF6"))
                        .clipShape(Capsule())
                    
                    // Delete button
                    Button {
                        deleteTargetProjectId = project.id
                        showDeleteProjectAlert = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.red.opacity(0.7))
                    }
                }
                .padding(12)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .background(cellBackground(hex: project.cellColor, intensity: project.cellColorIntensity))
    }
    
    // MARK: - Updates Column
    
    private func updatesColumn(project: LSWProject) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(project.updates.enumerated()), id: \.element.id) { uIndex, update in
                VStack(spacing: 0) {
                    if uIndex > 0 {
                        Divider()
                    }
                    updateRow(project: project, update: update, index: uIndex)
                }
            }
            
            // Add update button
            Divider()
            Button {
                Task { await handleAddUpdate(projectId: project.id) }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text("Add")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(Color(hex: "8B5CF6"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .frame(width: 160)
    }
    
    // MARK: - Update Row
    
    private func updateRow(project: LSWProject, update: LSWProjectUpdate, index: Int) -> some View {
        HStack(spacing: 6) {
            if editingUpdateId == update.id {
                TextField("Update text", text: $editingUpdateText)
                    .font(.system(size: 13))
                    .italic(update.fontItalic == true)
                    .foregroundColor(colorFromHex(update.fontColor))
                    .textFieldStyle(.plain)
                    .onSubmit { saveUpdateText(update: update) }
                
                Button { saveUpdateText(update: update) } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                }
            } else {
                Text(update.text.isEmpty ? "—" : update.text)
                    .font(.system(size: 13))
                    .italic(update.fontItalic == true)
                    .foregroundColor(update.text.isEmpty ? textTertiary : colorFromHex(update.fontColor))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture {
                        editingUpdateId = update.id
                        editingUpdateText = update.text
                    }
                
                // Delete button (only if project has > 1 update)
                if project.updates.count > 1 {
                    Button {
                        deleteTargetUpdateId = update.id
                        deleteTargetUpdateProjectId = project.id
                        showDeleteUpdateAlert = true
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.5))
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(cellBackground(hex: update.cellColor, intensity: update.cellColorIntensity))
    }
    
    // MARK: - Add Project Button
    
    private var addProjectButton: some View {
        Button {
            Task { await handleAddProject() }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(Color(hex: "8B5CF6"))
                .clipShape(Circle())
                .shadow(color: Color(hex: "8B5CF6").opacity(0.3), radius: 8, y: 4)
        }
    }
    
    // MARK: - Actions
    
    private func handleAddProject() async {
        if let created = await lswService.createProject(name: "") {
            await MainActor.run {
                // Only add locally if WS hasn't already added it
                if !lswService.projects.contains(where: { $0.id == created.id }) {
                    lswService.projects.append(created)
                }
                editingProjectId = created.id
                editingProjectName = ""
            }
        }
    }
    
    private func saveProjectName(project: LSWProject) {
        let trimmed = editingProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        editingProjectId = nil
        
        if trimmed.isEmpty {
            // Delete empty project
            Task {
                await MainActor.run { lswService.projects.removeAll { $0.id == project.id } }
                _ = await lswService.deleteProject(id: project.id)
            }
            return
        }
        
        if trimmed != project.name {
            // Optimistic update
            Task {
                await MainActor.run {
                    if let idx = lswService.projects.firstIndex(where: { $0.id == project.id }) {
                        let p = lswService.projects[idx]
                        lswService.projects[idx] = LSWProject(
                            id: p.id, name: trimmed, updates: p.updates,
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
                _ = await lswService.updateProject(id: project.id, data: ["name": trimmed])
            }
        }
    }
    
    private func saveUpdateText(update: LSWProjectUpdate) {
        let trimmed = editingUpdateText.trimmingCharacters(in: .whitespacesAndNewlines)
        editingUpdateId = nil
        
        if trimmed != update.text {
            // Optimistic update
            Task {
                await MainActor.run {
                    for (pIdx, project) in lswService.projects.enumerated() {
                        if let uIdx = project.updates.firstIndex(where: { $0.id == update.id }) {
                            var newUpdates = project.updates
                            newUpdates[uIdx] = LSWProjectUpdate(
                                id: update.id, text: trimmed,
                                fontColor: update.fontColor, fontItalic: update.fontItalic,
                                cellColor: update.cellColor, cellColorIntensity: update.cellColorIntensity,
                                sortOrder: update.sortOrder
                            )
                            let p = project
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
                            break
                        }
                    }
                }
                _ = await lswService.updateProjectUpdate(updateId: update.id, data: ["text": trimmed])
            }
        }
    }
    
    private func handleAddUpdate(projectId: String) async {
        if let created = await lswService.addProjectUpdate(projectId: projectId) {
            await MainActor.run {
                if let idx = lswService.projects.firstIndex(where: { $0.id == projectId }) {
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
                    editingUpdateId = created.id
                    editingUpdateText = ""
                }
            }
        }
    }
    
    private func handleDeleteProject(_ id: String) async {
        await MainActor.run { lswService.projects.removeAll { $0.id == id } }
        _ = await lswService.deleteProject(id: id)
    }
    
    private func handleDeleteUpdate(projectId: String, updateId: String) async {
        await MainActor.run {
            if let idx = lswService.projects.firstIndex(where: { $0.id == projectId }) {
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
