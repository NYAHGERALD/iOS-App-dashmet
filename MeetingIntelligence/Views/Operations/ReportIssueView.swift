//
//  ReportIssueView.swift
//  MeetingIntelligence
//
//  Report Operations Issue - Machine & Quality Issue Reporting
//

import SwiftUI
import FirebaseStorage

// MARK: - Issue Type Enum
enum IssueType: String, CaseIterable, Identifiable {
    case MACHINE = "MACHINE"
    case QUALITY = "QUALITY"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .MACHINE: return "Machine Issue"
        case .QUALITY: return "Quality Issue"
        }
    }
    
    var icon: String {
        switch self {
        case .MACHINE: return "gearshape.2"
        case .QUALITY: return "checkmark.seal"
        }
    }
    
    var color: Color {
        switch self {
        case .MACHINE: return AppColors.warning
        case .QUALITY: return AppColors.info
        }
    }
}

// MARK: - Issue Priority Enum
enum IssuePriority: String, CaseIterable, Identifiable {
    case LOW = "LOW"
    case MEDIUM = "MEDIUM"
    case HIGH = "HIGH"
    case CRITICAL = "CRITICAL"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .LOW: return "Low"
        case .MEDIUM: return "Medium"
        case .HIGH: return "High"
        case .CRITICAL: return "Critical"
        }
    }
    
    var color: Color {
        switch self {
        case .LOW: return AppColors.success
        case .MEDIUM: return AppColors.warning
        case .HIGH: return Color.orange
        case .CRITICAL: return AppColors.error
        }
    }
    
    var icon: String {
        switch self {
        case .LOW: return "arrow.down.circle"
        case .MEDIUM: return "minus.circle"
        case .HIGH: return "arrow.up.circle"
        case .CRITICAL: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Report Issue View
struct ReportIssueView: View {
    @StateObject private var operationsService = OperationsService.shared
    @StateObject private var departmentService = DepartmentService.shared
    @StateObject private var shiftService = ShiftService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Form state
    @State private var selectedType: IssueType = .MACHINE
    @State private var title = ""
    @State private var description = ""
    @State private var selectedPriority: IssuePriority = .MEDIUM
    @State private var selectedDepartment: Department?
    @State private var selectedArea: AreaItem?
    @State private var selectedLine: LineItem?
    @State private var selectedShift: ShiftItem?
    @State private var selectedEquipment: EquipmentItem?
    @State private var selectedComponent: ComponentItem?
    
    // Photo state
    @State private var attachedPhotos: [AttachedPhoto] = []
    @State private var showCamera = false
    @State private var showAttachOptions = false
    @State private var showGalleryPicker = false
    @State private var isUploadingPhotos = false
    @State private var renamingIndex: Int?
    @State private var renameText = ""
    
    // UI state
    @State private var showValidationError = false
    @State private var validationMessage = ""
    @State private var showSuccessAlert = false
    @State private var submittedIssueNumber = ""
    
    // Computed - form validity
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedDepartment != nil
    }
    
    // Adaptive colors
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    private var textTertiary: Color {
        colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4)
    }
    private var cardBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }
    private var inputBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 14) {
                        issueTypeField
                        titleField
                        descriptionField
                        priorityField
                        
                        sectionLabel("LOCATION")
                        locationSection
                        
                        photosSection
                        submitButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                
                // Loading overlay
                if operationsService.isSubmitting || isUploadingPhotos {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .overlay {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.1)
                                    .tint(.white)
                                Text(isUploadingPhotos ? "Uploading photos..." : "Submitting Issue...")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(28)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                }
            }
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 15))
                        .foregroundColor(textSecondary)
                }
            }
            .alert("Validation Error", isPresented: $showValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
            .alert("Issue Reported", isPresented: $showSuccessAlert) {
                Button("Done") { dismiss() }
            } message: {
                Text("Issue \(submittedIssueNumber) has been reported successfully.")
            }
            .fullScreenCover(isPresented: $showCamera) {
                IssueCameraPicker { image in
                    if let image = image {
                        let name = "photo_\(attachedPhotos.count + 1)"
                        attachedPhotos.append(AttachedPhoto(image: image, name: name))
                    }
                }
            }
            .fullScreenCover(isPresented: $showGalleryPicker) {
                IssueGalleryPicker { image in
                    if let image = image {
                        let name = "photo_\(attachedPhotos.count + 1)"
                        attachedPhotos.append(AttachedPhoto(image: image, name: name))
                    }
                }
            }
            .alert("Rename Photo", isPresented: Binding(
                get: { renamingIndex != nil },
                set: { if !$0 { renamingIndex = nil } }
            )) {
                TextField("Photo name", text: $renameText)
                Button("Save") {
                    if let idx = renamingIndex, idx < attachedPhotos.count, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                        attachedPhotos[idx].name = renameText.trimmingCharacters(in: .whitespaces)
                    }
                    renamingIndex = nil
                }
                Button("Cancel", role: .cancel) { renamingIndex = nil }
            } message: {
                Text("Enter a new name for this photo")
            }
            .onAppear {
                Task {
                    await departmentService.fetchDepartments()
                    await shiftService.fetchShifts()
                }
            }
        }
    }
    
    // MARK: - Issue Type Dropdown
    private var issueTypeField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Issue Type *")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textSecondary)
            
            Menu {
                ForEach(IssueType.allCases) { type in
                    Button {
                        selectedType = type
                    } label: {
                        Label(type.displayName, systemImage: type.icon)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: selectedType.icon)
                        .font(.system(size: 14))
                        .foregroundColor(selectedType.color)
                    
                    Text(selectedType.displayName)
                        .font(.system(size: 14))
                        .foregroundColor(textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(cardBorder, lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Title
    private var titleField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Title *")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textSecondary)
            
            TextField("Brief description of the issue", text: $title)
                .font(.system(size: 14))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(cardBorder, lineWidth: 1)
                )
        }
    }
    
    // MARK: - Description
    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Description *")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textSecondary)
            
            TextEditor(text: $description)
                .font(.system(size: 14))
                .frame(minHeight: 80, maxHeight: 120)
                .padding(8)
                .background(inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(cardBorder, lineWidth: 1)
                )
                .scrollContentBackground(.hidden)
        }
    }
    
    // MARK: - Priority Dropdown
    private var priorityField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Priority")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textSecondary)
            
            Menu {
                ForEach(IssuePriority.allCases) { priority in
                    Button {
                        selectedPriority = priority
                    } label: {
                        Label(priority.displayName, systemImage: priority.icon)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: selectedPriority.icon)
                        .font(.system(size: 14))
                        .foregroundColor(selectedPriority.color)
                    
                    Text(selectedPriority.displayName)
                        .font(.system(size: 14))
                        .foregroundColor(textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(cardBorder, lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Section Label
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }
    
    // MARK: - Location Section
    private var locationSection: some View {
        VStack(spacing: 10) {
            departmentField
            shiftField
            areaField
            lineField
            equipmentField
            componentField
        }
    }
    
    private var departmentField: some View {
        dropdownField(
            label: "Department *",
            value: selectedDepartment?.name,
            placeholder: "Select Department",
            items: departmentService.departments.map { ($0.id, $0.name) },
            isLoading: departmentService.isLoading
        ) { id in
            selectedDepartment = departmentService.departments.first { $0.id == id }
            selectedShift = nil; selectedArea = nil; selectedLine = nil
            selectedEquipment = nil; selectedComponent = nil
            operationsService.resetCascade(from: .department)
            if let dept = selectedDepartment {
                Task { await operationsService.fetchAreas(departmentId: dept.id) }
            }
        }
    }
    
    private var shiftField: some View {
        dropdownField(
            label: "Shift",
            value: selectedShift?.name,
            placeholder: selectedDepartment == nil ? "Select Department first" : "Select Shift",
            items: shiftService.shifts.map { ($0.id, $0.name) },
            isLoading: shiftService.isLoading,
            allowNone: true,
            disabled: selectedDepartment == nil
        ) { id in
            if let id = id {
                selectedShift = shiftService.shifts.first { $0.id == id }
            } else {
                selectedShift = nil
            }
        }
    }
    
    private var areaField: some View {
        dropdownField(
            label: "Area",
            value: selectedArea?.name,
            placeholder: selectedDepartment == nil ? "Select Department first" : "Select Area",
            items: operationsService.areas.map { ($0.id, $0.name) },
            isLoading: false,
            allowNone: true,
            disabled: selectedDepartment == nil
        ) { id in
            if let id = id {
                selectedArea = operationsService.areas.first { $0.id == id }
                selectedLine = nil; selectedEquipment = nil; selectedComponent = nil
                operationsService.resetCascade(from: .area)
                Task { await operationsService.fetchLines(areaId: id) }
            } else {
                selectedArea = nil; selectedLine = nil
                selectedEquipment = nil; selectedComponent = nil
                operationsService.resetCascade(from: .area)
            }
        }
    }
    
    private var lineField: some View {
        dropdownField(
            label: "Line",
            value: selectedLine?.name,
            placeholder: selectedArea == nil ? "Select Area first" : "Select Line",
            items: operationsService.lines.map { ($0.id, $0.name) },
            isLoading: false,
            allowNone: true,
            disabled: selectedArea == nil
        ) { id in
            if let id = id {
                selectedLine = operationsService.lines.first { $0.id == id }
                selectedEquipment = nil; selectedComponent = nil
                operationsService.resetCascade(from: .line)
                Task { await operationsService.fetchEquipment(lineId: id) }
            } else {
                selectedLine = nil; selectedEquipment = nil; selectedComponent = nil
                operationsService.resetCascade(from: .line)
            }
        }
    }
    
    private var equipmentField: some View {
        dropdownField(
            label: "Equipment / Machine",
            value: selectedEquipment?.name,
            placeholder: selectedLine == nil ? "Select Line first" : "Select Equipment",
            items: operationsService.equipment.map { ($0.id, $0.name) },
            isLoading: false,
            allowNone: true,
            disabled: selectedLine == nil
        ) { id in
            if let id = id {
                selectedEquipment = operationsService.equipment.first { $0.id == id }
                selectedComponent = nil
                operationsService.resetCascade(from: .equipment)
                Task { await operationsService.fetchComponents(equipmentId: id) }
            } else {
                selectedEquipment = nil; selectedComponent = nil
                operationsService.resetCascade(from: .equipment)
            }
        }
    }
    
    private var componentField: some View {
        dropdownField(
            label: "Component",
            value: selectedComponent?.name,
            placeholder: selectedEquipment == nil ? "Select Equipment first" : "Select Component",
            items: operationsService.components.map { ($0.id, $0.name) },
            isLoading: false,
            allowNone: true,
            disabled: selectedEquipment == nil
        ) { id in
            if let id = id {
                selectedComponent = operationsService.components.first { $0.id == id }
            } else {
                selectedComponent = nil
            }
        }
    }
    
    // MARK: - Dropdown Field Helper
    private func dropdownField(
        label: String,
        value: String?,
        placeholder: String,
        items: [(String, String)],
        isLoading: Bool,
        allowNone: Bool = false,
        disabled: Bool = false,
        onSelect: @escaping (String?) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textSecondary)
            
            Menu {
                if isLoading {
                    Text("Loading...")
                } else {
                    if allowNone {
                        Button("None") { onSelect(nil) }
                    }
                    ForEach(items, id: \.0) { item in
                        Button(item.1) { onSelect(item.0) }
                    }
                }
            } label: {
                HStack {
                    Text(value ?? placeholder)
                        .font(.system(size: 13))
                        .foregroundColor(value != nil ? textPrimary : textTertiary)
                        .lineLimit(1)
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(textTertiary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(cardBorder, lineWidth: 1)
                )
            }
            .disabled(disabled || isLoading)
            .opacity(disabled ? 0.5 : 1.0)
        }
    }
    
    // MARK: - Photos Section
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Photos")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textSecondary)
            
            // Attached photos grid
            if !attachedPhotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachedPhotos.indices, id: \.self) { index in
                            VStack(spacing: 2) {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: attachedPhotos[index].image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    
                                    Button {
                                        attachedPhotos.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.white)
                                            .shadow(radius: 2)
                                    }
                                    .offset(x: 4, y: -4)
                                }
                                
                                // Tappable name for renaming
                                Button {
                                    renameText = attachedPhotos[index].name
                                    renamingIndex = index
                                } label: {
                                    Text(attachedPhotos[index].name)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(AppColors.primary)
                                        .lineLimit(1)
                                        .frame(width: 72)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
            
            // Dashed upload area - tappable
            Button {
                showAttachOptions = true
            } label: {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "paperclip.circle")
                            .font(.system(size: 22))
                            .foregroundColor(AppColors.primary)
                        Text(attachedPhotos.isEmpty ? "Add Photos" : "Add More")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.primary)
                    }
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        .foregroundColor(AppColors.primary.opacity(0.3))
                )
            }
            .confirmationDialog("Add Photos", isPresented: $showAttachOptions, titleVisibility: .visible) {
                Button("Take Photo") {
                    showCamera = true
                }
                Button("Choose from Library") {
                    showGalleryPicker = true
                }
                Button("Cancel", role: .cancel) { }
            }

        }
        .padding(.top, 2)
    }
    
    // MARK: - Submit Button
    private var submitButton: some View {
        Button {
            submitIssue()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 15))
                
                Text("Submit Issue")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Group {
                    if isFormValid {
                        LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        LinearGradient(
                            colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: isFormValid ? AppColors.primary.opacity(0.25) : .clear, radius: 6, y: 3)
        }
        .disabled(!isFormValid || operationsService.isSubmitting || isUploadingPhotos)
        .padding(.top, 4)
        .padding(.bottom, 24)
    }
    
    // MARK: - Upload Photos to Firebase
    private func uploadPhotosToFirebase(issueId: String) async -> [(url: String, name: String)] {
        var uploaded: [(url: String, name: String)] = []
        let storage = Storage.storage()
        
        for (index, photo) in attachedPhotos.enumerated() {
            guard let imageData = photo.image.jpegData(compressionQuality: 0.8) else { continue }
            
            let timestamp = Int(Date().timeIntervalSince1970 * 1000)
            let fileName = "\(photo.name).jpg"
            let storagePath = "operations/\(issueId)/\(timestamp)_\(fileName)"
            
            let storageRef = storage.reference().child(storagePath)
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            do {
                _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
                let downloadURL = try await storageRef.downloadURL()
                uploaded.append((url: downloadURL.absoluteString, name: fileName))
            } catch {
                print("❌ Failed to upload photo \(index + 1): \(error.localizedDescription)")
            }
        }
        
        return uploaded
    }
    
    // MARK: - Upload Photos to Backend
    private func uploadPhotosToBackend(issueId: String, photos: [(url: String, name: String)]) async {
        guard let token = try? await FirebaseAuthService.shared.getIDToken(),
              let url = URL(string: "https://dashmet-rca-api.onrender.com/api/operations/issues/\(issueId)/photos") else { return }
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var body = Data()
        
        for (index, photo) in attachedPhotos.enumerated() {
            guard let imageData = photo.image.jpegData(compressionQuality: 0.8) else { continue }
            let name = photos.indices.contains(index) ? photos[index].name : "\(photo.name).jpg"
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"photos\"; filename=\"\(name)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print(httpResponse.statusCode == 200 ? "✅ Photos uploaded to backend" : "⚠️ Photo upload status: \(httpResponse.statusCode)")
            }
        } catch {
            print("❌ Failed to upload photos to backend: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Submit Action
    private func submitIssue() {
        guard let department = selectedDepartment else { return }
        
        let request = CreateIssueRequest(
            type: selectedType.rawValue,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            priority: selectedPriority.rawValue,
            departmentId: department.id,
            areaId: selectedArea?.id,
            lineId: selectedLine?.id,
            shiftId: selectedShift?.id,
            equipmentId: selectedEquipment?.id,
            componentId: selectedComponent?.id
        )
        
        Task {
            let success = await operationsService.createIssue(request)
            if success {
                let issueId = operationsService.issues.first?.id ?? ""
                submittedIssueNumber = operationsService.issues.first?.issueNumber ?? ""
                
                // Upload photos if any
                if !attachedPhotos.isEmpty && !issueId.isEmpty {
                    isUploadingPhotos = true
                    await uploadPhotosToBackend(issueId: issueId, photos: [])
                    isUploadingPhotos = false
                }
                
                showSuccessAlert = true
            } else if let error = operationsService.errorMessage {
                validationMessage = error
                showValidationError = true
            }
        }
    }
}

// MARK: - Attached Photo Model
struct AttachedPhoto: Identifiable {
    let id = UUID()
    var image: UIImage
    var name: String
}

// MARK: - Camera Picker
struct IssueCameraPicker: UIViewControllerRepresentable {
    var onImagePicked: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: IssueCameraPicker
        init(_ parent: IssueCameraPicker) { self.parent = parent }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage
            parent.onImagePicked(image)
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onImagePicked(nil)
            parent.dismiss()
        }
    }
}

// MARK: - Gallery Picker with Native Crop
struct IssueGalleryPicker: UIViewControllerRepresentable {
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
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: IssueGalleryPicker
        init(_ parent: IssueGalleryPicker) { self.parent = parent }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage
            parent.onImagePicked(image)
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onImagePicked(nil)
            parent.dismiss()
        }
    }
}

// MARK: - Text Field Style
struct IssueTextFieldStyle: TextFieldStyle {
    let colorScheme: ColorScheme
    
    private var inputBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(14)
            .background(inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
    }
}

#Preview {
    ReportIssueView()
}
