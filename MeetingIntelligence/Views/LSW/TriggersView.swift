//
//  TriggersView.swift
//  MeetingIntelligence
//
//  Plant Specific Cause RCA Triggers - row cards with edit modal and WebSocket sync
//

import SwiftUI

// MARK: - Triggers List (Main Screen)

struct TriggersView: View {
    @StateObject private var lswService = LSWService.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedTrigger: LSWRcaTrigger?
    @State private var showAddSheet = false
    @State private var showDeleteConfirm = false
    @State private var deleteTargetId: String?
    
    private let accentColor = Color(hex: "EF4444") // Red
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6) }
    private var textTertiary: Color { colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4) }
    private var cardBackground: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.white }
    private var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08) }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            if lswService.isLoadingTriggers {
                loadingView
            } else if lswService.rcaTriggers.isEmpty {
                emptyStateView
            } else {
                triggersList
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
        .navigationTitle("RCA Triggers")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await lswService.fetchRcaTriggers()
            lswService.connectTriggerWebSocket()
        }
        .alert("Delete Trigger", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let id = deleteTargetId {
                    Task { await handleDelete(id) }
                }
            }
        } message: {
            Text("This RCA trigger will be permanently deleted.")
        }
        .sheet(isPresented: $showAddSheet) {
            TriggerEditSheet(trigger: nil)
        }
        .sheet(item: $selectedTrigger) { trigger in
            TriggerEditSheet(trigger: trigger)
        }
    }
    
    // MARK: - Loading
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading triggers...")
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
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundColor(accentColor)
            }
            
            Text("No RCA Triggers Yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Text("Tap the + button to add your first RCA event trigger.")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Triggers List
    
    private var triggersList: some View {
        List {
            ForEach(lswService.rcaTriggers) { trigger in
                Button {
                    selectedTrigger = trigger
                } label: {
                    triggerCard(trigger: trigger)
                }
                .buttonStyle(.plain)
                .listRowBackground(cardBackground)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await handleDelete(trigger.id) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button {
                        selectedTrigger = trigger
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        deleteTargetId = trigger.id
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
    
    // MARK: - Trigger Card
    
    private func triggerCard(trigger: LSWRcaTrigger) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Trigger title
            Text(trigger.trigger.isEmpty ? "Untitled Trigger" : trigger.trigger)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(trigger.trigger.isEmpty ? textTertiary : textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Event date row
            HStack(spacing: 12) {
                if !trigger.eventDateFormatted.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text(trigger.eventDateFormatted)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.12))
                    .foregroundColor(accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(textTertiary.opacity(0.5))
            }
            
            // Comment preview
            if let comments = trigger.comments, !comments.isEmpty {
                Text(comments)
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
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
    
    private func handleDelete(_ id: String) async {
        await MainActor.run {
            lswService.rcaTriggers.removeAll { $0.id == id }
            if selectedTrigger?.id == id { selectedTrigger = nil }
        }
        _ = await lswService.deleteRcaTrigger(id: id)
    }
}

// MARK: - Trigger Edit Sheet

struct TriggerEditSheet: View {
    let trigger: LSWRcaTrigger?
    @StateObject private var lswService = LSWService.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var triggerText: String = ""
    @State private var eventDate: Date = Date()
    @State private var hasEventDate: Bool = false
    @State private var comments: String = ""
    @State private var isSaving = false
    
    private let accentColor = Color(hex: "EF4444")
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6) }
    private var cardBackground: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.white }
    private var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08) }
    
    private var isNew: Bool { trigger == nil }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Trigger field
                        fieldSection(title: "RCA Event Trigger", icon: "exclamationmark.triangle") {
                            TextField("Enter RCA trigger...", text: $triggerText, axis: .vertical)
                                .font(.system(size: 15))
                                .lineLimit(2...6)
                                .textFieldStyle(.plain)
                        }
                        
                        // Event Date field
                        fieldSection(title: "Event Date", icon: "calendar") {
                            VStack(spacing: 8) {
                                Toggle("Has event date", isOn: $hasEventDate)
                                    .font(.system(size: 14))
                                    .tint(accentColor)
                                
                                if hasEventDate {
                                    DatePicker("", selection: $eventDate, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                }
                            }
                        }
                        
                        // Comments field
                        fieldSection(title: "Comments / Notes", icon: "text.bubble") {
                            TextField("Add comment...", text: $comments, axis: .vertical)
                                .font(.system(size: 15))
                                .lineLimit(3...8)
                                .textFieldStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(isNew ? "New RCA Trigger" : "Edit RCA Trigger")
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
                    .disabled(triggerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .onAppear {
                if let t = trigger {
                    triggerText = t.trigger
                    comments = t.comments ?? ""
                    if let raw = t.eventDate?.prefix(10), !raw.isEmpty {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        formatter.timeZone = TimeZone(identifier: "UTC")
                        if let date = formatter.date(from: String(raw)) {
                            eventDate = date
                            hasEventDate = true
                        }
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
        let trimmedTrigger = triggerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTrigger.isEmpty else { return }
        
        await MainActor.run { isSaving = true }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let eventDateStr: String? = hasEventDate ? formatter.string(from: eventDate) : nil
        let trimmedComments = comments.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isNew {
            if let created = await lswService.createRcaTrigger(
                trigger: trimmedTrigger,
                eventDate: eventDateStr,
                comments: trimmedComments.isEmpty ? nil : trimmedComments
            ) {
                await MainActor.run {
                    if !lswService.rcaTriggers.contains(where: { $0.id == created.id }) {
                        lswService.rcaTriggers.append(created)
                    }
                }
            }
        } else if let t = trigger {
            var updateData: [String: Any] = ["trigger": trimmedTrigger]
            if let ed = eventDateStr {
                updateData["eventDate"] = ed
            } else {
                updateData["eventDate"] = NSNull()
            }
            if !trimmedComments.isEmpty {
                updateData["comments"] = trimmedComments
            }
            if let updated = await lswService.updateRcaTrigger(id: t.id, data: updateData) {
                await MainActor.run {
                    if let idx = lswService.rcaTriggers.firstIndex(where: { $0.id == t.id }) {
                        lswService.rcaTriggers[idx] = updated
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
