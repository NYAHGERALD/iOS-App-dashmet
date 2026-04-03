import Foundation
import SwiftUI
import PhotosUI
import Combine

// MARK: - Photo Attachment Model
struct PhotoAttachment: Identifiable {
    let id: String // local UUID or server photo ID
    var image: UIImage?  // local image (may be nil for server-loaded photos)
    var fileUrl: String?  // Firebase download URL
    var serverPhotoId: String?  // WSAPhoto ID from backend
    var isUploading: Bool = false
    var isUploaded: Bool = false
    var uploadError: String?
}

@MainActor
class SafetyAssessmentViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    // List view state
    @Published var assessments: [SafetyAssessment] = []
    @Published var isLoadingList = false
    @Published var listError: String?
    
    // Assessment form state
    @Published var sections: [AssessmentTemplate.Section] = []
    @Published var assessmentId: String?
    @Published var assessmentNumber: String = ""
    @Published var version: String = "3/19/25"
    @Published var assessmentDate: Date = Date()
    @Published var selectedDepartmentId: String?
    @Published var teamLeaderName: String = ""
    @Published var employeeName: String = ""
    @Published var status: WSAStatus = .draft
    
    // Departments
    @Published var departments: [DepartmentInfo] = []
    
    // Photo attachments keyed by item ID
    var itemPhotos: [String: [PhotoAttachment]] = [:] {
        willSet { objectWillChange.send() }
    }
    // Queue of photos waiting for assessment ID before saving to backend
    private var pendingPhotoUploads: [(itemId: String, sectionId: String?, fileName: String, fileUrl: String, fileSize: Int?, localId: String)] = []
    @Published var activePhotoPickerItemId: String?
    @Published var selectedPhotoItems: [PhotosPickerItem] = []
    
    // UI State
    @Published var expandedSections: Set<String> = []
    @Published var isAutoSaveEnabled = true
    @Published var isAutoSaving = false
    @Published var lastAutoSaved: Date?
    @Published var isSaving = false
    @Published var isSubmitting = false
    @Published var isLoadingDraft = false
    @Published var showNewAssessment = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showSignatureFlow = false
    @Published var activeTab: AssessmentTab = .newAssessment
    
    enum AssessmentTab {
        case newAssessment
        case history
    }
    
    // MARK: - Private Properties
    
    private var autoSaveTask: Task<Void, Never>?
    private var hasUserMadeChanges = false
    private var isInitialLoad = true
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var totalItems: Int {
        sections.reduce(0) { $0 + $1.items.count }
    }
    
    var acceptableCount: Int {
        sections.reduce(0) { sum, section in
            sum + section.items.filter { $0.status == .acceptable }.count
        }
    }
    
    var unacceptableCount: Int {
        sections.reduce(0) { sum, section in
            sum + section.items.filter { $0.status == .unacceptable }.count
        }
    }
    
    var naCount: Int {
        sections.reduce(0) { sum, section in
            sum + section.items.filter { $0.status == .notApplicable }.count
        }
    }
    
    var pendingCount: Int {
        totalItems - acceptableCount - unacceptableCount - naCount
    }
    
    var completionPercentage: Double {
        guard totalItems > 0 else { return 0 }
        return Double(totalItems - pendingCount) / Double(totalItems) * 100
    }
    
    var incompleteSections: [(section: AssessmentTemplate.Section, pendingCount: Int)] {
        sections.compactMap { section in
            let pending = section.items.filter { $0.status == nil }.count
            return pending > 0 ? (section, pending) : nil
        }
    }
    
    var canSubmit: Bool {
        pendingCount == 0 && totalItems > 0 && assessmentId != nil && selectedDepartmentId != nil && !employeeName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    func sectionHasIssues(_ section: AssessmentTemplate.Section) -> Bool {
        section.items.contains { $0.status == .unacceptable }
    }
    
    // Items that require work orders when marked as Unacceptable
    // Work order is only required for items that need PHYSICAL REPAIR, INSTALLATION, or MAINTENANCE
    static let workOrderRequiredItems: Set<String> = [
        "lockout-4", "lockout-6",
        "mg-1", "mg-2", "mg-3", "mg-4", "mg-5", "mg-6", "mg-7",
        "elec-1", "elec-2", "elec-3",
        "mh-6",
        "fp-1", "fp-2", "fp-3",
        "lbl-1", "lbl-2", "lbl-3", "lbl-4",
        "hk-2", "hk-4", "hk-7",
    ]
    
    func itemRequiresWorkOrder(_ itemId: String) -> Bool {
        Self.workOrderRequiredItems.contains(itemId)
    }
    
    // MARK: - Photo Management
    
    /// Add a photo: stores locally, uploads to Firebase, then saves record to backend
    func addPhotos(for itemId: String, images: [UIImage]) {
        for image in images {
            let localId = UUID().uuidString
            var attachment = PhotoAttachment(id: localId, image: image, isUploading: true)
            
            var current = itemPhotos[itemId] ?? []
            current.append(attachment)
            itemPhotos[itemId] = current
            
            // Upload in background
            Task {
                await uploadPhotoToFirebaseAndSave(itemId: itemId, localId: localId, image: image)
            }
        }
        hasUserMadeChanges = true
    }
    
    /// Upload photo to Firebase Storage, then save record to backend
    private func uploadPhotoToFirebaseAndSave(itemId: String, localId: String, image: UIImage) async {
        do {
            // 1. Upload to Firebase Storage
            let fileUrl = try await FirebaseStorageService.shared.uploadSafetyPhoto(
                image,
                assessmentNumber: assessmentNumber,
                itemId: itemId
            )
            
            let fileSize = image.jpegData(compressionQuality: 0.8)?.count
            
            // 2. Save record to backend (if assessment has an ID)
            if let assessmentId = assessmentId {
                let response = try await APIService.shared.addPhotoToAssessment(
                    assessmentId: assessmentId,
                    fileName: "\(localId).jpg",
                    fileUrl: fileUrl,
                    fileSize: fileSize,
                    mimeType: "image/jpeg",
                    itemId: itemId,
                    sectionId: findSectionId(for: itemId)
                )
                
                // Update local attachment with server info
                updatePhotoAttachment(itemId: itemId, localId: localId) { attachment in
                    attachment.fileUrl = fileUrl
                    attachment.serverPhotoId = response.data.photo.id
                    attachment.isUploading = false
                    attachment.isUploaded = true
                }
                print("✅ Photo uploaded and saved: \(response.data.photo.id)")
            } else {
                // Queue for later when assessment gets an ID
                let sectionId = findSectionId(for: itemId)
                pendingPhotoUploads.append((
                    itemId: itemId,
                    sectionId: sectionId,
                    fileName: "\(localId).jpg",
                    fileUrl: fileUrl,
                    fileSize: fileSize,
                    localId: localId
                ))
                
                updatePhotoAttachment(itemId: itemId, localId: localId) { attachment in
                    attachment.fileUrl = fileUrl
                    attachment.isUploading = false
                    attachment.isUploaded = true
                }
                print("📸 Photo uploaded to Firebase, queued for backend save (no assessment ID yet)")
            }
        } catch {
            print("❌ Photo upload failed: \(error.localizedDescription)")
            updatePhotoAttachment(itemId: itemId, localId: localId) { attachment in
                attachment.isUploading = false
                attachment.uploadError = error.localizedDescription
            }
        }
    }
    
    /// Sync pending photos after assessment gets an ID
    func syncPendingPhotos() async {
        guard let assessmentId = assessmentId, !pendingPhotoUploads.isEmpty else { return }
        
        let photosToSync = pendingPhotoUploads
        pendingPhotoUploads = []
        
        print("📸 Syncing \(photosToSync.count) pending photos to backend")
        
        for photo in photosToSync {
            do {
                let response = try await APIService.shared.addPhotoToAssessment(
                    assessmentId: assessmentId,
                    fileName: photo.fileName,
                    fileUrl: photo.fileUrl,
                    fileSize: photo.fileSize,
                    mimeType: "image/jpeg",
                    itemId: photo.itemId,
                    sectionId: photo.sectionId
                )
                
                updatePhotoAttachment(itemId: photo.itemId, localId: photo.localId) { attachment in
                    attachment.serverPhotoId = response.data.photo.id
                }
                print("✅ Pending photo synced: \(response.data.photo.id)")
            } catch {
                print("❌ Failed to sync pending photo: \(error)")
            }
        }
    }
    
    private func updatePhotoAttachment(itemId: String, localId: String, update: (inout PhotoAttachment) -> Void) {
        guard var photos = itemPhotos[itemId],
              let idx = photos.firstIndex(where: { $0.id == localId }) else { return }
        update(&photos[idx])
        itemPhotos[itemId] = photos
    }
    
    private func findSectionId(for itemId: String) -> String? {
        for section in sections {
            if section.items.contains(where: { $0.id == itemId }) {
                return section.id
            }
        }
        return nil
    }
    
    func removePhoto(for itemId: String, at index: Int) {
        guard var current = itemPhotos[itemId], index < current.count else { return }
        let attachment = current[index]
        
        // Delete from backend if it has a server ID
        if let serverPhotoId = attachment.serverPhotoId, let assessmentId = assessmentId {
            Task {
                do {
                    try await APIService.shared.deletePhotoFromAssessment(
                        assessmentId: assessmentId,
                        photoId: serverPhotoId
                    )
                    print("✅ Photo deleted from server: \(serverPhotoId)")
                } catch {
                    print("❌ Failed to delete photo from server: \(error)")
                }
            }
        }
        
        current.remove(at: index)
        itemPhotos[itemId] = current
        hasUserMadeChanges = true
    }
    
    func processPickedPhotos(_ items: [PhotosPickerItem], for itemId: String) async {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        if !images.isEmpty {
            addPhotos(for: itemId, images: images)
        }
        selectedPhotoItems = []
    }
    
    // MARK: - Initialization
    
    func configure(teamLeader: String) async {
        self.teamLeaderName = teamLeader
        setupAutoSaveObservers()
        if sections.isEmpty {
            resetToNewAssessment()
            // Try to load the most recent draft from the server
            await loadLatestDraft()
        }
        // Ensure isInitialLoad is cleared so Combine observers can trigger auto-save
        isInitialLoad = false
    }
    
    /// Observe changes to department, employee, and date fields to trigger auto-save
    private func setupAutoSaveObservers() {
        // Cancel any existing observers to avoid duplicates
        cancellables.removeAll()
        
        $selectedDepartmentId
            .dropFirst() // skip initial value
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self, !self.isInitialLoad else { return }
                self.triggerAutoSave()
            }
            .store(in: &cancellables)
        
        $employeeName
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self, !self.isInitialLoad else { return }
                self.triggerAutoSave()
            }
            .store(in: &cancellables)
        
        $assessmentDate
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self, !self.isInitialLoad else { return }
                self.triggerAutoSave()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Assessment List
    
    func fetchAssessments() async {
        isLoadingList = true
        listError = nil
        
        do {
            let response = try await APIService.shared.getWorkplaceSafetyAssessments()
            assessments = response.data.assessments
        } catch {
            listError = error.localizedDescription
            print("❌ Failed to fetch assessments: \(error)")
        }
        
        isLoadingList = false
    }
    
    // MARK: - Month Limit Check
    
    /// Returns the existing assessment for the current month if one was created by this user, nil otherwise.
    func existingAssessmentForCurrentMonth(userId: String) -> SafetyAssessment? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMM"
        let currentMonthStr = dateFormatter.string(from: Date())
        let prefix = "WSA-\(currentMonthStr)-"
        
        // Get user initials from teamLeaderName
        let initials = teamLeaderName
            .split(separator: " ")
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()
        
        return assessments.first { assessment in
            // Match by createdById AND current month prefix AND user initials suffix
            let matchesUser = assessment.createdById == userId
            let matchesMonth = assessment.assessmentNumber.hasPrefix(prefix)
            let matchesInitials = initials.isEmpty || assessment.assessmentNumber.hasSuffix("-\(initials)")
            return matchesUser && matchesMonth && matchesInitials
        }
    }
    
    // MARK: - New Assessment
    
    func resetToNewAssessment() {
        // Set isInitialLoad FIRST to block Combine observers during property changes
        isInitialLoad = true
        autoSaveTask?.cancel()
        autoSaveTask = nil
        
        sections = AssessmentTemplate.defaultSections()
        assessmentId = nil
        status = .draft
        assessmentDate = Date()
        employeeName = ""
        selectedDepartmentId = nil
        expandedSections = []
        hasUserMadeChanges = false
        lastAutoSaved = nil
        itemPhotos = [:]
        pendingPhotoUploads = []
        
        // Generate unique assessment number
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMM"
        let dateStr = dateFormatter.string(from: Date())
        
        // Add user initials if available
        let initials = teamLeaderName
            .split(separator: " ")
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()
        
        // Find next sequence number based on existing assessments this month
        let prefix = "WSA-\(dateStr)-"
        let existingNumbers = assessments
            .map { $0.assessmentNumber }
            .filter { $0.hasPrefix(prefix) }
            .compactMap { number -> Int? in
                // Extract sequence from WSA-YYYYMM-XXX-INITIALS
                let parts = number.dropFirst(prefix.count).split(separator: "-")
                return parts.first.flatMap { Int($0) }
            }
        let nextSeq = (existingNumbers.max() ?? 0) + 1
        let seqStr = String(format: "%03d", nextSeq)
        
        assessmentNumber = "\(prefix)\(seqStr)-\(initials)"
        
        // Clear isInitialLoad so Combine observers can trigger auto-save for user changes
        isInitialLoad = false
    }
    
    // MARK: - Load Latest Draft
    
    /// Automatically loads the most recent DRAFT assessment if one exists
    func loadLatestDraft() async {
        do {
            let response = try await APIService.shared.getWorkplaceSafetyAssessments()
            assessments = response.data.assessments
            
            // Find the most recent DRAFT assessment
            if let latestDraft = response.data.assessments.first(where: { $0.status == .draft }) {
                print("📋 Found existing draft: \(latestDraft.assessmentNumber) (\(latestDraft.id)), loading full data...")
                // Load the full assessment with sections and items
                await loadAssessmentById(id: latestDraft.id)
            } else {
                print("ℹ️ No existing drafts found, starting fresh")
            }
        } catch {
            print("ℹ️ Could not check for drafts: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Load Existing Draft
    
    func loadDraft(assessmentNumber: String) async {
        isLoadingDraft = true
        errorMessage = nil
        isInitialLoad = true
        
        do {
            let response = try await APIService.shared.getWorkplaceSafetyDraft(assessmentNumber: assessmentNumber)
            let assessment = response.data.assessment
            
            populateFromAssessment(assessment)
        } catch {
            // No draft found - that's OK for new assessments
            print("ℹ️ No existing draft: \(error.localizedDescription)")
        }
        
        isInitialLoad = false
        isLoadingDraft = false
    }
    
    func loadAssessmentById(id: String) async {
        isLoadingDraft = true
        errorMessage = nil
        isInitialLoad = true
        autoSaveTask?.cancel()
        autoSaveTask = nil
        
        do {
            let response = try await APIService.shared.getWorkplaceSafetyAssessment(id: id)
            let assessment = response.data.assessment
            
            populateFromAssessment(assessment)
            hasUserMadeChanges = false
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to load assessment: \(error)")
        }
        
        isInitialLoad = false
        isLoadingDraft = false
    }
    
    private func populateFromAssessment(_ assessment: SafetyAssessment) {
        assessmentId = assessment.id
        assessmentNumber = assessment.assessmentNumber
        version = assessment.version
        selectedDepartmentId = assessment.departmentId
        teamLeaderName = assessment.teamLeaderName
        employeeName = assessment.employeeName ?? ""
        status = assessment.status
        
        // Parse date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: assessment.date) {
            assessmentDate = date
        } else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: assessment.date) {
                assessmentDate = date
            }
        }
        
        // Populate sections from backend data
        if let serverSections = assessment.Sections, !serverSections.isEmpty {
            var templateSections = AssessmentTemplate.defaultSections()
            
            for serverSection in serverSections {
                if let idx = templateSections.firstIndex(where: { $0.id == serverSection.sectionId }) {
                    if let serverItems = serverSection.Items {
                        for serverItem in serverItems {
                            if let itemIdx = templateSections[idx].items.firstIndex(where: { $0.id == serverItem.itemId }) {
                                var item = templateSections[idx].items[itemIdx]
                                
                                if let statusStr = serverItem.status {
                                    item.status = ItemAssessmentStatus(rawValue: statusStr)
                                }
                                item.deficiency = serverItem.deficiency ?? ""
                                item.correctiveAction = serverItem.correctiveAction ?? ""
                                item.workOrderPlaced = serverItem.workOrderPlaced ?? false
                                item.reportedViaSafetyApp = serverItem.reportedViaSafetyApp ?? false
                                item.safetyAppReportDate = serverItem.safetyAppReportDate
                                item.workOrderDateCreated = serverItem.workOrderDateCreated
                                item.workOrderAssignedTo = serverItem.workOrderAssignedTo
                                
                                if let entries = serverItem.dynamicEntries {
                                    item.dynamicEntries = entries
                                }
                                
                                templateSections[idx].items[itemIdx] = item
                            }
                        }
                    }
                }
            }
            
            sections = templateSections
        } else {
            sections = AssessmentTemplate.defaultSections()
        }
        
        // Load photos from server response
        itemPhotos = [:]
        if let serverPhotos = assessment.Photos, !serverPhotos.isEmpty {
            for photo in serverPhotos {
                guard let itemId = photo.itemId else { continue }
                let attachment = PhotoAttachment(
                    id: photo.id,
                    image: nil,  // will be loaded async from URL
                    fileUrl: photo.fileUrl,
                    serverPhotoId: photo.id,
                    isUploading: false,
                    isUploaded: true
                )
                var current = itemPhotos[itemId] ?? []
                current.append(attachment)
                itemPhotos[itemId] = current
            }
            
            // Download images from URLs in background
            Task {
                await loadPhotoImages()
            }
        }
    }
    
    /// Download photo images from Firebase URLs for display
    private func loadPhotoImages() async {
        for (itemId, photos) in itemPhotos {
            for (index, photo) in photos.enumerated() {
                guard let urlString = photo.fileUrl,
                      let url = URL(string: urlString),
                      photo.image == nil else { continue }
                
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        var updatedPhotos = itemPhotos[itemId] ?? []
                        if index < updatedPhotos.count {
                            updatedPhotos[index].image = image
                            itemPhotos[itemId] = updatedPhotos
                        }
                    }
                } catch {
                    print("⚠️ Failed to load photo image: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Item Updates (trigger auto-save)
    
    func updateItemStatus(sectionId: String, itemId: String, newStatus: ItemAssessmentStatus) {
        guard let sIdx = sections.firstIndex(where: { $0.id == sectionId }),
              let iIdx = sections[sIdx].items.firstIndex(where: { $0.id == itemId }) else { return }
        
        // Toggle: if same status, clear it
        if sections[sIdx].items[iIdx].status == newStatus {
            sections[sIdx].items[iIdx].status = nil
        } else {
            sections[sIdx].items[iIdx].status = newStatus
        }
        
        triggerAutoSave()
    }
    
    func updateDeficiency(sectionId: String, itemId: String, deficiency: String) {
        guard let sIdx = sections.firstIndex(where: { $0.id == sectionId }),
              let iIdx = sections[sIdx].items.firstIndex(where: { $0.id == itemId }) else { return }
        sections[sIdx].items[iIdx].deficiency = deficiency
        triggerAutoSave()
    }
    
    func updateCorrectiveAction(sectionId: String, itemId: String, action: String) {
        guard let sIdx = sections.firstIndex(where: { $0.id == sectionId }),
              let iIdx = sections[sIdx].items.firstIndex(where: { $0.id == itemId }) else { return }
        sections[sIdx].items[iIdx].correctiveAction = action
        triggerAutoSave()
    }
    
    func updateDynamicEntry(sectionId: String, itemId: String, entryId: String, employeeName: String? = nil, equipmentName: String? = nil) {
        guard let sIdx = sections.firstIndex(where: { $0.id == sectionId }),
              let iIdx = sections[sIdx].items.firstIndex(where: { $0.id == itemId }),
              let entries = sections[sIdx].items[iIdx].dynamicEntries,
              let eIdx = entries.firstIndex(where: { $0.id == entryId }) else { return }
        
        var entry = sections[sIdx].items[iIdx].dynamicEntries![eIdx]
        if let name = employeeName { entry = DynamicEntry(id: entry.id, employeeName: name, equipmentName: entry.equipmentName) }
        if let equip = equipmentName { entry = DynamicEntry(id: entry.id, employeeName: entry.employeeName, equipmentName: equip) }
        sections[sIdx].items[iIdx].dynamicEntries![eIdx] = entry
        triggerAutoSave()
    }
    
    func addDynamicEntry(sectionId: String, itemId: String) {
        guard let sIdx = sections.firstIndex(where: { $0.id == sectionId }),
              let iIdx = sections[sIdx].items.firstIndex(where: { $0.id == itemId }) else { return }
        
        let newEntry = DynamicEntry(
            id: "entry-\(Int(Date().timeIntervalSince1970 * 1000))",
            employeeName: (itemId == "lockout-5" || itemId == "eap-1") ? "" : nil,
            equipmentName: (itemId == "lockout-5" || itemId == "lockout-6" || itemId == "mg-7") ? "" : nil
        )
        
        if sections[sIdx].items[iIdx].dynamicEntries != nil {
            sections[sIdx].items[iIdx].dynamicEntries!.append(newEntry)
        } else {
            sections[sIdx].items[iIdx].dynamicEntries = [newEntry]
        }
        triggerAutoSave()
    }
    
    func removeDynamicEntry(sectionId: String, itemId: String, entryId: String) {
        guard let sIdx = sections.firstIndex(where: { $0.id == sectionId }),
              let iIdx = sections[sIdx].items.firstIndex(where: { $0.id == itemId }) else { return }
        sections[sIdx].items[iIdx].dynamicEntries?.removeAll { $0.id == entryId }
        triggerAutoSave()
    }
    
    // MARK: - Work Order Updates
    
    func updateWorkOrderPlaced(sectionId: String, itemId: String, placed: Bool) {
        guard let sIdx = sections.firstIndex(where: { $0.id == sectionId }),
              let iIdx = sections[sIdx].items.firstIndex(where: { $0.id == itemId }) else { return }
        sections[sIdx].items[iIdx].workOrderPlaced = placed
        if !placed {
            sections[sIdx].items[iIdx].reportedViaSafetyApp = false
            sections[sIdx].items[iIdx].safetyAppReportDate = nil
            sections[sIdx].items[iIdx].workOrderDateCreated = nil
            sections[sIdx].items[iIdx].workOrderAssignedTo = nil
        }
        triggerAutoSave()
    }
    
    func updateReportedViaSafetyApp(sectionId: String, itemId: String, reported: Bool) {
        guard let sIdx = sections.firstIndex(where: { $0.id == sectionId }),
              let iIdx = sections[sIdx].items.firstIndex(where: { $0.id == itemId }) else { return }
        sections[sIdx].items[iIdx].reportedViaSafetyApp = reported
        if reported {
            sections[sIdx].items[iIdx].workOrderDateCreated = nil
            sections[sIdx].items[iIdx].workOrderAssignedTo = nil
        } else {
            sections[sIdx].items[iIdx].safetyAppReportDate = nil
        }
        triggerAutoSave()
    }
    
    func updateSafetyAppReportDate(sectionId: String, itemId: String, date: String) {
        guard let sIdx = sections.firstIndex(where: { $0.id == sectionId }),
              let iIdx = sections[sIdx].items.firstIndex(where: { $0.id == itemId }) else { return }
        sections[sIdx].items[iIdx].safetyAppReportDate = date
        triggerAutoSave()
    }
    
    func updateWorkOrderDateCreated(sectionId: String, itemId: String, date: String) {
        guard let sIdx = sections.firstIndex(where: { $0.id == sectionId }),
              let iIdx = sections[sIdx].items.firstIndex(where: { $0.id == itemId }) else { return }
        sections[sIdx].items[iIdx].workOrderDateCreated = date
        triggerAutoSave()
    }
    
    func updateWorkOrderAssignedTo(sectionId: String, itemId: String, assignee: String) {
        guard let sIdx = sections.firstIndex(where: { $0.id == sectionId }),
              let iIdx = sections[sIdx].items.firstIndex(where: { $0.id == itemId }) else { return }
        sections[sIdx].items[iIdx].workOrderAssignedTo = assignee
        triggerAutoSave()
    }
    
    // MARK: - Section Expansion
    
    func toggleSection(_ sectionId: String) {
        if expandedSections.contains(sectionId) {
            expandedSections.remove(sectionId)
        } else {
            expandedSections.insert(sectionId)
        }
    }
    
    // MARK: - Auto-Save
    
    private func triggerAutoSave() {
        guard isAutoSaveEnabled, status == .draft else { return }
        hasUserMadeChanges = true
        
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 second debounce
            guard !Task.isCancelled else { return }
            await performAutoSave()
        }
    }
    
    /// Immediately save any pending changes (called on dismiss)
    func saveOnDismiss() async {
        // Cancel any pending debounced auto-save
        autoSaveTask?.cancel()
        autoSaveTask = nil
        
        // Force an immediate save if there are unsaved changes
        guard status == .draft, hasUserMadeChanges else { return }
        
        let hasAssessedItems = acceptableCount > 0 || unacceptableCount > 0 || naCount > 0
        let hasInfoEntered = selectedDepartmentId != nil || !employeeName.trimmingCharacters(in: .whitespaces).isEmpty
        guard hasAssessedItems || hasInfoEntered else { return }
        
        isAutoSaving = true
        
        do {
            let payload = buildPayload()
            
            if let existingId = assessmentId {
                let _ = try await APIService.shared.updateWorkplaceSafetyAssessment(id: existingId, payload: payload)
                print("✅ Save-on-dismiss updated: \(existingId)")
            } else {
                let response = try await APIService.shared.saveWorkplaceSafetyAssessment(payload: payload)
                if let newId = response.data.assessment.id as String? {
                    assessmentId = newId
                    print("✅ Save-on-dismiss created: \(newId)")
                    await syncPendingPhotos()
                }
            }
            
            lastAutoSaved = Date()
            hasUserMadeChanges = false
        } catch {
            print("❌ Save-on-dismiss failed: \(error.localizedDescription)")
        }
        
        isAutoSaving = false
    }
    
    func performAutoSave() async {
        guard isAutoSaveEnabled, status == .draft, hasUserMadeChanges else { return }
        
        // Don't save if no data entered at all
        let hasAssessedItems = acceptableCount > 0 || unacceptableCount > 0 || naCount > 0
        let hasInfoEntered = selectedDepartmentId != nil || !employeeName.trimmingCharacters(in: .whitespaces).isEmpty
        if !hasAssessedItems && !hasInfoEntered {
            return
        }
        
        isAutoSaving = true
        
        do {
            let payload = buildPayload()
            
            if let existingId = assessmentId {
                // Update existing
                let response = try await APIService.shared.updateWorkplaceSafetyAssessment(id: existingId, payload: payload)
                print("✅ Auto-save updated: \(existingId)")
                _ = response
            } else {
                // Create new
                let response = try await APIService.shared.saveWorkplaceSafetyAssessment(payload: payload)
                if let newId = response.data.assessment.id as String? {
                    assessmentId = newId
                    print("✅ Auto-save created: \(newId)")
                    // Sync any photos that were uploaded before the assessment had an ID
                    await syncPendingPhotos()
                }
            }
            
            lastAutoSaved = Date()
        } catch {
            print("❌ Auto-save failed: \(error.localizedDescription)")
        }
        
        isAutoSaving = false
    }
    
    // MARK: - Manual Save
    
    func saveDraft() async {
        isSaving = true
        errorMessage = nil
        
        do {
            let payload = buildPayload()
            
            if let existingId = assessmentId {
                let response = try await APIService.shared.updateWorkplaceSafetyAssessment(id: existingId, payload: payload)
                _ = response
            } else {
                let response = try await APIService.shared.saveWorkplaceSafetyAssessment(payload: payload)
                if let newId = response.data.assessment.id as String? {
                    assessmentId = newId
                }
            }
            
            lastAutoSaved = Date()
            successMessage = "Draft saved successfully"
            
            // Clear success after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                successMessage = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSaving = false
    }
    
    // MARK: - Submit
    
    /// Validates the assessment and shows the signature flow if valid
    func submitAssessment() async {
        guard let id = assessmentId else {
            errorMessage = "Please save the assessment first"
            return
        }
        
        guard canSubmit else {
            var issues: [String] = []
            if selectedDepartmentId == nil {
                issues.append("Department Audited is required")
            }
            if employeeName.trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append("Employee is required")
            }
            if pendingCount > 0 {
                issues.append("\(pendingCount) items have not been assessed")
            }
            errorMessage = issues.joined(separator: ". ")
            return
        }
        
        // Save latest changes first before showing signature flow
        do {
            let payload = buildPayload()
            let _ = try await APIService.shared.updateWorkplaceSafetyAssessment(id: id, payload: payload)
        } catch {
            errorMessage = "Failed to save before submit: \(error.localizedDescription)"
            return
        }
        
        // Show signature flow
        showSignatureFlow = true
    }
    
    /// Called from the signature flow after both signatures are captured and uploaded
    func submitAssessmentWithSignatures(employeeSignatureUrl: String, teamLeaderSignatureUrl: String) async {
        guard let id = assessmentId else {
            errorMessage = "Assessment ID not found"
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        do {
            let response = try await APIService.shared.submitWorkplaceSafetyAssessment(
                id: id,
                employeeSignatureUrl: employeeSignatureUrl,
                teamLeaderSignatureUrl: teamLeaderSignatureUrl
            )
            status = response.data.assessment.status
            successMessage = "Assessment submitted successfully!"
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSubmitting = false
    }
    
    // MARK: - Delete
    
    func deleteAssessment(id: String, confirmNumber: String) async -> Bool {
        do {
            try await APIService.shared.deleteWorkplaceSafetyAssessment(id: id, confirmNumber: confirmNumber)
            withAnimation(.easeInOut(duration: 0.3)) {
                assessments.removeAll { $0.id == id }
            }
            return true
        } catch {
            let msg = error.localizedDescription
            print("❌ Delete assessment failed: \(msg)")
            errorMessage = msg
            return false
        }
    }
    
    /// Revert a submitted assessment back to draft for editing
    func editAssessment(id: String) async {
        isInitialLoad = true
        autoSaveTask?.cancel()
        autoSaveTask = nil
        do {
            let response = try await APIService.shared.editWorkplaceSafetyAssessment(id: id)
            let assessment = response.data.assessment
            populateFromAssessment(assessment)
            status = .draft
            hasUserMadeChanges = false
            // Refresh the list so the status change is reflected
            await fetchAssessments()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to revert assessment to draft: \(error)")
        }
        isInitialLoad = false
    }
    
    // MARK: - Fetch Departments
    
    func fetchDepartments() async {
        do {
            departments = try await APIService.shared.fetchDepartments()
        } catch {
            print("❌ Failed to fetch departments: \(error)")
        }
    }
    
    // MARK: - Build Payload
    
    private func buildPayload() -> [String: Any] {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        
        let sectionsData: [[String: Any]] = sections.map { section in
            let itemsData: [[String: Any]] = section.items.map { item in
                var itemDict: [String: Any] = [
                    "id": item.id,
                    "description": item.description,
                ]
                
                if let status = item.status {
                    itemDict["status"] = status.rawValue
                }
                
                if !item.deficiency.isEmpty {
                    itemDict["deficiency"] = item.deficiency
                }
                
                if !item.correctiveAction.isEmpty {
                    itemDict["correctiveAction"] = item.correctiveAction
                }
                
                if let entries = item.dynamicEntries {
                    itemDict["dynamicEntries"] = entries.map { entry -> [String: Any] in
                        var dict: [String: Any] = ["id": entry.id]
                        if let name = entry.employeeName { dict["employeeName"] = name }
                        if let equip = entry.equipmentName { dict["equipmentName"] = equip }
                        return dict
                    }
                }
                
                itemDict["workOrderPlaced"] = item.workOrderPlaced
                itemDict["reportedViaSafetyApp"] = item.reportedViaSafetyApp
                
                if let date = item.safetyAppReportDate {
                    itemDict["safetyAppReportDate"] = date
                }
                if let date = item.workOrderDateCreated {
                    itemDict["workOrderDateCreated"] = date
                }
                if let assignee = item.workOrderAssignedTo {
                    itemDict["workOrderAssignedTo"] = assignee
                }
                
                return itemDict
            }
            
            return [
                "id": section.id,
                "title": section.title,
                "items": itemsData
            ]
        }
        
        var payload: [String: Any] = [
            "assessmentNumber": assessmentNumber,
            "version": version,
            "date": dateFormatter.string(from: assessmentDate),
            "teamLeaderName": teamLeaderName,
            "sections": sectionsData
        ]
        
        if let deptId = selectedDepartmentId, !deptId.isEmpty {
            payload["departmentId"] = deptId
        }
        
        if !employeeName.isEmpty {
            payload["employeeName"] = employeeName
        }
        
        return payload
    }
}
