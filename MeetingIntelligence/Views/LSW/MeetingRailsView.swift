//
//  MeetingRailsView.swift
//  MeetingIntelligence
//
//  Level 1, 2 & 3 Meeting Rails - with completion toggle and WebSocket sync
//

import SwiftUI

// MARK: - Meeting Rails List (Main Screen)

struct MeetingRailsView: View {
    @StateObject private var lswService = LSWService.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedRail: LSWMeetingRail?
    @State private var showAddSheet = false
    @State private var currentWeekOffset = 0
    
    private let accentColor = Color(hex: "6366F1") // Indigo/Purple
    
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
                
                if lswService.isLoadingRails {
                    Spacer()
                    loadingView
                    Spacer()
                } else if lswService.meetingRails.isEmpty {
                    Spacer()
                    emptyStateView
                    Spacer()
                } else {
                    railsList
                }
            }
            
            // Floating add button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    addButton
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Meeting Rails")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            lswService.setActiveWeek(weekNumber: currentWeekNumber, year: currentYear)
            await lswService.fetchMeetingRails(weekNumber: currentWeekNumber, year: currentYear)
            lswService.connectRailWebSocket()
        }
        .onChange(of: currentWeekOffset) { _, _ in
            lswService.setActiveWeek(weekNumber: currentWeekNumber, year: currentYear)
            Task { await lswService.fetchMeetingRails(weekNumber: currentWeekNumber, year: currentYear) }
        }
        .sheet(isPresented: $showAddSheet) {
            RailEditSheet(rail: nil)
        }
        .sheet(item: $selectedRail) { rail in
            RailEditSheet(rail: rail)
        }
    }
    
    // MARK: - Loading
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading meeting rails...")
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
                Image(systemName: "person.3")
                    .font(.system(size: 32))
                    .foregroundColor(accentColor)
            }
            
            Text("No Meeting Rails Yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Text("Tap the + button to add your first meeting rail.")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Rails List
    
    private var railsList: some View {
        List {
            ForEach(lswService.meetingRails) { rail in
                Button {
                    selectedRail = rail
                } label: {
                    railCard(rail: rail)
                }
                .buttonStyle(.plain)
                .listRowBackground(cardBackground)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await handleDelete(rail.id) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        Task { await handleToggle(rail) }
                    } label: {
                        Label(rail.completed ? "Undo" : "Complete", systemImage: rail.completed ? "arrow.uturn.backward" : "checkmark")
                    }
                    .tint(accentColor)
                }
                .contextMenu {
                    Button {
                        Task { await handleToggle(rail) }
                    } label: {
                        Label(rail.completed ? "Mark Incomplete" : "Mark Complete", systemImage: rail.completed ? "circle" : "checkmark.circle.fill")
                    }
                    Button {
                        selectedRail = rail
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        Task { await handleDelete(rail.id) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Rail Card
    
    private func railCard(rail: LSWMeetingRail) -> some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                Task { await handleToggle(rail) }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(rail.completed ? accentColor : textTertiary, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if rail.completed {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(accentColor)
                            .frame(width: 22, height: 22)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Rail name
            Text(rail.rail.isEmpty ? "Untitled Rail" : rail.rail)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(rail.completed ? textTertiary : (rail.rail.isEmpty ? textTertiary : textPrimary))
                .strikethrough(rail.completed, color: textTertiary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            // Due date
            Text(rail.dueDateFormatted)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textSecondary)
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - Add Button
    
    private var addButton: some View {
        Button {
            showAddSheet = true
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
    
    private func handleToggle(_ rail: LSWMeetingRail) async {
        let newCompleted = !rail.completed
        // Optimistic update
        await MainActor.run {
            if let idx = lswService.meetingRails.firstIndex(where: { $0.id == rail.id }) {
                let updated = LSWMeetingRail(
                    id: rail.id, rail: rail.rail, dueDate: rail.dueDate,
                    completed: newCompleted, sortOrder: rail.sortOrder, isActive: rail.isActive
                )
                lswService.meetingRails[idx] = updated
            }
        }
        _ = await lswService.toggleMeetingRailCompleted(id: rail.id, completed: newCompleted)
    }
    
    private func handleDelete(_ id: String) async {
        await MainActor.run {
            lswService.meetingRails.removeAll { $0.id == id }
            if selectedRail?.id == id { selectedRail = nil }
        }
        _ = await lswService.deleteMeetingRail(id: id)
    }
}

// MARK: - Rail Edit Sheet

struct RailEditSheet: View {
    let rail: LSWMeetingRail?
    @StateObject private var lswService = LSWService.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var railText: String = ""
    @State private var dueDate: Date = Date()
    @State private var isSaving = false
    
    private let accentColor = Color(hex: "6366F1")
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6) }
    private var cardBackground: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.white }
    private var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08) }
    
    private var isNew: Bool { rail == nil }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Rail name field
                        fieldSection(title: "Meeting Rail", icon: "person.3") {
                            TextField("Enter meeting rail name...", text: $railText, axis: .vertical)
                                .font(.system(size: 15))
                                .lineLimit(2...4)
                                .textFieldStyle(.plain)
                        }
                        
                        // Due Date field
                        fieldSection(title: "Due Date", icon: "calendar") {
                            DatePicker("", selection: $dueDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(isNew ? "New Meeting Rail" : "Edit Meeting Rail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(railText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .onAppear {
                if let r = rail {
                    railText = r.rail
                    let raw = String(r.dueDate.prefix(10))
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    if let date = formatter.date(from: raw) {
                        dueDate = date
                    }
                }
            }
        }
    }
    
    // MARK: - Field Section
    
    @ViewBuilder
    private func fieldSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(accentColor)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(textSecondary)
            }
            
            content()
                .padding(12)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(cardBorder, lineWidth: 1)
                )
        }
    }
    
    // MARK: - Save
    
    private func save() async {
        let trimmedRail = railText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRail.isEmpty else { return }
        
        await MainActor.run { isSaving = true }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dueDateStr = formatter.string(from: dueDate)
        
        if isNew {
            if let created = await lswService.createMeetingRail(
                rail: trimmedRail,
                dueDate: dueDateStr,
                weekNumber: lswService.activeWeekNumber,
                year: lswService.activeYear
            ) {
                await MainActor.run {
                    if !lswService.meetingRails.contains(where: { $0.id == created.id }) {
                        lswService.meetingRails.append(created)
                    }
                }
            }
        } else if let r = rail {
            let updateData: [String: Any] = [
                "rail": trimmedRail,
                "dueDate": dueDateStr
            ]
            if let updated = await lswService.updateMeetingRail(id: r.id, data: updateData) {
                await MainActor.run {
                    if let idx = lswService.meetingRails.firstIndex(where: { $0.id == r.id }) {
                        lswService.meetingRails[idx] = updated
                    }
                }
            }
        }
        
        await MainActor.run {
            isSaving = false
            dismiss()
        }
    }
}
