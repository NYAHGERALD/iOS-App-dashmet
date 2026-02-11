//
//  DocumentScannerView.swift
//  MeetingIntelligence
//
//  Document Scanner with AI-Powered OCR for Conflict Resolution
//  Supports camera scanning and file upload
//  Uses GPT-4 Vision for intelligent text extraction
//  Updated: Feb 2026
//

import SwiftUI
import VisionKit
import Vision
import PhotosUI
import PDFKit
import AVFoundation

// MARK: - Supported Languages for OCR
enum SupportedOCRLanguage: String, CaseIterable, Identifiable {
    case english = "English"
    case spanish = "Spanish"
    case french = "French"
    case german = "German"
    case portuguese = "Portuguese"
    case italian = "Italian"
    case dutch = "Dutch"
    case polish = "Polish"
    case russian = "Russian"
    case arabic = "Arabic"
    case persian = "Persian"
    case pashto = "Pashto"
    case dari = "Dari"
    case chinese = "Chinese"
    case japanese = "Japanese"
    case korean = "Korean"
    case vietnamese = "Vietnamese"
    case tagalog = "Tagalog"
    case hindi = "Hindi"
    
    var id: String { rawValue }
    
    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .portuguese: return "🇵🇹"
        case .italian: return "🇮🇹"
        case .dutch: return "🇳🇱"
        case .polish: return "🇵🇱"
        case .russian: return "🇷🇺"
        case .arabic: return "🇸🇦"
        case .persian: return "🇮🇷"
        case .pashto: return "🇦🇫"
        case .dari: return "🇦🇫"
        case .chinese: return "🇨🇳"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .vietnamese: return "🇻🇳"
        case .tagalog: return "🇵🇭"
        case .hindi: return "🇮🇳"
        }
    }
}

// MARK: - Full Image Selection (for reliable fullScreenCover)
struct SelectedImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
    let index: Int
}

// MARK: - Document Scanner Entry View
struct DocumentScannerEntryView: View {
    let conflictCase: ConflictCase
    let documentType: CaseDocumentType
    var onDocumentAdded: () -> Void = {}
    var preselectedEmployee: InvolvedEmployee? = nil
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showScanner = false
    @State private var showPhotoPicker = false
    @State private var showFilePicker = false
    @State private var scannedImages: [UIImage] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showProcessingView = false
    @State private var selectedEmployee: InvolvedEmployee?
    @State private var selectedLanguage: SupportedOCRLanguage = .english
    @State private var selectedImageItem: SelectedImageItem? = nil
    @State private var languageConfirmed = false
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    // Get employees appropriate for this document type
    private var availableEmployees: [InvolvedEmployee] {
        switch documentType {
        case .complaintA:
            // For Complaint A, show first complainant
            if let complainantA = conflictCase.complainantA {
                return [complainantA]
            }
            return []
        case .complaintB:
            // For Complaint B, show second complainant
            if let complainantB = conflictCase.complainantB {
                return [complainantB]
            }
            return []
        case .witnessStatement:
            // For witness statements, show witnesses only
            return conflictCase.witnesses
        case .evidence, .priorRecord, .counselingRecord, .warningDocument, .other:
            // For other docs, show all involved employees
            return conflictCase.involvedEmployees
        }
    }
    
    // Check if document can be processed (has employee selected and language confirmed)
    private var canProcess: Bool {
        !scannedImages.isEmpty && selectedEmployee != nil && languageConfirmed
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Submitter Name
                        submitterSection
                        
                        // Scan Options
                        scanOptionsSection
                        
                        // Scanned Pages Preview
                        if !scannedImages.isEmpty {
                            scannedPagesSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Scan \(documentType.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(textSecondary)
                }
            }
            .sheet(isPresented: $showScanner) {
                DocumentCameraView(scannedImages: $scannedImages)
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newItem in
                if let item = newItem {
                    loadPhotoFromPicker(item)
                }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentFilePicker(scannedImages: $scannedImages)
            }
            .fullScreenCover(isPresented: $showProcessingView) {
                DocumentProcessingView(
                    caseId: conflictCase.id,
                    documentType: documentType,
                    submittedBy: selectedEmployee,
                    scannedImages: scannedImages,
                    sourceLanguage: selectedLanguage.rawValue,
                    onComplete: {
                        onDocumentAdded()
                        dismiss()
                    }
                )
            }
            .fullScreenCover(item: $selectedImageItem) { item in
                FullImageView(image: item.image, onDismiss: {
                    selectedImageItem = nil
                })
            }
            .onAppear {
                // Pre-select employee if provided (e.g., for witness statements)
                if selectedEmployee == nil, let preselected = preselectedEmployee {
                    selectedEmployee = preselected
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(documentType.color.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: documentType.icon)
                    .font(.system(size: 32))
                    .foregroundColor(documentType.color)
            }
            
            Text("Add \(documentType.displayName)")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Text("Scan a handwritten or printed document, or upload an existing file.")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    private var submitterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUBMITTED BY")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(textSecondary)
            
            if availableEmployees.isEmpty {
                // No employees available - show message
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No employees available")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(textPrimary)
                        
                        Text("Please add employees to the case first")
                            .font(.system(size: 13))
                            .foregroundColor(textSecondary)
                    }
                    
                    Spacer()
                }
                .padding(14)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if availableEmployees.count == 1 {
                // Auto-select single employee
                let employee = availableEmployees[0]
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppColors.primary.opacity(0.15))
                            .frame(width: 40, height: 40)
                        
                        Text(employee.name.prefix(1).uppercased())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(employee.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(textPrimary)
                        
                        if !employee.role.isEmpty || !employee.department.isEmpty {
                            Text([employee.role, employee.department].filter { !$0.isEmpty }.joined(separator: " • "))
                                .font(.system(size: 13))
                                .foregroundColor(textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.success)
                }
                .padding(14)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.success.opacity(0.3), lineWidth: 1)
                )
                .onAppear {
                    selectedEmployee = employee
                }
            } else {
                // Multiple employees - show picker
                Menu {
                    ForEach(availableEmployees) { employee in
                        Button {
                            selectedEmployee = employee
                        } label: {
                            HStack {
                                Text(employee.name)
                                if !employee.role.isEmpty {
                                    Text("(\(employee.role))")
                                        .foregroundColor(.secondary)
                                }
                                if selectedEmployee?.id == employee.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        if let employee = selectedEmployee {
                            ZStack {
                                Circle()
                                    .fill(AppColors.primary.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                
                                Text(employee.name.prefix(1).uppercased())
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppColors.primary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(employee.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(textPrimary)
                                
                                if !employee.role.isEmpty || !employee.department.isEmpty {
                                    Text([employee.role, employee.department].filter { !$0.isEmpty }.joined(separator: " • "))
                                        .font(.system(size: 13))
                                        .foregroundColor(textSecondary)
                                }
                            }
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                            
                            Text("Select employee...")
                                .font(.system(size: 15))
                                .foregroundColor(textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(14)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedEmployee != nil ? AppColors.primary.opacity(0.3) : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)), lineWidth: 1)
                    )
                }
            }
        }
    }
    
    private var scanOptionsSection: some View {
        VStack(spacing: 16) {
            Text("CAPTURE METHOD")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Camera Scan Option
            ScanOptionButton(
                icon: "camera.fill",
                title: "Scan with Camera",
                subtitle: "Use camera to scan documents",
                color: .blue,
                isDisabled: languageConfirmed
            ) {
                showScanner = true
            }
            
            // Photo Library Option
            ScanOptionButton(
                icon: "photo.fill",
                title: "Choose from Photos",
                subtitle: "Select image from photo library",
                color: .green,
                isDisabled: languageConfirmed
            ) {
                showPhotoPicker = true
            }
            
            // File Upload Option
            ScanOptionButton(
                icon: "doc.fill",
                title: "Upload File",
                subtitle: "Import PDF or image file",
                color: .orange,
                isDisabled: languageConfirmed
            ) {
                showFilePicker = true
            }
        }
    }
    
    private var scannedPagesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("SCANNED PAGES (\(scannedImages.count))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(textSecondary)
                
                Spacer()
                
                Button("Clear All") {
                    scannedImages.removeAll()
                    languageConfirmed = false
                }
                .font(.system(size: 14))
                .foregroundColor(languageConfirmed ? .gray : .red)
                .disabled(languageConfirmed)
            }
            
            // Pages Grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                ForEach(scannedImages.indices, id: \.self) { index in
                    ScannedPageThumbnail(
                        image: scannedImages[index],
                        pageNumber: index + 1,
                        isDeleteDisabled: languageConfirmed,
                        onDelete: {
                            scannedImages.remove(at: index)
                        },
                        onTap: {
                            selectedImageItem = SelectedImageItem(image: scannedImages[index], index: index)
                        }
                    )
                }
                
                // Add More Button
                Button {
                    showScanner = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(languageConfirmed ? .gray : AppColors.primary)
                        Text("Add Page")
                            .font(.system(size: 12))
                            .foregroundColor(languageConfirmed ? .gray : textSecondary)
                    }
                    .frame(width: 80, height: 100)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                    )
                    .opacity(languageConfirmed ? 0.5 : 1.0)
                }
                .disabled(languageConfirmed)
            }
            
            // Language Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("DOCUMENT LANGUAGE")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(textSecondary)
                
                Menu {
                    ForEach(SupportedOCRLanguage.allCases) { language in
                        Button {
                            selectedLanguage = language
                        } label: {
                            HStack {
                                Text("\(language.flag) \(language.rawValue)")
                                if selectedLanguage == language {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text(selectedLanguage.flag)
                            .font(.system(size: 24))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedLanguage.rawValue)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(languageConfirmed ? .gray : textPrimary)
                            Text("Language of the scanned document")
                                .font(.system(size: 12))
                                .foregroundColor(languageConfirmed ? .gray : textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(14)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(languageConfirmed ? Color.gray.opacity(0.3) : AppColors.primary.opacity(0.3), lineWidth: 1)
                    )
                    .opacity(languageConfirmed ? 0.6 : 1.0)
                }
                .disabled(languageConfirmed)
            }
            .padding(.top, 8)
            
            // Language Confirmation Card
            languageConfirmationCard
                .padding(.top, 8)
            
            // Process Button
            Button {
                showProcessingView = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: canProcess ? "text.viewfinder" : "exclamationmark.circle")
                    Text(processButtonText)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canProcess ? AppColors.primary : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canProcess)
            .padding(.top, 8)
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var processButtonText: String {
        if selectedEmployee == nil {
            return "Select Employee First"
        } else if !languageConfirmed {
            return "Confirm Language First"
        } else {
            return "Process \(scannedImages.count) Page\(scannedImages.count == 1 ? "" : "s")"
        }
    }
    
    private var languageConfirmationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                languageConfirmed.toggle()
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    // Checkbox
                    Image(systemName: languageConfirmed ? "checkmark.square.fill" : "square")
                        .font(.system(size: 22))
                        .foregroundColor(languageConfirmed ? AppColors.success : .orange)
                    
                    // Message
                    VStack(alignment: .leading, spacing: 6) {
                        if languageConfirmed {
                            Text("Thank you for confirming!")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppColors.success)
                            
                            Text("You can now click the button below to proceed with processing.")
                                .font(.system(size: 13))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7))
                                .multilineTextAlignment(.leading)
                        } else {
                            Text("Please Confirm Language")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.orange)
                            
                            Text("Please confirm that the selected language matches the language used in the scanned document in order to get the correct result.")
                                .font(.system(size: 13))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7))
                                .multilineTextAlignment(.leading)
                        }
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(languageConfirmed ? AppColors.success.opacity(0.1) : Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(languageConfirmed ? AppColors.success.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func loadPhotoFromPicker(_ item: PhotosPickerItem) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    scannedImages.append(image)
                    selectedPhotoItem = nil
                }
            }
        }
    }
}

// MARK: - Scan Option Button
struct ScanOptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var isDisabled: Bool = false
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isDisabled ? Color.gray.opacity(0.15) : color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(isDisabled ? .gray : color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isDisabled ? .gray : (colorScheme == .dark ? .white : .black))
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(isDisabled ? .gray.opacity(0.6) : (colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.5)))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 8, x: 0, y: 2)
            .opacity(isDisabled ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

// MARK: - Scanned Page Thumbnail
struct ScannedPageThumbnail: View {
    let image: UIImage
    let pageNumber: Int
    var isDeleteDisabled: Bool = false
    let onDelete: () -> Void
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 4) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onTapGesture {
                        onTap?()
                    }
                
                Text("Page \(pageNumber)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            if !isDeleteDisabled {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                        .background(Color.white.clipShape(Circle()))
                }
                .offset(x: 8, y: -8)
            }
        }
    }
}

// MARK: - Document Camera View (VisionKit)
struct DocumentCameraView: UIViewControllerRepresentable {
    @Binding var scannedImages: [UIImage]
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentCameraView
        
        init(_ parent: DocumentCameraView) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                parent.scannedImages.append(image)
            }
            parent.dismiss()
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document scanner failed: \(error.localizedDescription)")
            parent.dismiss()
        }
    }
}

// MARK: - Document File Picker
struct DocumentFilePicker: UIViewControllerRepresentable {
    @Binding var scannedImages: [UIImage]
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image, .jpeg, .png])
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentFilePicker
        
        init(_ parent: DocumentFilePicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                
                if url.pathExtension.lowercased() == "pdf" {
                    // Extract images from PDF
                    if let pdfDocument = PDFDocument(url: url) {
                        for pageIndex in 0..<pdfDocument.pageCount {
                            if let page = pdfDocument.page(at: pageIndex) {
                                let pageRect = page.bounds(for: .mediaBox)
                                let renderer = UIGraphicsImageRenderer(size: pageRect.size)
                                let image = renderer.image { ctx in
                                    UIColor.white.setFill()
                                    ctx.fill(pageRect)
                                    ctx.cgContext.translateBy(x: 0, y: pageRect.height)
                                    ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                                    page.draw(with: .mediaBox, to: ctx.cgContext)
                                }
                                parent.scannedImages.append(image)
                            }
                        }
                    }
                } else if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    parent.scannedImages.append(image)
                }
            }
            parent.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

// MARK: - Document Processing View
struct DocumentProcessingView: View {
    let caseId: UUID
    let documentType: CaseDocumentType
    let submittedBy: InvolvedEmployee?
    let scannedImages: [UIImage]
    let sourceLanguage: String
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var processingState: ProcessingState = .processing
    @State private var progress: Double = 0
    @State private var currentStep = "Preparing images..."
    @State private var extractedText = ""
    @State private var translatedText: String? = nil
    @State private var cleanedText = ""
    @State private var detectedLanguage = "English"
    @State private var selectedTab = 0
    @State private var isEditing = false
    @State private var isEditingOriginal = false
    @State private var selectedImageItem: SelectedImageItem? = nil
    
    // TTS State
    @State private var isReading = false
    @State private var isLoadingAudio = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var currentWordIndex = 0
    @State private var words: [String] = []
    @State private var highlightTimer: Timer?
    @State private var showTranslationOffer = false
    @State private var isReadingTranslation = false
    @State private var introWordCount: Int = 0  // Words in intro speech (for delayed highlighting)
    @State private var introDelayTimer: Timer?  // Timer to delay highlighting until after intro
    
    // Review Workflow State
    @State private var showReviewWorkflow = false
    
    private let aiService = DocumentAIService.shared
    private let ttsService = TextToSpeechService.shared
    
    enum ProcessingState: Equatable {
        case processing
        case review
        case error(String, hint: String?)
    }
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                switch processingState {
                case .processing:
                    processingContent
                case .review:
                    reviewContent
                case .error(let message, let hint):
                    errorContent(message, hint: hint)
                }
            }
            .navigationTitle(processingState == .review ? "Review Document" : "Processing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if processingState == .review {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(textSecondary)
                    }
                }
            }
            .task {
                await processDocuments()
            }
        }
    }
    
    private var processingContent: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Processing Animation
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(AppColors.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)
                
                VStack(spacing: 4) {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 32))
                        .foregroundColor(AppColors.primary)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textSecondary)
                }
            }
            
            VStack(spacing: 8) {
                Text("Processing Document")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Text(currentStep)
                    .font(.system(size: 14))
                    .foregroundColor(textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Processing Steps
            VStack(alignment: .leading, spacing: 12) {
                OCRProcessingStepRow(title: "Extracting Text", isComplete: progress > 0.3, isActive: progress <= 0.3)
                if sourceLanguage.lowercased() != "english" {
                    OCRProcessingStepRow(title: "Translating to English", isComplete: progress > 0.5, isActive: progress > 0.3 && progress <= 0.5)
                    OCRProcessingStepRow(title: "Analysing Text", isComplete: progress > 0.75, isActive: progress > 0.5 && progress <= 0.75)
                } else {
                    OCRProcessingStepRow(title: "Analysing Text", isComplete: progress > 0.6, isActive: progress > 0.3 && progress <= 0.6)
                }
                OCRProcessingStepRow(title: "Finalizing", isComplete: progress >= 1.0, isActive: progress > 0.75 && progress < 1.0)
            }
            .padding()
            .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private var reviewContent: some View {
        ZStack {
            VStack(spacing: 0) {
                // Tab Selector - show Translated tab if non-English
                HStack(spacing: 0) {
                    TabButton(title: "Original", icon: "doc.text", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    if translatedText != nil {
                        TabButton(title: "Translated", icon: "globe", isSelected: selectedTab == 1) {
                            selectedTab = 1
                        }
                }
                TabButton(title: "Cleaned", icon: "sparkles", isSelected: selectedTab == (translatedText != nil ? 2 : 1)) {
                    selectedTab = translatedText != nil ? 2 : 1
                }
                TabButton(title: "Images", icon: "photo.stack", isSelected: selectedTab == (translatedText != nil ? 3 : 2)) {
                    selectedTab = translatedText != nil ? 3 : 2
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Content
            TabView(selection: $selectedTab) {
                // Original Text Tab
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label("Original (\(detectedLanguage))", systemImage: "doc.text")
                                .font(.system(size: 14))
                                .foregroundColor(textSecondary)
                            Spacer()
                            
                            Button {
                                isEditingOriginal.toggle()
                            } label: {
                                Text(isEditingOriginal ? "Done" : "Edit")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        if isEditingOriginal {
                            TextEditor(text: $extractedText)
                                .font(.system(size: 15))
                                .frame(minHeight: 300)
                                .padding(12)
                                .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal)
                        } else {
                            Text(extractedText.isEmpty ? "No text detected" : extractedText)
                                .font(.system(size: 15))
                                .foregroundColor(extractedText.isEmpty ? textSecondary : textPrimary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal)
                        }
                    }
                }
                .tag(0)
                
                // Translated Text Tab (only if non-English)
                if let translated = translatedText {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Label("English Translation", systemImage: "globe")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.primary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top)
                            
                            Text(translated)
                                .font(.system(size: 15))
                                .foregroundColor(textPrimary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal)
                        }
                    }
                    .tag(1)
                }
                
                // Cleaned Text Tab (in English - either original or translated then cleaned)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label("Cleaned & Structured (English)", systemImage: "sparkles")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.primary)
                            Spacer()
                            
                            Button {
                                isEditing.toggle()
                            } label: {
                                Text(isEditing ? "Done" : "Edit")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        if isEditing {
                            TextEditor(text: $cleanedText)
                                .font(.system(size: 15))
                                .frame(minHeight: 300)
                                .padding(12)
                                .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal)
                        } else {
                            Text(cleanedText.isEmpty ? "No text to display" : cleanedText)
                                .font(.system(size: 15))
                                .foregroundColor(cleanedText.isEmpty ? textSecondary : textPrimary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal)
                        }
                    }
                }
                .tag(translatedText != nil ? 2 : 1)
                
                // Images Tab
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                        ForEach(scannedImages.indices, id: \.self) { index in
                            Button {
                                selectedImageItem = SelectedImageItem(image: scannedImages[index], index: index)
                            } label: {
                                Image(uiImage: scannedImages[index])
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(radius: 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .tag(translatedText != nil ? 3 : 2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .fullScreenCover(item: $selectedImageItem) { item in
                FullImageView(image: item.image, onDismiss: {
                    selectedImageItem = nil
                })
            }
            
            // Accept Button
            VStack(spacing: 12) {
                Button {
                    showReviewWorkflow = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Accept Document")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                
                Text("Complete review & signature workflow to add document")
                    .font(.system(size: 12))
                    .foregroundColor(textSecondary)
            }
            .padding()
            .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
            .sheet(isPresented: $showReviewWorkflow) {
                DocumentReviewWorkflowView(
                    caseId: caseId.uuidString,
                    documentType: documentType,
                    originalText: extractedText,
                    cleanedText: cleanedText,
                    translatedText: translatedText,
                    originalImageBase64: scannedImages.first?.jpegData(compressionQuality: 0.7)?.base64EncodedString(),
                    submittedBy: submittedBy,
                    onComplete: { auditLog in
                        saveDocumentWithAuditLog(auditLog)
                        showReviewWorkflow = false
                    },
                    onCancel: {
                        showReviewWorkflow = false
                    }
                )
            }
            } // End of VStack
            
            // Floating Read Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        if isReading {
                            stopReading()
                        } else {
                            startReading()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if isLoadingAudio {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: isReading ? "stop.fill" : "speaker.wave.2.fill")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            
                            Text(isReading ? "Stop" : "Read")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(isReading ? Color.red : Color.blue)
                                .shadow(color: (isReading ? Color.red : Color.blue).opacity(0.4), radius: 8, x: 0, y: 4)
                        )
                    }
                    .disabled(isLoadingAudio)
                    .padding(.trailing, 20)
                    .padding(.bottom, 120) // Above Accept button
                }
            }
        }
        .alert("Listen to English Translation?", isPresented: $showTranslationOffer) {
            Button("Yes") {
                readEnglishTranslation()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Would you like me to read the English translation of this document?")
        }
    }
    
    private func errorContent(_ message: String, hint: String? = nil) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Processing Error")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            // Show recovery hint if available
            if let hint = hint {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text(hint)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(textPrimary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.yellow.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
            }
            
            Button {
                dismiss()
            } label: {
                Text("Go Back")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private func processDocuments() async {
        do {
            // Use AI-powered processing with GPT-4 Vision
            currentStep = "Analyzing document with AI Vision..."
            await MainActor.run { progress = 0.05 }
            
            let result = try await aiService.processMultiplePages(
                scannedImages,
                documentType: documentType.displayName,
                sourceLanguage: sourceLanguage
            ) { stepProgress, step in
                // Progress handler - update UI (note: callback is (Double, String))
                Task { @MainActor in
                    currentStep = step
                    // Map the step progress to our UI progress
                    switch step {
                    case let s where s.contains("Extracting"):
                        progress = 0.1 + (stepProgress * 0.2)  // 0.1-0.3
                    case let s where s.contains("Verifying"):
                        progress = 0.3 + (stepProgress * 0.15) // 0.3-0.45
                    case let s where s.contains("Cleaning"):
                        progress = 0.5 + (stepProgress * 0.25) // 0.5-0.75
                    case let s where s.contains("translating") || s.contains("Translating"):
                        progress = 0.75 + (stepProgress * 0.15) // 0.75-0.9
                    default:
                        progress = 0.9 + (stepProgress * 0.1)  // 0.9-1.0
                    }
                }
            }
            
            // Update state with results
            await MainActor.run {
                extractedText = result.originalText
                translatedText = result.translatedText
                cleanedText = result.cleanedText
                detectedLanguage = result.detectedLanguage
                progress = 1.0
            }
            
            // Brief pause before showing review
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                processingState = .review
            }
            
        } catch let error as DocumentAIError {
            // Handle specific AI errors - show friendly message with recovery hint
            await MainActor.run {
                processingState = .error(
                    error.errorDescription ?? "AI service is currently unavailable. Please contact your administrator.",
                    hint: error.recoveryHint
                )
            }
            
        } catch {
            // Generic error - show friendly message
            await MainActor.run {
                processingState = .error(
                    "AI service is currently unavailable. Please check your internet connection and try again, or contact your administrator for assistance.",
                    hint: nil
                )
            }
        }
    }
    
    private func saveDocument() {
        // Convert images to base64 for local storage
        // In production, these would be uploaded to Firebase Storage
        let imageDataArray = scannedImages.compactMap { image -> String? in
            guard let data = image.jpegData(compressionQuality: 0.7) else { return nil }
            return data.base64EncodedString()
        }
        
        let document = CaseDocument(
            type: documentType,
            originalText: extractedText,
            translatedText: translatedText,
            cleanedText: cleanedText,
            originalImageBase64: imageDataArray.first,
            processedImageBase64: imageDataArray.first,
            detectedLanguage: detectedLanguage,
            isHandwritten: nil,
            employeeId: submittedBy?.id,
            submittedBy: submittedBy?.name
        )
        
        ConflictResolutionManager.shared.addDocument(to: caseId, document: document)
        onComplete()
    }
    
    /// Save document with comprehensive audit log from review workflow
    private func saveDocumentWithAuditLog(_ auditLog: DocumentAuditLog) {
        // Convert images to base64 for local storage
        let imageDataArray = scannedImages.compactMap { image -> String? in
            guard let data = image.jpegData(compressionQuality: 0.7) else { return nil }
            return data.base64EncodedString()
        }
        
        // Create document with full audit trail
        let document = CaseDocument(
            id: auditLog.documentId,
            type: documentType,
            originalText: extractedText,
            translatedText: translatedText,
            cleanedText: cleanedText,
            originalImageBase64: imageDataArray.first,
            processedImageBase64: imageDataArray.first,
            detectedLanguage: detectedLanguage,
            isHandwritten: nil,
            employeeId: submittedBy?.id,
            submittedBy: submittedBy?.name,
            // Audit log fields
            signatureImageBase64: auditLog.signatureImageBase64,
            employeeReviewTimestamp: auditLog.employeeReviewTimestamp,
            employeeSignatureTimestamp: auditLog.employeeSignatureTimestamp,
            supervisorCertificationTimestamp: auditLog.supervisorCertificationTimestamp,
            supervisorId: auditLog.supervisorId,
            supervisorName: auditLog.supervisorName,
            submittedById: auditLog.submittedById,
            deviceId: auditLog.deviceId,
            appVersion: auditLog.appVersion,
            versionHash: auditLog.versionHash
        )
        
        // Add document to case
        ConflictResolutionManager.shared.addDocument(to: caseId, document: document)
        
        // Submit audit log to backend (fire-and-forget)
        Task {
            await submitAuditLogToBackend(auditLog)
        }
        
        onComplete()
    }
    
    /// Submit audit log to backend for permanent storage
    private func submitAuditLogToBackend(_ auditLog: DocumentAuditLog) async {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(auditLog)
            
            guard let url = URL(string: "https://dashmet-rca-api.onrender.com/api/document-ocr/audit-log") else {
                print("Invalid audit log URL")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    print("Audit log submitted successfully")
                } else {
                    print("Audit log submission failed with status: \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("Error submitting audit log: \(error.localizedDescription)")
            // Don't fail the document save - audit log submission is best-effort
        }
    }
    
    // MARK: - TTS Methods
    
    /// Check if document is in a non-English language
    private var isNonEnglishDocument: Bool {
        let language = detectedLanguage.lowercased()
        return !language.contains("english") && language != "en"
    }
    
    /// Get the language code for TTS based on detected language
    private var documentLanguageCode: String {
        let language = detectedLanguage.lowercased()
        
        // Map detected language names to language codes
        let languageMap: [String: String] = [
            "english": "en-US",
            "french": "fr-FR",
            "spanish": "es-ES",
            "german": "de-DE",
            "portuguese": "pt-BR",
            "chinese": "zh-CN",
            "japanese": "ja-JP",
            "korean": "ko-KR",
            "arabic": "ar-SA",
            "hindi": "hi-IN",
            "italian": "it-IT",
            "dutch": "nl-NL",
            "polish": "pl-PL",
            "russian": "ru-RU",
            "turkish": "tr-TR",
            "thai": "th-TH",
            "vietnamese": "vi-VN",
            "indonesian": "id-ID",
            "malay": "ms-MY",
            "swedish": "sv-SE",
            "norwegian": "nb-NO",
            "danish": "da-DK",
            "finnish": "fi-FI",
            "hebrew": "he-IL",
            "greek": "el-GR",
            "czech": "cs-CZ",
            "hungarian": "hu-HU",
            "romanian": "ro-RO",
            "ukrainian": "uk-UA",
            "swahili": "sw-KE",
            "afrikaans": "af-ZA",
            "persian": "fa-IR",
            "pashto": "ps-AF",
            "dari": "fa-AF",
            "tagalog": "tl-PH"
        ]
        
        // Find matching language
        for (key, code) in languageMap {
            if language.contains(key) {
                return code
            }
        }
        
        return "en-US"
    }
    
    private func startReading() {
        isLoadingAudio = true
        isReadingTranslation = false
        
        // Get the text to read based on selected tab
        let textToRead: String
        let languageCode: String
        
        if selectedTab == 0 {
            // Reading original text
            textToRead = extractedText.isEmpty ? cleanedText : extractedText
            languageCode = documentLanguageCode
        } else if translatedText != nil && selectedTab == 1 {
            // Reading translated text (English)
            textToRead = translatedText ?? cleanedText
            languageCode = "en-US"
            isReadingTranslation = true
        } else {
            // Reading cleaned text
            textToRead = cleanedText
            languageCode = documentLanguageCode
        }
        
        print("TTS: Starting to read, text length: \(textToRead.count), language: \(languageCode)")
        
        // Prepare words for highlighting
        words = textToRead.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        currentWordIndex = 0
        
        Task {
            do {
                print("TTS: Calling API with intro (first review instance)...")
                // First instance (before submission): Include intro speech
                let result = try await ttsService.generateSpeech(
                    text: textToRead,
                    employeeName: submittedBy?.name ?? "User",
                    documentType: documentType.displayName,
                    languageCode: languageCode,
                    skipIntro: false  // Include intro for first review
                )
                
                print("TTS: Got audio data, size: \(result.audioData.count) bytes, intro words: \(result.introWordCount)")
                
                await MainActor.run {
                    introWordCount = result.introWordCount
                    playAudio(audioData: result.audioData)
                }
            } catch {
                await MainActor.run {
                    isLoadingAudio = false
                    isReading = false
                    print("TTS Error: \(error)")
                }
            }
        }
    }
    
    /// Read the English translation after user accepts the offer
    private func readEnglishTranslation() {
        guard let translated = translatedText, !translated.isEmpty else {
            return
        }
        
        isLoadingAudio = true
        isReadingTranslation = true
        
        // Prepare words for highlighting
        words = translated.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        currentWordIndex = 0
        
        // Switch to translation tab if available
        if translatedText != nil {
            selectedTab = 1
        }
        
        Task {
            do {
                // Include intro for first review instance
                let result = try await ttsService.generateSpeech(
                    text: translated,
                    employeeName: submittedBy?.name ?? "User",
                    documentType: documentType.displayName,
                    languageCode: "en-US",  // Always English for translation
                    skipIntro: false  // Include intro for first review
                )
                
                await MainActor.run {
                    introWordCount = result.introWordCount
                    playAudio(audioData: result.audioData)
                }
            } catch {
                await MainActor.run {
                    isLoadingAudio = false
                    isReadingTranslation = false
                    print("TTS Error: \(error)")
                }
            }
        }
    }
    
    private func playAudio(audioData: Data) {
        do {
            // Configure audio session for playback (same as AI Vision)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            print("TTS: Audio session configured, data size: \(audioData.count) bytes")
            
            // Use AVAudioPlayer directly like AI Vision
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            print("TTS: Audio playback started, duration: \(audioPlayer?.duration ?? 0), intro words: \(introWordCount)")
            
            isLoadingAudio = false
            isReading = true
            
            // Reading speed: ~2.5 words per second (average TTS speed)
            let wordsPerSecond: Double = 2.5
            let interval = 1.0 / wordsPerSecond
            
            // Calculate delay for intro speech (intro + closing "..." marker)
            // Highlighting should start only when actual document content begins
            let introDelaySeconds = Double(introWordCount) * interval
            
            if introWordCount > 0 {
                print("TTS: Delaying highlight by \(introDelaySeconds)s for intro (\(introWordCount) words)")
                
                // Delay starting the highlight timer until intro finishes
                introDelayTimer = Timer.scheduledTimer(withTimeInterval: introDelaySeconds, repeats: false) { [self] _ in
                    startHighlightTimer(interval: interval)
                }
            } else {
                // No intro - start highlighting immediately
                startHighlightTimer(interval: interval)
            }
            
            // Also set a timer to check for audio completion
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                if !(audioPlayer?.isPlaying ?? false) && !isLoadingAudio {
                    timer.invalidate()
                    onAudioFinished()
                }
            }
        } catch {
            isLoadingAudio = false
            isReading = false
            print("TTS: Audio playback error: \(error)")
        }
    }
    
    /// Start the highlight timer for syncing text with speech
    private func startHighlightTimer(interval: Double) {
        print("TTS: Starting text highlighting, \(words.count) words at \(1.0/interval) words/sec")
        
        highlightTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            if currentWordIndex < words.count {
                currentWordIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
    
    /// Called when audio playback finishes naturally
    private func onAudioFinished() {
        let wasReadingTranslation = isReadingTranslation
        let wasNonEnglish = isNonEnglishDocument && translatedText != nil && !wasReadingTranslation
        
        // Clean up audio state
        audioPlayer?.stop()
        audioPlayer = nil
        highlightTimer?.invalidate()
        highlightTimer = nil
        introDelayTimer?.invalidate()
        introDelayTimer = nil
        isReading = false
        currentWordIndex = 0
        words = []
        introWordCount = 0
        
        // If we just finished reading non-English original text and there's a translation,
        // offer to read the English version
        if wasNonEnglish {
            // Small delay before showing the popup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showTranslationOffer = true
            }
        }
        
        isReadingTranslation = false
    }
    
    /// Stop reading manually (user pressed stop)
    private func stopReading() {
        audioPlayer?.stop()
        audioPlayer = nil
        highlightTimer?.invalidate()
        highlightTimer = nil
        introDelayTimer?.invalidate()
        introDelayTimer = nil
        isReading = false
        currentWordIndex = 0
        words = []
        introWordCount = 0
        isReadingTranslation = false
        // Don't show translation offer when user manually stops
    }
}

// MARK: - OCR Processing Step Row
struct OCRProcessingStepRow: View {
    let title: String
    let isComplete: Bool
    let isActive: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isComplete ? AppColors.success : (isActive ? AppColors.primary : Color.gray.opacity(0.3)))
                    .frame(width: 24, height: 24)
                
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else if isActive {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(.white)
                }
            }
            
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(isComplete ? AppColors.success : (isActive ? (colorScheme == .dark ? .white : .black) : .gray))
        }
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var iconColor: Color {
        switch icon {
        case "doc.text": return .blue
        case "globe": return .green
        case "sparkles": return .purple
        case "photo.stack": return .orange
        default: return AppColors.primary
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? iconColor : .gray)
                
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? (colorScheme == .dark ? .white : .black) : .gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Rectangle()
                    .fill(isSelected ? iconColor : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Full Image View
struct FullImageView: View {
    let image: UIImage
    let onDismiss: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Image with zoom - render immediately with no animation
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
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
                                    }
                                }
                            }
                    )
                    .gesture(
                        TapGesture(count: 2)
                            .onEnded {
                                withAnimation {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        lastScale = 1.0
                                    } else {
                                        scale = 2.5
                                        lastScale = 2.5
                                    }
                                }
                            }
                    )
                
                // Overlay controls
                VStack {
                    // Header with close button
                    HStack {
                        Spacer()
                        Button {
                            onDismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                    }
                    
                    Spacer()
                    
                    // Footer hint
                    Text("Pinch to zoom • Double-tap to fit")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Preview
#Preview {
    let sampleCase = ConflictCase(
        caseNumber: "CR-2025-001",
        type: .conflict,
        status: .draft,
        involvedEmployees: [
            InvolvedEmployee(name: "John Doe", role: "Engineer", department: "IT", isComplainant: true),
            InvolvedEmployee(name: "Jane Smith", role: "Manager", department: "HR", isComplainant: true)
        ]
    )
    
    DocumentScannerEntryView(
        conflictCase: sampleCase,
        documentType: .complaintA,
        onDocumentAdded: {}
    )
}
