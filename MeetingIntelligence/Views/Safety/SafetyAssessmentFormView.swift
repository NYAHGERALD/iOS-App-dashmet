import SwiftUI
import PhotosUI

struct SafetyAssessmentFormView: View {
    @ObservedObject var viewModel: SafetyAssessmentViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Photo state
    @State private var showImagePicker = false
    @State private var activePhotoItemId: String?
    @State private var fullScreenImage: UIImage?
    @State private var showFullScreenPhoto = false
    @State private var showDraftSavedFeedback = false
    @State private var showDeletePhotoAlert = false
    @State private var photoToDeleteItemId: String?
    @State private var photoToDeleteIndex: Int?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top bar with stats
                    topBar
                    
                    // Sections list
                    ScrollView {
                        VStack(spacing: 12) {
                            // Assessment Information at top
                            assessmentInfoCard
                            
                            // Legend
                            legendView
                            
                            // Incomplete Assessment Warning
                            if viewModel.pendingCount > 0 && (viewModel.acceptableCount > 0 || viewModel.unacceptableCount > 0 || viewModel.naCount > 0) {
                                incompleteWarning
                            }
                            
                            // Section cards
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.sections) { section in
                                    sectionCard(section)
                                }
                            }
                            
                            // Bottom spacing
                            Color.clear.frame(height: 100)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    
                    // Bottom action bar
                    bottomBar
                }
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showImagePicker) {
                if let itemId = activePhotoItemId {
                    CroppingImagePicker { croppedImage in
                        if let image = croppedImage {
                            viewModel.addPhotos(for: itemId, images: [image])
                        }
                    }
                }
            }
            .overlay {
                if showFullScreenPhoto, let image = fullScreenImage {
                    FullScreenPhotoView(image: image, isPresented: $showFullScreenPhoto)
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
            .overlay {
                if viewModel.showSignatureFlow {
                    SubmissionSignatureFlowView(viewModel: viewModel, isPresented: $viewModel.showSignatureFlow)
                        .transition(.move(edge: .bottom))
                        .zIndex(99)
                }
            }
            .alert("Delete Photo", isPresented: $showDeletePhotoAlert) {
                Button("Cancel", role: .cancel) {
                    photoToDeleteItemId = nil
                    photoToDeleteIndex = nil
                }
                Button("Delete", role: .destructive) {
                    if let itemId = photoToDeleteItemId, let index = photoToDeleteIndex {
                        viewModel.removePhoto(for: itemId, at: index)
                    }
                    photoToDeleteItemId = nil
                    photoToDeleteIndex = nil
                }
            } message: {
                Text("Are you sure you want to delete this photo? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    Task {
                        await viewModel.saveOnDismiss()
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Assessments")
                            .font(.system(size: 17))
                    }
                    .foregroundColor(.accentColor)
                }
                
                Spacer()
                
                // Completion percentage
                Text("\(Int(viewModel.completionPercentage))%")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(viewModel.completionPercentage >= 100 ? Color(hex: "10B981") : AppColors.textSecondary)
                
                // More options menu
                Menu {
                    // Stats section
                    Section("Statistics") {
                        Label("\(viewModel.acceptableCount) Acceptable", systemImage: "checkmark.circle")
                        Label("\(viewModel.unacceptableCount) Unacceptable", systemImage: "xmark.circle")
                        Label("\(viewModel.naCount) Not Applicable", systemImage: "minus.circle")
                    }
                    
                    Section {
                        Button {
                            if viewModel.expandedSections.count == viewModel.sections.count {
                                viewModel.expandedSections = []
                            } else {
                                viewModel.expandedSections = Set(viewModel.sections.map { $0.id })
                            }
                        } label: {
                            if viewModel.expandedSections.count == viewModel.sections.count {
                                Label("Collapse All Sections", systemImage: "rectangle.compress.vertical")
                            } else {
                                Label("Expand All Sections", systemImage: "rectangle.expand.vertical")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 22))
                        .foregroundColor(.accentColor)
                }
            }
            
            // Auto-save indicator
            HStack(spacing: 6) {
                // Auto-save toggle
                Toggle(isOn: $viewModel.isAutoSaveEnabled) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.isAutoSaveEnabled ? Color(hex: "10B981") : .gray)
                            .frame(width: 8, height: 8)
                        Text("Auto Save")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(viewModel.isAutoSaveEnabled ? Color(hex: "10B981") : AppColors.textTertiary)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .toggleStyle(.switch)
                .scaleEffect(0.75)
                .fixedSize()
                
                Spacer()
                
                if viewModel.isAutoSaving {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("saving changes...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.orange)
                    }
                } else if let lastSaved = viewModel.lastAutoSaved {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "10B981"))
                        Text("Saved \(lastSaved, style: .relative) ago")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppColors.surface)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
    
    // MARK: - Section Card
    
    private func sectionCard(_ section: AssessmentTemplate.Section) -> some View {
        let isExpanded = viewModel.expandedSections.contains(section.id)
        let sectionStats = sectionStatistics(section)
        
        return VStack(spacing: 0) {
            // Section header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.toggleSection(section.id)
                }
            } label: {
                HStack(spacing: 12) {
                    // Section icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(sectionIconColor(section.id).opacity(0.15))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: section.iconName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(sectionIconColor(section.id))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("\(sectionStats.completed)/\(sectionStats.total) items")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(
                                sectionStats.completed == sectionStats.total
                                    ? Color(hex: "10B981")
                                    : sectionStats.completed == 0
                                        ? Color(hex: "EF4444")
                                        : Color(hex: "3B82F6")
                            )
                    }
                    
                    Spacer()
                    
                    // Issues Found badge
                    if viewModel.sectionHasIssues(section) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text("Issues Found")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "EF4444"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "FEE2E2").opacity(colorScheme == .dark ? 0.3 : 1.0))
                        .clipShape(Capsule())
                    }
                    
                    // Section completion status icon
                    if sectionStats.total > 0 && sectionStats.completed == sectionStats.total {
                        if sectionHasMissingWorkOrderDetails(section) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "F59E0B"))
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "10B981"))
                        }
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expanded items
            if isExpanded {
                Divider()
                    .padding(.horizontal, 14)
                
                VStack(spacing: 0) {
                    ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                        assessmentItemView(section: section, item: item, index: index)
                        
                        if index < section.items.count - 1 {
                            Divider()
                                .padding(.horizontal, 14)
                        }
                    }
                }
            }
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }
    
    // MARK: - Assessment Item View
    
    private func assessmentItemView(section: AssessmentTemplate.Section, item: AssessmentTemplate.Item, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.description)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Dynamic entries (for lockout-5, lockout-6, mg-7, eap-1)
            if let entries = item.dynamicEntries {
                dynamicEntriesView(section: section, item: item, entries: entries)
            }
            
            // Status buttons
            HStack(spacing: 8) {
                statusButton(
                    label: "Acceptable",
                    icon: "checkmark.circle.fill",
                    color: Color(hex: "10B981"),
                    isSelected: item.status == .acceptable,
                    action: { viewModel.updateItemStatus(sectionId: section.id, itemId: item.id, newStatus: .acceptable) }
                )
                
                statusButton(
                    label: "Unacceptable",
                    icon: "xmark.circle.fill",
                    color: Color(hex: "EF4444"),
                    isSelected: item.status == .unacceptable,
                    action: { viewModel.updateItemStatus(sectionId: section.id, itemId: item.id, newStatus: .unacceptable) }
                )
                
                statusButton(
                    label: "N/A",
                    icon: "minus.circle.fill",
                    color: .gray,
                    isSelected: item.status == .notApplicable,
                    action: { viewModel.updateItemStatus(sectionId: section.id, itemId: item.id, newStatus: .notApplicable) }
                )
                
                Spacer()
            }
            
            // Unacceptable details
            if item.status == .unacceptable {
                unacceptableDetailsView(section: section, item: item)
                
                // Work order required section
                if viewModel.itemRequiresWorkOrder(item.id) {
                    workOrderSection(section: section, item: item)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
    
    // MARK: - Status Button
    
    private func statusButton(label: String, icon: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? color : color.opacity(0.08))
            .foregroundColor(isSelected ? .white : color)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Unacceptable Details
    
    private func unacceptableDetailsView(section: AssessmentTemplate.Section, item: AssessmentTemplate.Item) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Deficiency
            VStack(alignment: .leading, spacing: 4) {
                Text("Deficiency Found")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                
                TextField("Describe any deficiency found...", text: Binding(
                    get: { item.deficiency },
                    set: { viewModel.updateDeficiency(sectionId: section.id, itemId: item.id, deficiency: $0) }
                ), axis: .vertical)
                .font(.system(size: 13))
                .padding(10)
                .background(AppColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .lineLimit(2...5)
            }
            
            // Corrective Action
            VStack(alignment: .leading, spacing: 4) {
                Text("Corrective Action")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                
                TextField("Describe corrective action taken...", text: Binding(
                    get: { item.correctiveAction },
                    set: { viewModel.updateCorrectiveAction(sectionId: section.id, itemId: item.id, action: $0) }
                ), axis: .vertical)
                .font(.system(size: 13))
                .padding(10)
                .background(AppColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .lineLimit(2...5)
            }
            
            // Photo Attachments
            photoAttachmentsView(itemId: item.id)
        }
        .padding(10)
        .background(Color(hex: "FEE2E2").opacity(colorScheme == .dark ? 0.15 : 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Photo Attachments
    
    private func photoAttachmentsView(itemId: String) -> some View {
        let photos = viewModel.itemPhotos[itemId] ?? []
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
                Text("Photo Attachments (Optional)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            
            // Photo thumbnails
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { index, attachment in
                            ZStack(alignment: .topTrailing) {
                                if let image = attachment.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .onTapGesture {
                                            fullScreenImage = image
                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                showFullScreenPhoto = true
                                            }
                                        }
                                } else if attachment.fileUrl != nil {
                                    // Photo is loading from server
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(AppColors.surfaceSecondary)
                                            .frame(width: 72, height: 72)
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                                
                                // Upload status overlay
                                if attachment.isUploading {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.black.opacity(0.4))
                                            .frame(width: 72, height: 72)
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.8)
                                    }
                                }
                                
                                // Delete button
                                if !attachment.isUploading {
                                    Button {
                                        photoToDeleteItemId = itemId
                                        photoToDeleteIndex = index
                                        showDeletePhotoAlert = true
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.white)
                                            .shadow(radius: 2)
                                    }
                                    .offset(x: 4, y: -4)
                                }
                                
                                // Error indicator
                                if attachment.uploadError != nil {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.orange)
                                        .offset(x: -4, y: -4)
                                }
                            }
                        }
                    }
                }
            }
            
            // Add Photos button (opens picker with cropping)
            Button {
                activePhotoItemId = itemId
                showImagePicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text("Add Photos")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(AppColors.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppColors.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            if photos.isEmpty {
                Text("Click to upload photos as evidence")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
    }
    
    // MARK: - Work Order Section
    
    private func workOrderSection(section: AssessmentTemplate.Section, item: AssessmentTemplate.Item) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Work order required banner
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "EF4444"))
                Text("Work order required")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "EF4444"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "FEE2E2").opacity(colorScheme == .dark ? 0.2 : 0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Work order placed checkbox
            Button {
                viewModel.updateWorkOrderPlaced(sectionId: section.id, itemId: item.id, placed: !item.workOrderPlaced)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: item.workOrderPlaced ? "checkmark.square.fill" : "square")
                        .font(.system(size: 18))
                        .foregroundColor(item.workOrderPlaced ? Color(hex: "10B981") : AppColors.textTertiary)
                    Text("Work order placed?")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                }
            }
            .buttonStyle(.plain)
            
            // Work order details (shown when placed)
            if item.workOrderPlaced {
                VStack(alignment: .leading, spacing: 10) {
                    // Reported via Safety App checkbox
                    Button {
                        viewModel.updateReportedViaSafetyApp(sectionId: section.id, itemId: item.id, reported: !item.reportedViaSafetyApp)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: item.reportedViaSafetyApp ? "checkmark.square.fill" : "square")
                                .font(.system(size: 16))
                                .foregroundColor(item.reportedViaSafetyApp ? AppColors.primary : AppColors.textTertiary)
                            HStack(spacing: 4) {
                                Image(systemName: "iphone")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.primary)
                                Text("Deficiency reported using the Safety App")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppColors.textPrimary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    if item.reportedViaSafetyApp {
                        // Date reported field
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 2) {
                                Text("Date reported")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                                Text("*")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(hex: "EF4444"))
                            }
                            
                            DatePicker(
                                "",
                                selection: dateBinding(
                                    get: { item.safetyAppReportDate },
                                    set: { viewModel.updateSafetyAppReportDate(sectionId: section.id, itemId: item.id, date: $0) }
                                ),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .font(.system(size: 13))
                            .padding(6)
                            .background(AppColors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    } else {
                        // Standard work order fields
                        VStack(alignment: .leading, spacing: 10) {
                            // Date created & Assigned to
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 2) {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 11))
                                            .foregroundColor(AppColors.textTertiary)
                                        Text("Date created")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(AppColors.textSecondary)
                                        Text("*")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(Color(hex: "EF4444"))
                                    }
                                    
                                    DatePicker(
                                        "",
                                        selection: dateBinding(
                                            get: { item.workOrderDateCreated },
                                            set: { viewModel.updateWorkOrderDateCreated(sectionId: section.id, itemId: item.id, date: $0) }
                                        ),
                                        displayedComponents: .date
                                    )
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .font(.system(size: 13))
                                    .padding(6)
                                    .background(AppColors.surfaceSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 2) {
                                        Image(systemName: "person")
                                            .font(.system(size: 11))
                                            .foregroundColor(AppColors.textTertiary)
                                        Text("Assigned to")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                    
                                    TextField("Enter assignee name...", text: Binding(
                                        get: { item.workOrderAssignedTo ?? "" },
                                        set: { viewModel.updateWorkOrderAssignedTo(sectionId: section.id, itemId: item.id, assignee: $0) }
                                    ))
                                    .font(.system(size: 13))
                                    .padding(10)
                                    .background(AppColors.surfaceSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .padding(10)
                        .background(AppColors.surfaceSecondary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
    
    // MARK: - Dynamic Entries
    
    private func dynamicEntriesView(section: AssessmentTemplate.Section, item: AssessmentTemplate.Item, entries: [DynamicEntry]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(entries) { entry in
                HStack(spacing: 8) {
                    if entry.employeeName != nil {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Employee Name")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.textTertiary)
                            TextField("Employee name", text: Binding(
                                get: { entry.employeeName ?? "" },
                                set: { viewModel.updateDynamicEntry(sectionId: section.id, itemId: item.id, entryId: entry.id, employeeName: $0) }
                            ))
                            .font(.system(size: 13))
                            .padding(8)
                            .background(AppColors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    
                    if entry.equipmentName != nil {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Equipment Name")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.textTertiary)
                            TextField("Equipment name", text: Binding(
                                get: { entry.equipmentName ?? "" },
                                set: { viewModel.updateDynamicEntry(sectionId: section.id, itemId: item.id, entryId: entry.id, equipmentName: $0) }
                            ))
                            .font(.system(size: 13))
                            .padding(8)
                            .background(AppColors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    
                    if entries.count > 1 {
                        Button {
                            viewModel.removeDynamicEntry(sectionId: section.id, itemId: item.id, entryId: entry.id)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.error)
                        }
                        .padding(.top, 14)
                    }
                }
            }
            
            Button {
                viewModel.addDynamicEntry(sectionId: section.id, itemId: item.id)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                    Text("Add Entry")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(AppColors.primary)
            }
        }
        .padding(8)
        .background(AppColors.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Save Draft Button (hidden when auto-save is on)
                if !viewModel.isAutoSaveEnabled {
                    Button {
                        Task {
                            await viewModel.saveDraft()
                            showDraftSavedFeedback = true
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            showDraftSavedFeedback = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.isSaving {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(AppColors.textPrimary)
                            } else if showDraftSavedFeedback {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "10B981"))
                            } else {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 14))
                            }
                            Text(showDraftSavedFeedback ? "Saved!" : "Save Draft")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(showDraftSavedFeedback ? Color(hex: "10B981") : AppColors.textPrimary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(showDraftSavedFeedback ? Color(hex: "10B981").opacity(0.1) : AppColors.surface)
                        .foregroundColor(AppColors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(showDraftSavedFeedback ? Color(hex: "10B981") : AppColors.border, lineWidth: 1)
                        )
                        .animation(.easeInOut(duration: 0.3), value: showDraftSavedFeedback)
                    }
                    .disabled(viewModel.isSaving || viewModel.isSubmitting)
                }
                
                // Submit Button
                Button {
                    Task { await viewModel.submitAssessment() }
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 14))
                        }
                        Text("Submit")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        viewModel.canSubmit
                        ? LinearGradient(colors: [Color(hex: "10B981"), Color(hex: "059669")], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(!viewModel.canSubmit || viewModel.isSubmitting || viewModel.isSaving)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColors.surface)
        }
    }
    
    // MARK: - Assessment Info Card
    
    private var assessmentInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section title
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .foregroundColor(AppColors.primary)
                Text("Assessment Information")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            // Fields grid
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    infoField(label: "Assessment No.", value: viewModel.assessmentNumber)
                    infoField(label: "Version", value: viewModel.version)
                }
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Date")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                        
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(AppColors.textTertiary)
                                .font(.system(size: 14))
                            Text(viewModel.assessmentDate, style: .date)
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppColors.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Department picker
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 2) {
                            Text("Department Audited")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                            Text("*")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.red)
                        }
                        
                        Menu {
                            Button("None") {
                                viewModel.selectedDepartmentId = nil
                            }
                            ForEach(viewModel.departments, id: \.id) { dept in
                                Button(dept.name) {
                                    viewModel.selectedDepartmentId = dept.id
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "building.2")
                                    .foregroundColor(AppColors.textTertiary)
                                    .font(.system(size: 14))
                                Text(selectedDepartmentName)
                                    .font(.system(size: 14))
                                    .foregroundColor(viewModel.selectedDepartmentId == nil ? AppColors.textTertiary : AppColors.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppColors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                HStack(spacing: 12) {
                    infoField(label: "Team Leader", value: viewModel.teamLeaderName)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 2) {
                            Text("Employee")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                            Text("*")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.red)
                        }
                        
                        TextField("Enter employee name", text: $viewModel.employeeName)
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppColors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Status
                HStack {
                    Text("Status")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                    
                    statusBadge(viewModel.status)
                    
                    Spacer()
                    
                    // Completion stats
                    HStack(spacing: 16) {
                        statPill(count: viewModel.acceptableCount, label: "A", color: Color(hex: "10B981"))
                        statPill(count: viewModel.unacceptableCount, label: "U", color: Color(hex: "EF4444"))
                        statPill(count: viewModel.naCount, label: "NA", color: .gray)
                    }
                }
            }
        }
        .padding(16)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
    
    // MARK: - Legend
    
    private var legendView: some View {
        HStack(spacing: 20) {
            Text("Legend:")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            
            legendItem(color: Color(hex: "10B981"), text: "A = Acceptable")
            legendItem(color: Color(hex: "EF4444"), text: "U = Unacceptable")
            legendItem(color: .gray, text: "NA = Not Applicable")
        }
    }
    
    // MARK: - Incomplete Warning
    
    private var incompleteWarning: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Color(hex: "F59E0B"))
                Text("Incomplete Assessment - \(viewModel.pendingCount) items remaining")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "92400E"))
            }
            
            ForEach(viewModel.incompleteSections, id: \.section.id) { info in
                HStack(spacing: 4) {
                    Text(info.section.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "D97706"))
                    Text("(\(info.pendingCount) items not assessed)")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "B45309"))
                }
                .padding(.leading, 28)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "FEF3C7").opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Info Field Helpers
    
    private func infoField(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
            
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func statusBadge(_ status: WSAStatus) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 6, height: 6)
            Text(status.rawValue)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(statusColor(status).opacity(0.15))
        .clipShape(Capsule())
    }
    
    private func statusColor(_ status: WSAStatus) -> Color {
        switch status {
        case .draft: return Color(hex: "F59E0B")
        case .submitted: return AppColors.primary
        case .completed: return AppColors.success
        }
    }
    
    private func statPill(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 13, weight: .bold))
            Text(label)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color)
        .clipShape(Capsule())
    }
    
    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    private var selectedDepartmentName: String {
        if let id = viewModel.selectedDepartmentId,
           let dept = viewModel.departments.first(where: { $0.id == id }) {
            return dept.name
        }
        return "Select department"
    }
    
    // MARK: - Helpers
    
    private func sectionStatistics(_ section: AssessmentTemplate.Section) -> (total: Int, completed: Int) {
        let total = section.items.count
        let completed = section.items.filter { $0.status != nil }.count
        return (total, completed)
    }
    
    /// Check if a fully-completed section still has missing work order details
    /// (e.g. work order checkbox not checked, or work order date not filled)
    private func sectionHasMissingWorkOrderDetails(_ section: AssessmentTemplate.Section) -> Bool {
        for item in section.items {
            guard item.status == .unacceptable else { continue }
            guard viewModel.itemRequiresWorkOrder(item.id) else { continue }
            
            // Work order required but not placed
            if !item.workOrderPlaced {
                return true
            }
            
            // Work order placed — check required details
            if item.reportedViaSafetyApp {
                // Must have a report date
                if (item.safetyAppReportDate ?? "").isEmpty {
                    return true
                }
            } else {
                // Must have date created and assigned to
                if (item.workOrderDateCreated ?? "").isEmpty {
                    return true
                }
                if (item.workOrderAssignedTo ?? "").isEmpty {
                    return true
                }
            }
        }
        return false
    }
    
    // MARK: - Date Binding Helper
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd/yyyy"
        return f
    }()
    
    /// Converts a String? date ("MM/dd/yyyy") ↔ Date for use with DatePicker
    private func dateBinding(get: @escaping () -> String?, set: @escaping (String) -> Void) -> Binding<Date> {
        Binding<Date>(
            get: {
                if let str = get(), let date = Self.dateFormatter.date(from: str) {
                    return date
                }
                return Date()
            },
            set: { newDate in
                set(Self.dateFormatter.string(from: newDate))
            }
        )
    }
    
    private func sectionIconColor(_ sectionId: String) -> Color {
        switch sectionId {
        case "ppe": return Color(hex: "6366F1")            // Indigo
        case "lockout": return Color(hex: "EF4444")          // Red
        case "machine-guarding": return Color(hex: "8B5CF6") // Purple
        case "electrical": return Color(hex: "F59E0B")       // Amber
        case "material-handling": return Color(hex: "06B6D4") // Cyan
        case "fall-protection": return Color(hex: "3B82F6")  // Blue
        case "labeling": return Color(hex: "10B981")         // Emerald
        case "housekeeping": return Color(hex: "EC4899")     // Pink
        case "emergency-action": return Color(hex: "F97316") // Orange
        default: return AppColors.primary
        }
    }
    
    private func miniStatPill(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 11, weight: .bold))
            Text(label)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color)
        .clipShape(Capsule())
    }
}

// MARK: - Cropping Image Picker (UIImagePickerController with allowsEditing)

struct CroppingImagePicker: UIViewControllerRepresentable {
    var onImagePicked: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onImagePicked: (UIImage?) -> Void
        var dismiss: DismissAction
        
        init(onImagePicked: @escaping (UIImage?) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            // Prefer the edited (cropped) image, fall back to original
            let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage
            onImagePicked(image)
            dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImagePicked(nil)
            dismiss()
        }
    }
}

// MARK: - Full Screen Photo Viewer

struct FullScreenPhotoView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { value in
                            lastScale = scale
                            if scale < 1.0 {
                                withAnimation(.spring()) {
                                    scale = 1.0
                                    lastScale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                        }
                        .simultaneously(with:
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring()) {
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
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.85))
                            .shadow(radius: 4)
                    }
                    .padding(20)
                }
                Spacer()
            }
        }
        .statusBarHidden(true)
    }
}
