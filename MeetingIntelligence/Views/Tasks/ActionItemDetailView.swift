//
//  ActionItemDetailView.swift
//  MeetingIntelligence
//
//  Comprehensive Action Item Detail View with editing, comments, and evidence
//

import SwiftUI
import PhotosUI
import FirebaseStorage
import UniformTypeIdentifiers

struct ActionItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TaskViewModel
    
    let task: TaskItem
    let onUpdate: (() -> Void)?
    
    @State private var isEditing = false
    @State private var editTitle: String = ""
    @State private var editDescription: String = ""
    @State private var editPriority: TaskPriority = .medium
    @State private var editStatus: TaskStatus = .pending
    @State private var editDueDate: Date = Date()
    @State private var hasDueDate: Bool = false
    @State private var editProgress: Double = 0
    
    @State private var showAddComment = false
    @State private var newCommentText = ""
    
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var isSaving = false
    
    // Assignees management
    @State private var showAssigneesPicker = false
    @State private var selectedAssigneeIds: Set<String> = []
    @State private var isUpdatingAssignees = false
    
    // Evidence attachment
    @State private var showEvidenceSourcePicker = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showFilePicker = false
    @State private var showImageCropper = false
    @State private var showRenameDialog = false
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var imageToCrop: UIImage?
    @State private var croppedImage: UIImage?
    @State private var evidenceFileName: String = ""
    @State private var isUploadingEvidence = false
    @State private var uploadProgress: Double = 0
    @State private var selectedEvidenceForPreview: TaskEvidence?
    
    init(task: TaskItem, viewModel: TaskViewModel, onUpdate: (() -> Void)? = nil) {
        self.task = task
        self.viewModel = viewModel
        self.onUpdate = onUpdate
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    headerCard
                    
                    // Progress Section
                    progressSection
                    
                    // Assignees Section
                    assigneesSection
                    
                    // Details Section
                    detailsSection
                    
                    // AI Source Section (if extracted from transcript)
                    if let sourceText = currentTask.sourceText, !sourceText.isEmpty {
                        aiSourceSection(sourceText)
                    }
                    
                    // Comments Section
                    commentsSection
                    
                    // Evidence Section
                    evidenceSection
                    
                    // Danger Zone
                    if isEditing {
                        dangerZone
                    }
                }
                .padding(16)
            }
            .background(AppColors.background)
            .navigationTitle(isEditing ? "Edit Action Item" : "Action Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button("Save") {
                            Task { await saveChanges() }
                        }
                        .fontWeight(.semibold)
                        .disabled(isSaving)
                    } else {
                        Button("Edit") {
                            startEditing()
                        }
                    }
                }
            }
            .alert("Delete Action Item", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task { await deleteTask() }
                }
            } message: {
                Text("Are you sure you want to delete this action item? This cannot be undone.")
            }
        }
        .onAppear {
            Task {
                await viewModel.fetchTaskDetails(taskId: task.id)
            }
        }
    }
    
    private var currentTask: TaskItem {
        viewModel.selectedTask ?? task
    }
    
    // MARK: - Header Card
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status and Priority Row
            HStack(spacing: 12) {
                // Status Badge
                Menu {
                    ForEach(TaskStatus.allCases, id: \.self) { status in
                        Button {
                            Task {
                                _ = await viewModel.updateTaskStatus(taskId: currentTask.id, status: status)
                                onUpdate?()
                            }
                        } label: {
                            HStack {
                                Image(systemName: status.icon)
                                Text(status.displayName)
                                if currentTask.status == status {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: currentTask.status.icon)
                            .font(.system(size: 14))
                        Text(currentTask.status.displayName)
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(statusColor)
                    .clipShape(Capsule())
                }
                
                // Priority Badge
                Menu {
                    ForEach(TaskPriority.allCases, id: \.self) { priority in
                        Button {
                            Task {
                                _ = await viewModel.updateTask(taskId: currentTask.id, priority: priority)
                                onUpdate?()
                            }
                        } label: {
                            HStack {
                                Image(systemName: priority.icon)
                                Text(priority.displayName)
                                if currentTask.priority == priority {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: currentTask.priority.icon)
                            .font(.system(size: 12))
                        Text(currentTask.priority.displayName)
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(priorityColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(priorityColor.opacity(0.12))
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                // AI Badge
                if currentTask.isAiExtracted == true {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                        Text("System")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(AppColors.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.primary.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            
            // Title
            if isEditing {
                TextField("Title", text: $editTitle)
                    .font(.system(size: 22, weight: .bold))
                    .textFieldStyle(.plain)
            } else {
                Text(currentTask.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            // Description
            if isEditing {
                TextEditor(text: $editDescription)
                    .font(.system(size: 16))
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(AppColors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if let description = currentTask.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(4)
            }
            
            // Meta Info Row
            HStack(spacing: 20) {
                // Due Date
                if isEditing {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Due Date", isOn: $hasDueDate)
                            .font(.system(size: 14))
                        if hasDueDate {
                            DatePicker("", selection: $editDueDate, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                        }
                    }
                } else if let dueDate = currentTask.dueDate {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                        Text(formatDueDate(dueDate))
                            .font(.system(size: 14))
                    }
                    .foregroundColor(dueDateColor)
                }
                
                // Assignee
                if let assignee = currentTask.assignee {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppColors.primary.opacity(0.2))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Text(assignee.initials)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(AppColors.primary)
                            )
                        Text(assignee.fullName)
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(AppColors.primary)
                Text("Progress")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Text("\(currentTask.progressValue)%")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(progressColor)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.surfaceSecondary)
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(progressGradient)
                        .frame(width: geometry.size.width * CGFloat(currentTask.progressValue) / 100, height: 12)
                }
            }
            .frame(height: 12)
            
            // Quick Progress Buttons - tap to change progress
            HStack(spacing: 8) {
                ForEach([0, 25, 50, 75, 100], id: \.self) { value in
                    Button {
                        Task {
                            _ = await viewModel.updateTaskProgress(taskId: currentTask.id, progress: value)
                            onUpdate?()
                        }
                    } label: {
                        Text("\(value)%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(currentTask.progressValue == value ? .white : AppColors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(currentTask.progressValue == value ? AppColors.primary : AppColors.surfaceSecondary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(20)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Assignees Section
    private var assigneesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(AppColors.info)
                Text("Responsible Parties")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Button {
                    // Initialize selected with current assignees
                    selectedAssigneeIds = Set(currentTask.assignees?.map { $0.userId } ?? [])
                    // Fetch users if needed
                    if viewModel.organizationUsers.isEmpty {
                        Task {
                            await viewModel.fetchOrganizationUsers()
                        }
                    }
                    showAssigneesPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Add")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            
            // Current assignees list
            if let assignees = currentTask.assignees, !assignees.isEmpty {
                VStack(spacing: 8) {
                    ForEach(assignees) { assignee in
                        HStack(spacing: 12) {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(AppColors.primary.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                
                                Text(assignee.user?.initials ?? "?")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColors.primary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(assignee.displayName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppColors.textPrimary)
                                
                                if let email = assignee.user?.email {
                                    Text(email)
                                        .font(.system(size: 12))
                                        .foregroundColor(AppColors.textTertiary)
                                }
                            }
                            
                            Spacer()
                            
                            // Remove button
                            Button {
                                Task {
                                    isUpdatingAssignees = true
                                    _ = await viewModel.removeAssignee(taskId: currentTask.id, userId: assignee.userId)
                                    onUpdate?()
                                    isUpdatingAssignees = false
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .disabled(isUpdatingAssignees)
                        }
                        .padding(12)
                        .background(AppColors.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            } else {
                // Empty state
                HStack {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.textTertiary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No assignees yet")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                        Text("Tap + Add to assign responsible parties")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(AppColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            if isUpdatingAssignees {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Updating...")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(20)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showAssigneesPicker) {
            AssigneesPickerView(
                selectedUserIds: $selectedAssigneeIds,
                viewModel: viewModel,
                onSave: {
                    Task {
                        isUpdatingAssignees = true
                        showAssigneesPicker = false
                        _ = await viewModel.updateAssignees(
                            taskId: currentTask.id,
                            userIds: Array(selectedAssigneeIds)
                        )
                        onUpdate?()
                        isUpdatingAssignees = false
                    }
                }
            )
        }
    }
    
    // MARK: - Details Section
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(AppColors.info)
                Text("Details")
                    .font(.system(size: 16, weight: .semibold))
            }
            
            VStack(spacing: 12) {
                detailRow(icon: "person.fill", label: "Owner", value: currentTask.owner?.fullName ?? "Unknown")
                
                if let assignee = currentTask.assignee {
                    detailRow(icon: "person.badge.plus", label: "Assignee", value: assignee.fullName)
                }
                
                detailRow(icon: "calendar.badge.plus", label: "Created", value: formatDate(currentTask.createdAt))
                
                if let completedAt = currentTask.completedAt {
                    detailRow(icon: "checkmark.circle.fill", label: "Completed", value: formatDate(completedAt))
                }
                
                detailRow(icon: "message.fill", label: "Comments", value: "\(currentTask.commentsCount)")
                detailRow(icon: "doc.fill", label: "Evidence", value: "\(currentTask.evidenceCount)")
            }
        }
        .padding(20)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 24)
            
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
        }
    }
    
    // MARK: - AI Source Section
    private func aiSourceSection(_ sourceText: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(AppColors.primary)
                Text("Extracted From")
                    .font(.system(size: 16, weight: .semibold))
            }
            
            Text("\"" + sourceText + "\"")
                .font(.system(size: 15))
                .italic()
                .foregroundColor(AppColors.textSecondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(20)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Comments Section
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundColor(AppColors.warning)
                Text("Comments")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Button {
                    showAddComment = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                        Text("Add")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            
            if let comments = currentTask.comments, !comments.isEmpty {
                ForEach(comments) { comment in
                    CommentRow(comment: comment, onDelete: {
                        Task {
                            _ = await viewModel.deleteComment(commentId: comment.id, taskId: currentTask.id)
                        }
                    })
                }
            } else {
                Text("No comments yet")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
            
            // Add Comment Input
            if showAddComment {
                VStack(spacing: 12) {
                    TextEditor(text: $newCommentText)
                        .font(.system(size: 15))
                        .frame(minHeight: 60)
                        .padding(8)
                        .background(AppColors.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    HStack {
                        Button("Cancel") {
                            showAddComment = false
                            newCommentText = ""
                        }
                        .foregroundColor(AppColors.textSecondary)
                        
                        Spacer()
                        
                        Button {
                            Task {
                                _ = await viewModel.addComment(taskId: currentTask.id, content: newCommentText)
                                newCommentText = ""
                                showAddComment = false
                            }
                        } label: {
                            Text("Post Comment")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(AppColors.primary)
                                .clipShape(Capsule())
                        }
                        .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .padding(20)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Evidence Section
    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "paperclip")
                    .foregroundColor(AppColors.success)
                Text("Evidence & Attachments")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Button {
                    showEvidenceSourcePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                        Text("Add")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            
            // Upload progress indicator
            if isUploadingEvidence {
                VStack(spacing: 8) {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Uploading evidence...")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text("\(Int(uploadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(AppColors.primary)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppColors.surfaceSecondary)
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppColors.primary)
                                .frame(width: geometry.size.width * uploadProgress, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(12)
                .background(AppColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // Evidence grid/list
            if let evidence = currentTask.evidence, !evidence.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(evidence) { item in
                        EvidenceThumbnailCard(
                            evidence: item,
                            onTap: {
                                selectedEvidenceForPreview = item
                            },
                            onDelete: {
                                Task {
                                    _ = await viewModel.deleteEvidence(evidenceId: item.id, taskId: currentTask.id)
                                    onUpdate?()
                                }
                            }
                        )
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.textTertiary)
                    Text("No evidence attached")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textTertiary)
                    Text("Tap + Add to attach photos or files")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            }
        }
        .padding(20)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .confirmationDialog("Add Evidence", isPresented: $showEvidenceSourcePicker) {
            Button {
                showPhotoPicker = true
            } label: {
                Label("Photo Library", systemImage: "photo.on.rectangle")
            }
            
            Button {
                showCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera")
            }
            
            Button {
                showFilePicker = true
            } label: {
                Label("Choose File", systemImage: "folder")
            }
            
            Button("Cancel", role: .cancel) { }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedImages, maxSelectionCount: 5, matching: .images)
        .onChange(of: selectedImages) { _, newItems in
            Task {
                await processSelectedPhotos(newItems)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraWithCropView(croppedImage: $croppedImage, onComplete: {
                showCamera = false
                if croppedImage != nil {
                    // Generate unique filename
                    let timestamp = Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")
                    let uniqueId = String(UUID().uuidString.prefix(6))
                    evidenceFileName = "Evidence_\(timestamp)_\(uniqueId)"
                    showRenameDialog = true
                }
            })
        }
        .fullScreenCover(isPresented: $showImageCropper) {
            if let image = imageToCrop {
                NativeImageCropperView(
                    image: image,
                    onCrop: { cropped in
                        croppedImage = cropped
                        imageToCrop = nil
                        showImageCropper = false
                        // Generate unique filename with timestamp and random suffix
                        let timestamp = Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")
                        let uniqueId = String(UUID().uuidString.prefix(6))
                        evidenceFileName = "Evidence_\(timestamp)_\(uniqueId)"
                        showRenameDialog = true
                    },
                    onCancel: {
                        imageToCrop = nil
                        showImageCropper = false
                    }
                )
            }
        }
        .alert("Rename Evidence", isPresented: $showRenameDialog) {
            TextField("File name", text: $evidenceFileName)
            Button("Cancel", role: .cancel) {
                croppedImage = nil
                evidenceFileName = ""
            }
            Button("Upload") {
                Task {
                    await uploadEvidenceImage()
                }
            }
        } message: {
            Text("Enter a name for this evidence")
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.image, .pdf, .data], allowsMultipleSelection: true) { result in
            Task {
                await handleFileImport(result)
            }
        }
        .fullScreenCover(item: $selectedEvidenceForPreview) { evidence in
            EvidencePreviewView(evidence: evidence)
        }
    }
    
    // MARK: - Evidence Helper Methods
    
    private func processSelectedPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    imageToCrop = image
                    showImageCropper = true
                }
                // Process one at a time
                break
            }
        }
        selectedImages = []
    }
    
    private func uploadEvidenceImage() async {
        guard let image = croppedImage else { return }
        
        isUploadingEvidence = true
        uploadProgress = 0
        
        do {
            // Convert to JPEG data
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw EvidenceUploadError.invalidFile
            }
            
            // Upload to Firebase
            let fileName = evidenceFileName.isEmpty ? "evidence_\(UUID().uuidString.prefix(8))" : evidenceFileName
            let downloadURL = try await uploadImageToFirebase(
                data: imageData,
                fileName: "\(fileName).jpg",
                taskId: currentTask.id
            )
            
            // Add evidence record to backend
            _ = await viewModel.addEvidence(
                taskId: currentTask.id,
                title: fileName,
                description: nil,
                fileUrl: downloadURL,
                fileType: "image/jpeg",
                fileName: "\(fileName).jpg"
            )
            
            onUpdate?()
            
        } catch {
            print("❌ Error uploading evidence: \(error)")
            viewModel.errorMessage = error.localizedDescription
        }
        
        croppedImage = nil
        evidenceFileName = ""
        isUploadingEvidence = false
        uploadProgress = 0
    }
    
    private func uploadImageToFirebase(data: Data, fileName: String, taskId: String) async throws -> String {
        let storage = Storage.storage()
        let userId = viewModel.currentUserId ?? "unknown"
        let storagePath = "tasks/\(taskId)/evidence/\(userId)/\(fileName)"
        let storageRef = storage.reference().child(storagePath)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        return try await withCheckedThrowingContinuation { continuation in
            let uploadTask = storageRef.putData(data, metadata: metadata) { metadata, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                storageRef.downloadURL { url, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let url = url {
                        continuation.resume(returning: url.absoluteString)
                    } else {
                        continuation.resume(throwing: EvidenceUploadError.uploadFailed("Failed to get download URL"))
                    }
                }
            }
            
            // Track progress
            uploadTask.observe(.progress) { snapshot in
                if let progress = snapshot.progress {
                    Task { @MainActor in
                        self.uploadProgress = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    }
                }
            }
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                
                do {
                    let data = try Data(contentsOf: url)
                    let fileName = url.lastPathComponent
                    
                    // Check if it's an image
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            imageToCrop = image
                            evidenceFileName = url.deletingPathExtension().lastPathComponent
                            showImageCropper = true
                        }
                    } else {
                        // Upload non-image file directly
                        isUploadingEvidence = true
                        let downloadURL = try await uploadFileToFirebase(data: data, fileName: fileName, taskId: currentTask.id)
                        
                        _ = await viewModel.addEvidence(
                            taskId: currentTask.id,
                            title: url.deletingPathExtension().lastPathComponent,
                            description: nil,
                            fileUrl: downloadURL,
                            fileType: url.pathExtension,
                            fileName: fileName
                        )
                        
                        onUpdate?()
                        isUploadingEvidence = false
                    }
                } catch {
                    print("❌ Error importing file: \(error)")
                }
            }
        case .failure(let error):
            print("❌ File import failed: \(error)")
        }
    }
    
    private func uploadFileToFirebase(data: Data, fileName: String, taskId: String) async throws -> String {
        let storage = Storage.storage()
        let userId = viewModel.currentUserId ?? "unknown"
        let storagePath = "tasks/\(taskId)/evidence/\(userId)/\(fileName)"
        let storageRef = storage.reference().child(storagePath)
        
        return try await withCheckedThrowingContinuation { continuation in
            let uploadTask = storageRef.putData(data, metadata: nil) { metadata, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                storageRef.downloadURL { url, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let url = url {
                        continuation.resume(returning: url.absoluteString)
                    } else {
                        continuation.resume(throwing: EvidenceUploadError.uploadFailed("Failed to get download URL"))
                    }
                }
            }
            
            uploadTask.observe(.progress) { snapshot in
                if let progress = snapshot.progress {
                    Task { @MainActor in
                        self.uploadProgress = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    }
                }
            }
        }
    }
    
    // MARK: - Danger Zone
    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppColors.error)
                Text("Danger Zone")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.error)
            }
            
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Delete Action Item")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColors.error)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(isDeleting)
        }
        .padding(20)
        .background(AppColors.error.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Helper Methods
    private func startEditing() {
        editTitle = currentTask.title
        editDescription = currentTask.description ?? ""
        editPriority = currentTask.priority
        editStatus = currentTask.status
        editProgress = Double(currentTask.progressValue)
        hasDueDate = currentTask.dueDate != nil
        editDueDate = currentTask.dueDate ?? Date()
        isEditing = true
    }
    
    private func saveChanges() async {
        isSaving = true
        _ = await viewModel.updateTask(
            taskId: currentTask.id,
            title: editTitle,
            description: editDescription.isEmpty ? nil : editDescription,
            status: editStatus,
            priority: editPriority,
            dueDate: hasDueDate ? editDueDate : nil,
            progress: Int(editProgress)
        )
        onUpdate?()
        isSaving = false
        isEditing = false
    }
    
    private func deleteTask() async {
        isDeleting = true
        let success = await viewModel.deleteTask(taskId: currentTask.id)
        isDeleting = false
        if success {
            onUpdate?()
            dismiss()
        }
    }
    
    private var statusColor: Color {
        switch currentTask.status {
        case .completed: return AppColors.success
        case .inProgress: return AppColors.primary
        case .cancelled: return AppColors.error
        case .pending: return AppColors.textSecondary
        }
    }
    
    private var priorityColor: Color {
        switch currentTask.priority {
        case .urgent: return AppColors.error
        case .high: return AppColors.warning
        case .medium: return AppColors.info
        case .low: return AppColors.textTertiary
        }
    }
    
    private var dueDateColor: Color {
        guard let dueDate = currentTask.dueDate else { return AppColors.textSecondary }
        if dueDate < Date() && currentTask.status != .completed {
            return AppColors.error
        } else if Calendar.current.isDateInToday(dueDate) {
            return AppColors.warning
        }
        return AppColors.textSecondary
    }
    
    private var progressColor: Color {
        let progress = currentTask.progressValue
        if progress >= 100 { return AppColors.success }
        if progress >= 75 { return AppColors.primary }
        if progress >= 50 { return AppColors.info }
        if progress >= 25 { return AppColors.warning }
        return AppColors.textTertiary
    }
    
    private var progressGradient: LinearGradient {
        let progress = currentTask.progressValue
        if progress >= 100 {
            return LinearGradient(colors: [AppColors.success, AppColors.success.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(colors: [AppColors.primary, AppColors.primary.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
    }
    
    private func formatDueDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if date < Date() {
            let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
            return "\(days)d overdue"
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Comment Row
struct CommentRow: View {
    let comment: TaskComment
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(comment.author?.initials ?? "?")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(comment.author?.fullName ?? "Unknown")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(comment.timeAgo)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                }
                
                Spacer()
                
                Menu {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(AppColors.textTertiary)
                        .padding(8)
                }
            }
            
            Text(comment.content)
                .font(.system(size: 15))
                .foregroundColor(AppColors.textPrimary)
                .padding(.leading, 40)
        }
        .padding(12)
        .background(AppColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Evidence Row
struct EvidenceRow: View {
    let evidence: TaskEvidence
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: evidence.fileIcon)
                .font(.system(size: 20))
                .foregroundColor(AppColors.primary)
                .frame(width: 40, height: 40)
                .background(AppColors.primary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(evidence.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                
                if let description = evidence.description {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
                
                Text("Added \(evidence.formattedDate) by \(evidence.uploader?.fullName ?? "Unknown")")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textTertiary)
            }
            
            Spacer()
            
            Menu {
                if let _ = evidence.fileUrl {
                    Button {
                        // Open file
                    } label: {
                        Label("Open", systemImage: "arrow.up.right")
                    }
                }
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(AppColors.textTertiary)
                    .padding(8)
            }
        }
        .padding(12)
        .background(AppColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Assignees Picker View
struct AssigneesPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedUserIds: Set<String>
    @ObservedObject var viewModel: TaskViewModel
    let onSave: () -> Void
    
    @State private var searchText = ""
    
    var filteredUsers: [OrganizationUser] {
        if searchText.isEmpty {
            return viewModel.organizationUsers
        }
        return viewModel.organizationUsers.filter { user in
            user.fullName.localizedCaseInsensitiveContains(searchText) ||
            user.email.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.textTertiary)
                    TextField("Search users...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(12)
                .background(AppColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                if viewModel.isLoadingUsers {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading users...")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                } else if filteredUsers.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 40))
                            .foregroundColor(AppColors.textTertiary)
                        Text(searchText.isEmpty ? "No users available" : "No users found")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                } else {
                    // Users list
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredUsers) { user in
                                UserSelectionRow(
                                    user: user,
                                    isSelected: selectedUserIds.contains(user.id),
                                    onToggle: {
                                        if selectedUserIds.contains(user.id) {
                                            selectedUserIds.remove(user.id)
                                        } else {
                                            selectedUserIds.insert(user.id)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
                
                // Selected count and save button
                VStack(spacing: 12) {
                    Divider()
                    
                    HStack {
                        Text("\(selectedUserIds.count) selected")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Spacer()
                        
                        Button {
                            onSave()
                        } label: {
                            Text("Save")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(AppColors.primary)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            .background(AppColors.background)
            .navigationTitle("Select Assignees")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        selectedUserIds.removeAll()
                    }
                    .foregroundColor(AppColors.error)
                    .disabled(selectedUserIds.isEmpty)
                }
            }
            .task {
                // Fetch users when view appears if not already loaded
                if viewModel.organizationUsers.isEmpty && !viewModel.isLoadingUsers {
                    await viewModel.fetchOrganizationUsers()
                }
            }
        }
    }
}

// MARK: - User Selection Row
struct UserSelectionRow: View {
    let user: OrganizationUser
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(isSelected ? AppColors.primary : AppColors.primary.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text(user.initials)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.fullName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(user.email)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textTertiary)
                }
                
                Spacer()
                
                if let role = user.role {
                    Text(role.capitalized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.surfaceSecondary)
                        .clipShape(Capsule())
                }
            }
            .padding(12)
            .background(isSelected ? AppColors.primary.opacity(0.1) : AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppColors.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Evidence Upload Error
enum EvidenceUploadError: LocalizedError {
    case invalidFile
    case uploadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return "Invalid file format"
        case .uploadFailed(let message):
            return message
        }
    }
}

// MARK: - Evidence Thumbnail Card
struct EvidenceThumbnailCard: View {
    let evidence: TaskEvidence
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail with delete button overlay
            ZStack(alignment: .topTrailing) {
                Button(action: onTap) {
                    ZStack {
                        if let fileUrl = evidence.fileUrl, let url = URL(string: fileUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(AppColors.surfaceSecondary)
                                        .overlay(ProgressView())
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 120)
                                        .clipped()
                                case .failure:
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(AppColors.surfaceSecondary)
                                        .overlay(
                                            Image(systemName: evidence.fileIcon)
                                                .font(.system(size: 32))
                                                .foregroundColor(AppColors.textTertiary)
                                        )
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.surfaceSecondary)
                                .overlay(
                                    Image(systemName: evidence.fileIcon)
                                        .font(.system(size: 32))
                                        .foregroundColor(AppColors.textTertiary)
                                )
                        }
                    }
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                
                // Delete button overlay
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white, Color.red)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                .padding(6)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(evidence.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                Text(evidence.formattedDate)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        .confirmationDialog("Delete Evidence", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this evidence? This action cannot be undone.")
        }
    }
}

// MARK: - Camera With Native Crop View
struct CameraWithCropView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var croppedImage: UIImage?
    let onComplete: () -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true // Enable native iOS cropping
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraWithCropView
        
        init(_ parent: CameraWithCropView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Prefer edited (cropped) image, fallback to original
            if let editedImage = info[.editedImage] as? UIImage {
                parent.croppedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.croppedImage = originalImage
            }
            parent.onComplete()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.croppedImage = nil
            parent.onComplete()
        }
    }
}

// MARK: - Native Image Cropper View (UIKit-based)
struct NativeImageCropperView: UIViewControllerRepresentable {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let cropVC = ImageCropViewController(image: image)
        cropVC.delegate = context.coordinator
        let navController = UINavigationController(rootViewController: cropVC)
        navController.modalPresentationStyle = .fullScreen
        return navController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCrop: onCrop, onCancel: onCancel)
    }
    
    class Coordinator: NSObject, ImageCropViewControllerDelegate {
        let onCrop: (UIImage) -> Void
        let onCancel: () -> Void
        
        init(onCrop: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCrop = onCrop
            self.onCancel = onCancel
        }
        
        func cropViewController(_ controller: ImageCropViewController, didCropImage image: UIImage) {
            onCrop(image)
        }
        
        func cropViewControllerDidCancel(_ controller: ImageCropViewController) {
            onCancel()
        }
    }
}

// MARK: - Image Crop View Controller Delegate
protocol ImageCropViewControllerDelegate: AnyObject {
    func cropViewController(_ controller: ImageCropViewController, didCropImage image: UIImage)
    func cropViewControllerDidCancel(_ controller: ImageCropViewController)
}

// MARK: - Image Crop View Controller (UIKit)
class ImageCropViewController: UIViewController {
    
    weak var delegate: ImageCropViewControllerDelegate?
    
    private let originalImage: UIImage
    private var imageView: UIImageView!
    private var cropOverlayView: CropOverlayUIView!
    private var scrollView: UIScrollView!
    
    init(image: UIImage) {
        self.originalImage = image
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupInitialZoom()
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Scroll view for zoom and pan
        scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = true
        scrollView.bouncesZoom = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // Image view
        imageView = UIImageView(image: originalImage)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)
        
        // Crop overlay
        cropOverlayView = CropOverlayUIView()
        cropOverlayView.translatesAutoresizingMaskIntoConstraints = false
        cropOverlayView.isUserInteractionEnabled = true
        view.addSubview(cropOverlayView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80),
            
            cropOverlayView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            cropOverlayView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            cropOverlayView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            cropOverlayView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
        ])
    }
    
    private func setupInitialZoom() {
        let scrollViewSize = scrollView.bounds.size
        let imageSize = originalImage.size
        
        guard scrollViewSize.width > 0 && scrollViewSize.height > 0 else { return }
        
        let widthScale = scrollViewSize.width / imageSize.width
        let heightScale = scrollViewSize.height / imageSize.height
        let minScale = min(widthScale, heightScale)
        
        scrollView.minimumZoomScale = minScale
        scrollView.zoomScale = minScale
        
        imageView.frame = CGRect(origin: .zero, size: CGSize(
            width: imageSize.width * minScale,
            height: imageSize.height * minScale
        ))
        
        scrollView.contentSize = imageView.frame.size
        centerImageView()
        
        // Initialize crop rect
        let padding: CGFloat = 30
        let cropWidth = min(scrollViewSize.width - padding * 2, imageView.frame.width - padding)
        let cropHeight = min(scrollViewSize.height - padding * 2, imageView.frame.height - padding)
        let cropSize = min(cropWidth, cropHeight)
        
        let cropRect = CGRect(
            x: (scrollViewSize.width - cropSize) / 2,
            y: (scrollViewSize.height - cropSize) / 2,
            width: cropSize,
            height: cropSize
        )
        cropOverlayView.setCropRect(cropRect)
    }
    
    private func centerImageView() {
        let scrollViewSize = scrollView.bounds.size
        let imageViewSize = imageView.frame.size
        
        let horizontalPadding = max(0, (scrollViewSize.width - imageViewSize.width) / 2)
        let verticalPadding = max(0, (scrollViewSize.height - imageViewSize.height) / 2)
        
        scrollView.contentInset = UIEdgeInsets(
            top: verticalPadding,
            left: horizontalPadding,
            bottom: verticalPadding,
            right: horizontalPadding
        )
    }
    
    private func setupNavigationBar() {
        title = "Crop Image"
        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: self,
            action: #selector(doneTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
    }
    
    @objc private func cancelTapped() {
        delegate?.cropViewControllerDidCancel(self)
    }
    
    @objc private func doneTapped() {
        guard let croppedImage = cropImage() else {
            delegate?.cropViewController(self, didCropImage: originalImage)
            return
        }
        delegate?.cropViewController(self, didCropImage: croppedImage)
    }
    
    private func cropImage() -> UIImage? {
        let cropRect = cropOverlayView.cropRect
        
        // Convert crop rect from overlay view coordinates to image coordinates
        let scrollViewOffset = scrollView.contentOffset
        let zoomScale = scrollView.zoomScale
        let contentInset = scrollView.contentInset
        
        // Calculate the visible rect in the image
        let visibleX = (scrollViewOffset.x + cropRect.minX - contentInset.left) / zoomScale
        let visibleY = (scrollViewOffset.y + cropRect.minY - contentInset.top) / zoomScale
        let visibleWidth = cropRect.width / zoomScale
        let visibleHeight = cropRect.height / zoomScale
        
        // Scale to actual image size
        let imageScale = originalImage.size.width / imageView.frame.width * zoomScale
        
        let cropRectInImage = CGRect(
            x: max(0, visibleX * imageScale),
            y: max(0, visibleY * imageScale),
            width: visibleWidth * imageScale,
            height: visibleHeight * imageScale
        )
        
        // Ensure crop rect is within image bounds
        let boundedRect = CGRect(
            x: min(max(0, cropRectInImage.origin.x), originalImage.size.width),
            y: min(max(0, cropRectInImage.origin.y), originalImage.size.height),
            width: min(cropRectInImage.width, originalImage.size.width - cropRectInImage.origin.x),
            height: min(cropRectInImage.height, originalImage.size.height - cropRectInImage.origin.y)
        )
        
        guard let cgImage = originalImage.cgImage?.cropping(to: boundedRect) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage, scale: originalImage.scale, orientation: originalImage.imageOrientation)
    }
}

extension ImageCropViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImageView()
    }
}

// MARK: - Crop Overlay UIView
class CropOverlayUIView: UIView {
    
    private(set) var cropRect: CGRect = .zero
    private var initialCropRect: CGRect = .zero
    private var activeCorner: Corner?
    
    private let cornerSize: CGFloat = 44
    private let minCropSize: CGFloat = 80
    
    enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight, move
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = false
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setCropRect(_ rect: CGRect) {
        cropRect = rect
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Draw semi-transparent overlay
        context.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
        context.fill(rect)
        
        // Clear the crop area
        context.setBlendMode(.clear)
        context.fill(cropRect)
        
        // Reset blend mode
        context.setBlendMode(.normal)
        
        // Draw crop border
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2)
        context.stroke(cropRect)
        
        // Draw grid lines (rule of thirds)
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(0.5)
        
        let thirdWidth = cropRect.width / 3
        let thirdHeight = cropRect.height / 3
        
        // Vertical lines
        for i in 1...2 {
            let x = cropRect.minX + thirdWidth * CGFloat(i)
            context.move(to: CGPoint(x: x, y: cropRect.minY))
            context.addLine(to: CGPoint(x: x, y: cropRect.maxY))
        }
        
        // Horizontal lines
        for i in 1...2 {
            let y = cropRect.minY + thirdHeight * CGFloat(i)
            context.move(to: CGPoint(x: cropRect.minX, y: y))
            context.addLine(to: CGPoint(x: cropRect.maxX, y: y))
        }
        context.strokePath()
        
        // Draw corner handles
        let handleRadius: CGFloat = 12
        let corners: [(CGPoint, Corner)] = [
            (CGPoint(x: cropRect.minX, y: cropRect.minY), .topLeft),
            (CGPoint(x: cropRect.maxX, y: cropRect.minY), .topRight),
            (CGPoint(x: cropRect.minX, y: cropRect.maxY), .bottomLeft),
            (CGPoint(x: cropRect.maxX, y: cropRect.maxY), .bottomRight)
        ]
        
        for (point, _) in corners {
            // White fill
            context.setFillColor(UIColor.white.cgColor)
            context.fillEllipse(in: CGRect(
                x: point.x - handleRadius,
                y: point.y - handleRadius,
                width: handleRadius * 2,
                height: handleRadius * 2
            ))
            
            // Blue border
            context.setStrokeColor(UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0).cgColor)
            context.setLineWidth(3)
            context.strokeEllipse(in: CGRect(
                x: point.x - handleRadius,
                y: point.y - handleRadius,
                width: handleRadius * 2,
                height: handleRadius * 2
            ))
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        
        switch gesture.state {
        case .began:
            initialCropRect = cropRect
            activeCorner = cornerAt(location)
            
        case .changed:
            guard let corner = activeCorner else { return }
            let translation = gesture.translation(in: self)
            
            var newRect = initialCropRect
            
            switch corner {
            case .topLeft:
                newRect.origin.x = min(initialCropRect.origin.x + translation.x, initialCropRect.maxX - minCropSize)
                newRect.origin.y = min(initialCropRect.origin.y + translation.y, initialCropRect.maxY - minCropSize)
                newRect.size.width = initialCropRect.maxX - newRect.origin.x
                newRect.size.height = initialCropRect.maxY - newRect.origin.y
                
            case .topRight:
                newRect.size.width = max(initialCropRect.width + translation.x, minCropSize)
                newRect.origin.y = min(initialCropRect.origin.y + translation.y, initialCropRect.maxY - minCropSize)
                newRect.size.height = initialCropRect.maxY - newRect.origin.y
                
            case .bottomLeft:
                newRect.origin.x = min(initialCropRect.origin.x + translation.x, initialCropRect.maxX - minCropSize)
                newRect.size.width = initialCropRect.maxX - newRect.origin.x
                newRect.size.height = max(initialCropRect.height + translation.y, minCropSize)
                
            case .bottomRight:
                newRect.size.width = max(initialCropRect.width + translation.x, minCropSize)
                newRect.size.height = max(initialCropRect.height + translation.y, minCropSize)
                
            case .move:
                newRect.origin.x = initialCropRect.origin.x + translation.x
                newRect.origin.y = initialCropRect.origin.y + translation.y
            }
            
            // Constrain to bounds
            newRect.origin.x = max(0, min(newRect.origin.x, bounds.width - newRect.width))
            newRect.origin.y = max(0, min(newRect.origin.y, bounds.height - newRect.height))
            newRect.size.width = min(newRect.width, bounds.width - newRect.origin.x)
            newRect.size.height = min(newRect.height, bounds.height - newRect.origin.y)
            
            cropRect = newRect
            setNeedsDisplay()
            
        case .ended, .cancelled:
            activeCorner = nil
            
        default:
            break
        }
    }
    
    private func cornerAt(_ point: CGPoint) -> Corner? {
        let corners: [(CGPoint, Corner)] = [
            (CGPoint(x: cropRect.minX, y: cropRect.minY), .topLeft),
            (CGPoint(x: cropRect.maxX, y: cropRect.minY), .topRight),
            (CGPoint(x: cropRect.minX, y: cropRect.maxY), .bottomLeft),
            (CGPoint(x: cropRect.maxX, y: cropRect.maxY), .bottomRight)
        ]
        
        for (cornerPoint, corner) in corners {
            if distance(from: point, to: cornerPoint) < cornerSize {
                return corner
            }
        }
        
        // Check if inside crop rect for move
        if cropRect.insetBy(dx: cornerSize / 2, dy: cornerSize / 2).contains(point) {
            return .move
        }
        
        return nil
    }
    
    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2))
    }
}

// MARK: - Evidence Preview View
struct EvidencePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let evidence: TaskEvidence
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    if let fileUrl = evidence.fileUrl, let url = URL(string: fileUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .scaleEffect(scale)
                                    .offset(offset)
                                    .gesture(
                                        MagnificationGesture()
                                            .onChanged { value in
                                                scale = lastScale * value
                                            }
                                            .onEnded { _ in
                                                lastScale = scale
                                                if scale < 1.0 {
                                                    withAnimation {
                                                        scale = 1.0
                                                        lastScale = 1.0
                                                        offset = .zero
                                                        lastOffset = .zero
                                                    }
                                                }
                                            }
                                    )
                                    .simultaneousGesture(
                                        DragGesture()
                                            .onChanged { value in
                                                if scale > 1.0 {
                                                    offset = CGSize(
                                                        width: lastOffset.width + value.translation.width,
                                                        height: lastOffset.height + value.translation.height
                                                    )
                                                }
                                            }
                                            .onEnded { _ in
                                                lastOffset = offset
                                            }
                                    )
                                    .gesture(
                                        TapGesture(count: 2)
                                            .onEnded {
                                                withAnimation {
                                                    if scale > 1.0 {
                                                        scale = 1.0
                                                        lastScale = 1.0
                                                        offset = .zero
                                                        lastOffset = .zero
                                                    } else {
                                                        scale = 2.5
                                                        lastScale = 2.5
                                                    }
                                                }
                                            }
                                    )
                            case .failure:
                                VStack(spacing: 16) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 48))
                                        .foregroundColor(.white.opacity(0.7))
                                    Text("Failed to load image")
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: evidence.fileIcon)
                                .font(.system(size: 64))
                                .foregroundColor(.white.opacity(0.7))
                            Text(evidence.title)
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .navigationTitle(evidence.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

#Preview {
    Text("Action Item Detail Preview")
}
