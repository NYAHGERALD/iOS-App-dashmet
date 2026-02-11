//
//  NewMeetingView.swift
//  MeetingIntelligence
//
//  Phase 3 - Create New Meeting View (Enhanced)
//

import SwiftUI

struct NewMeetingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MeetingViewModel
    
    // Basic fields
    @State private var title: String = ""
    @State private var selectedType: MeetingType = .general
    @State private var location: String = ""
    @State private var locationType: LocationType = .onsite
    @State private var tagsText: String = ""
    @State private var selectedDate: Date = Date()
    
    // Department/Team - now fetched from API
    @State private var departments: [DepartmentInfo] = []
    @State private var selectedDepartmentId: String? = nil
    @State private var isLoadingDepartments: Bool = false
    
    // Meeting Objective & Agenda
    @State private var meetingObjective: String = ""
    @State private var agendaItems: [String] = []
    @State private var newAgendaItem: String = ""
    
    // Participants
    @State private var participants: [ParticipantEntry] = []
    @State private var showAddParticipant: Bool = false
    
    // AI Settings (collapsed by default)
    @State private var showAISettings: Bool = false
    @State private var liveTranscriptionEnabled: Bool = true
    @State private var selectedAIMode: AIProcessingMode = .executive
    @State private var confidentialityLevel: ConfidentialityLevel = .teamVisible
    
    // State
    @State private var isCreating: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showRecording: Bool = false
    @State private var createdMeeting: Meeting?
    
    var onMeetingCreated: ((Meeting) -> Void)?
    
    // Computed property for selected department name
    private var selectedDepartmentName: String {
        if let id = selectedDepartmentId,
           let dept = departments.first(where: { $0.id == id }) {
            return dept.name
        }
        return "Select Department"
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 20) {
                        // SECTION 1 — Meeting Type
                        meetingTypeSection
                        
                        // SECTION 2 — Meeting Details
                        meetingDetailsSection
                        
                        // SECTION 3 — Participants
                        participantsSection
                        
                        // SECTION 4 — Meeting Objective & Agenda
                        objectiveAgendaSection
                        
                        // SECTION 5 — AI Settings (Collapsible)
                        aiSettingsSection
                        
                        // SECTION 6 — Quick Actions
                        quickActionsSection
                        
                        // Spacer for floating button
                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .background(AppColors.background)
                
                // Floating Create Button
                floatingCreateButton
            }
            .navigationTitle("New Meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                // Meeting Type Hamburger Menu
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(MeetingType.allCases, id: \.self) { type in
                            Button {
                                selectedType = type
                            } label: {
                                HStack {
                                    Label(type.displayName, systemImage: type.icon)
                                    if selectedType == type {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3)
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .disabled(isCreating)
            .overlay {
                if isCreating {
                    ProgressView("Creating meeting...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                }
            }
            .fullScreenCover(isPresented: $showRecording) {
                if let meeting = createdMeeting {
                    RecordingView(meeting: meeting, meetingViewModel: viewModel) { recordingUrl in
                        onMeetingCreated?(meeting)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAddParticipant) {
                AddParticipantSheet(participants: $participants)
            }
            .task {
                await loadDepartments()
            }
        }
    }
    
    // MARK: - Load Departments from API
    private func loadDepartments() async {
        isLoadingDepartments = true
        do {
            departments = try await APIService.shared.fetchDepartments()
            // Auto-select first department if available
            if selectedDepartmentId == nil, let first = departments.first {
                selectedDepartmentId = first.id
            }
        } catch {
            print("⚠️ Failed to load departments: \(error.localizedDescription)")
            // Departments will remain empty, UI will show "No departments"
        }
        isLoadingDepartments = false
    }
    
    // MARK: - Section 1: Meeting Type
    private var meetingTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Meeting Type")
            
            HStack(spacing: 12) {
                Image(systemName: selectedType.icon)
                    .font(.title2)
                    .foregroundColor(Color(hex: selectedType.color))
                    .frame(width: 50, height: 50)
                    .background(Color(hex: selectedType.color).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedType.displayName)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    Text("Tap menu to change")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                
                Spacer()
            }
            .padding(16)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Section 2: Meeting Details
    private var meetingDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Meeting Details")
            
            VStack(spacing: 0) {
                // Title
                FormTextField(
                    icon: "textformat",
                    placeholder: "Meeting Title",
                    text: $title
                )
                
                Divider().padding(.leading, 44)
                
                // Date & Time
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.primary)
                        .frame(width: 28)
                    
                    DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                    
                    Spacer()
                }
                .padding(14)
                
                Divider().padding(.leading, 44)
                
                // Location Type
                HStack(spacing: 12) {
                    Image(systemName: "location")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.primary)
                        .frame(width: 28)
                    
                    Picker("Location", selection: $locationType) {
                        ForEach(LocationType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(14)
                
                if locationType == .custom {
                    Divider().padding(.leading, 44)
                    FormTextField(
                        icon: "mappin",
                        placeholder: "Custom Location",
                        text: $location
                    )
                }
                
                Divider().padding(.leading, 44)
                
                // Department - fetched from API
                HStack(spacing: 12) {
                    Image(systemName: "building.2")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.primary)
                        .frame(width: 28)
                    
                    Text("Department")
                        .foregroundColor(AppColors.textSecondary)
                    
                    Spacer()
                    
                    if isLoadingDepartments {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if departments.isEmpty {
                        Text("No departments")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textTertiary)
                    } else {
                        Menu {
                            Button {
                                selectedDepartmentId = nil
                            } label: {
                                HStack {
                                    Text("None")
                                    if selectedDepartmentId == nil {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            
                            Divider()
                            
                            ForEach(departments) { dept in
                                Button {
                                    selectedDepartmentId = dept.id
                                } label: {
                                    HStack {
                                        Text(dept.name)
                                        if selectedDepartmentId == dept.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedDepartmentName)
                                    .font(.subheadline)
                                    .foregroundColor(selectedDepartmentId == nil ? AppColors.textTertiary : AppColors.primary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                }
                .padding(14)
                
                Divider().padding(.leading, 44)
                
                // Tags
                FormTextField(
                    icon: "tag",
                    placeholder: "Tags (comma separated)",
                    text: $tagsText
                )
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Section 3: Participants
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Participants")
            
            VStack(spacing: 0) {
                // Added participants
                ForEach(participants.indices, id: \.self) { index in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(AppGradients.primary)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(participants[index].initials)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(participants[index].name)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textPrimary)
                            if let role = participants[index].role {
                                Text(role)
                                    .font(.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            participants.remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .padding(14)
                    
                    if index < participants.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
                
                if !participants.isEmpty {
                    Divider()
                }
                
                // Add participant button
                Button {
                    showAddParticipant = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppColors.primary)
                        
                        Text("Add Participant")
                            .font(.subheadline)
                            .foregroundColor(AppColors.primary)
                        
                        Spacer()
                    }
                    .padding(14)
                }
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Section 4: Objective & Agenda
    private var objectiveAgendaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Objective & Agenda")
            
            VStack(spacing: 0) {
                // Objective
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "scope")
                            .foregroundColor(AppColors.primary)
                        Text("Objective")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    
                    TextField("What's the goal of this meeting?", text: $meetingObjective, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.subheadline)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(10)
                        .background(AppColors.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Text("System uses this to focus summaries and improve action extraction")
                        .font(.caption2)
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(14)
                
                Divider()
                
                // Agenda Items
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "list.bullet.clipboard")
                            .foregroundColor(AppColors.primary)
                        Text("Agenda Items")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Spacer()
                        
                        Text("Optional")
                            .font(.caption2)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    
                    // Existing agenda items
                    ForEach(agendaItems.indices, id: \.self) { index in
                        HStack(spacing: 8) {
                            Text("•")
                                .foregroundColor(AppColors.primary)
                            Text(agendaItems[index])
                                .font(.subheadline)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Button {
                                agendaItems.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .font(.caption)
                                    .foregroundColor(AppColors.error)
                            }
                        }
                    }
                    
                    // Add new agenda item
                    HStack(spacing: 8) {
                        TextField("Add agenda item", text: $newAgendaItem)
                            .font(.subheadline)
                            .padding(8)
                            .background(AppColors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        Button {
                            if !newAgendaItem.isEmpty {
                                agendaItems.append(newAgendaItem)
                                newAgendaItem = ""
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(AppColors.primary)
                        }
                        .disabled(newAgendaItem.isEmpty)
                    }
                }
                .padding(14)
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Section 5: AI Settings (Collapsible)
    private var aiSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Collapsible header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showAISettings.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(AppColors.primary)
                    Text("System & Transcription Settings")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: showAISettings ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            
            if showAISettings {
                VStack(spacing: 0) {
                    // Live Transcription Toggle
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(AppColors.primary)
                            .frame(width: 28)
                        Text("Live Transcription")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Toggle("", isOn: $liveTranscriptionEnabled)
                            .tint(AppColors.primary)
                    }
                    .padding(14)
                    
                    Divider().padding(.leading, 44)
                    
                    // AI Processing Mode
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(AppColors.primary)
                            .frame(width: 28)
                        Text("System Mode")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Picker("", selection: $selectedAIMode) {
                            ForEach(AIProcessingMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .tint(AppColors.primary)
                    }
                    .padding(14)
                    
                    Divider().padding(.leading, 44)
                    
                    // Confidentiality Level
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(AppColors.primary)
                            .frame(width: 28)
                        Text("Confidentiality")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Picker("", selection: $confidentialityLevel) {
                            ForEach(ConfidentialityLevel.allCases, id: \.self) { level in
                                Text(level.rawValue).tag(level)
                            }
                        }
                        .tint(AppColors.primary)
                    }
                    .padding(14)
                }
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Section 6: Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Quick Actions")
            
            Button {
                Task {
                    await createMeetingAndStartRecording()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "mic.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(AppColors.error)
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start Recording")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Create meeting and begin recording immediately")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(16)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Floating Create Button
    private var floatingCreateButton: some View {
        Button {
            Task {
                await createMeetingOnly()
            }
        } label: {
            Text("Create Meeting")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppGradients.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: AppColors.primary.opacity(0.3), radius: 8, y: 4)
        }
        .disabled(isCreating)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [AppColors.background.opacity(0), AppColors.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)
            .allowsHitTesting(false)
        )
    }
    
    // MARK: - Build Participants Request
    private func buildParticipantsRequest() -> [CreateParticipantRequest] {
        return participants.map { p in
            CreateParticipantRequest(
                userId: nil,
                name: p.name,
                email: p.email,
                phone: nil
            )
        }
    }
    
    // MARK: - Create Meeting Only
    private func createMeetingOnly() async {
        isCreating = true
        
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        if let meeting = await viewModel.createMeeting(
            title: title.isEmpty ? nil : title,
            meetingType: selectedType,
            location: locationType == .custom ? location : nil,
            locationType: locationType.rawValue,
            tags: tags,
            scheduledAt: selectedDate,
            departmentId: selectedDepartmentId,
            objective: meetingObjective.isEmpty ? nil : meetingObjective,
            agendaItems: agendaItems,
            liveTranscriptionEnabled: liveTranscriptionEnabled,
            aiProcessingMode: selectedAIMode.rawValue,
            confidentialityLevel: confidentialityLevel.rawValue,
            participants: buildParticipantsRequest()
        ) {
            onMeetingCreated?(meeting)
            dismiss()
        } else {
            errorMessage = viewModel.errorMessage ?? "Failed to create meeting"
            showError = true
        }
        
        isCreating = false
    }
    
    // MARK: - Create Meeting and Start Recording
    private func createMeetingAndStartRecording() async {
        isCreating = true
        
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        if let meeting = await viewModel.createMeeting(
            title: title.isEmpty ? nil : title,
            meetingType: selectedType,
            location: locationType == .custom ? location : nil,
            locationType: locationType.rawValue,
            tags: tags,
            scheduledAt: selectedDate,
            departmentId: selectedDepartmentId,
            objective: meetingObjective.isEmpty ? nil : meetingObjective,
            agendaItems: agendaItems,
            liveTranscriptionEnabled: liveTranscriptionEnabled,
            aiProcessingMode: selectedAIMode.rawValue,
            confidentialityLevel: confidentialityLevel.rawValue,
            participants: buildParticipantsRequest()
        ) {
            createdMeeting = meeting
            isCreating = false
            showRecording = true
        } else {
            errorMessage = viewModel.errorMessage ?? "Failed to create meeting"
            showError = true
            isCreating = false
        }
    }
}

// MARK: - Supporting Types

enum LocationType: String, CaseIterable {
    case onsite = "On-site"
    case remote = "Remote"
    case hybrid = "Hybrid"
    case custom = "Custom"
}

enum AIProcessingMode: String, CaseIterable {
    case executive = "Executive Summary"
    case detailed = "Detailed Minutes"
    case actionFocused = "Action-Focused"
    case compliance = "Compliance/Audit"
}

enum ConfidentialityLevel: String, CaseIterable {
    case `private` = "Private"
    case teamVisible = "Team Visible"
    case restricted = "Restricted"
}

struct ParticipantEntry: Identifiable {
    let id = UUID()
    var name: String
    var role: String?
    var email: String?
    
    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Supporting Views

struct FormTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(AppColors.primary)
                .frame(width: 28)
            
            TextField(placeholder, text: $text)
                .font(.subheadline)
        }
        .padding(14)
    }
}

struct AddParticipantSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var participants: [ParticipantEntry]
    
    @State private var name: String = ""
    @State private var role: String = ""
    @State private var email: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Participant Details") {
                    TextField("Full Name", text: $name)
                    TextField("Role (Optional)", text: $role)
                    TextField("Email (Optional)", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Add Participant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let participant = ParticipantEntry(
                            name: name,
                            role: role.isEmpty ? nil : role,
                            email: email.isEmpty ? nil : email
                        )
                        participants.append(participant)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NewMeetingView(viewModel: MeetingViewModel())
}
