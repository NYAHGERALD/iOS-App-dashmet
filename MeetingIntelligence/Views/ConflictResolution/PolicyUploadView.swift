//
//  PolicyUploadView.swift
//  MeetingIntelligence
//
//  Step 1: Upload Workplace Policy
//  Handles PDF/DOC upload, text extraction, and section parsing
//

import SwiftUI
import UniformTypeIdentifiers

struct PolicyUploadView: View {
    @StateObject private var manager = ConflictResolutionManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Form State
    @State private var policyName = ""
    @State private var policyVersion = "1.0"
    @State private var effectiveDate = Date()
    @State private var policyDescription = ""
    
    // Document State
    @State private var selectedFileURL: URL?
    @State private var selectedFileName = ""
    @State private var showFilePicker = false
    
    // Processing State
    @State private var isUploading = false
    @State private var uploadedPolicy: WorkplacePolicy?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccessView = false
    
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
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
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
                
                if showSuccessView, let policy = uploadedPolicy {
                    successView(policy: policy)
                } else if manager.isProcessingDocument {
                    processingView
                } else {
                    uploadFormView
                }
            }
            .navigationTitle("Upload Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(textSecondary)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf, .plainText, UTType("com.microsoft.word.doc") ?? .data, UTType("org.openxmlformats.wordprocessingml.document") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Upload Form View
    private var uploadFormView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // File Upload Section
                fileUploadSection
                
                // Policy Details Form
                policyDetailsForm
                
                // Upload Button
                uploadButton
            }
            .padding()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "doc.badge.arrow.up.fill")
                    .font(.system(size: 36))
                    .foregroundColor(AppColors.primary)
            }
            
            Text("Upload Workplace Policy")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(textPrimary)
            
            Text("Upload your company policy document to enable System-powered conflict analysis and recommendations")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - File Upload Section
    private var fileUploadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DOCUMENT")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(textTertiary)
            
            if let fileName = selectedFileURL?.lastPathComponent {
                // File Selected View
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.success.opacity(0.15))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: fileIcon(for: selectedFileURL))
                            .font(.system(size: 22))
                            .foregroundColor(AppColors.success)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(fileName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(textPrimary)
                            .lineLimit(1)
                        
                        Text("Ready to upload")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.success)
                    }
                    
                    Spacer()
                    
                    Button {
                        selectedFileURL = nil
                        selectedFileName = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(textSecondary)
                    }
                }
                .padding(14)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.success.opacity(0.3), lineWidth: 1)
                )
            } else {
                // Upload Button
                Button {
                    showFilePicker = true
                } label: {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                .foregroundColor(AppColors.primary.opacity(0.4))
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: "arrow.up.doc.fill")
                                .font(.system(size: 28))
                                .foregroundColor(AppColors.primary)
                        }
                        
                        VStack(spacing: 4) {
                            Text("Tap to select a file")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(textPrimary)
                            
                            Text("PDF, DOC, DOCX, or TXT")
                                .font(.system(size: 13))
                                .foregroundColor(textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .foregroundColor(cardBorder)
                    )
                    .background(cardBackground.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
    
    // MARK: - Policy Details Form
    private var policyDetailsForm: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("POLICY DETAILS")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(textTertiary)
            
            // Policy Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Policy Name")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textSecondary)
                
                TextField("e.g., Employee Conduct Policy", text: $policyName)
                    .textFieldStyle(CustomTextFieldStyle(colorScheme: colorScheme))
            }
            
            // Version & Effective Date
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Version")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textSecondary)
                    
                    TextField("1.0", text: $policyVersion)
                        .textFieldStyle(CustomTextFieldStyle(colorScheme: colorScheme))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Effective Date")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textSecondary)
                    
                    DatePicker("", selection: $effectiveDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(AppColors.primary)
                }
            }
            
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Description (Optional)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textSecondary)
                
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $policyDescription)
                        .font(.system(size: 15))
                        .foregroundColor(textPrimary)
                        .scrollContentBackground(.hidden)
                        .background(inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .frame(minHeight: 80)
                    
                    if policyDescription.isEmpty {
                        Text("Brief description of the policy...")
                            .font(.system(size: 15))
                            .foregroundColor(textTertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(cardBorder, lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Upload Button
    private var uploadButton: some View {
        Button {
            Task {
                await uploadPolicy()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 18))
                Text("Upload & Process Policy")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                (isFormValid ? AppColors.primary : AppColors.primary.opacity(0.5))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!isFormValid)
        .padding(.top, 8)
    }
    
    // MARK: - Processing View
    private var processingView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Animated Processing Icon
            ZStack {
                Circle()
                    .stroke(AppColors.primary.opacity(0.2), lineWidth: 4)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: manager.processingProgress)
                    .stroke(AppColors.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: manager.processingProgress)
                
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.primary)
            }
            
            VStack(spacing: 12) {
                Text("Processing Document")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Text(manager.processingStatus)
                    .font(.system(size: 15))
                    .foregroundColor(textSecondary)
                
                Text("\(Int(manager.processingProgress * 100))%")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(AppColors.primary)
            }
            
            // Processing Steps
            VStack(alignment: .leading, spacing: 16) {
                ProcessingStepRow(
                    title: "Reading document",
                    isComplete: manager.processingProgress > 0.2,
                    isActive: manager.processingProgress <= 0.2 && manager.processingProgress > 0
                )
                
                ProcessingStepRow(
                    title: "Extracting text",
                    isComplete: manager.processingProgress > 0.4,
                    isActive: manager.processingProgress > 0.2 && manager.processingProgress <= 0.4
                )
                
                ProcessingStepRow(
                    title: "Analyzing structure",
                    isComplete: manager.processingProgress > 0.6,
                    isActive: manager.processingProgress > 0.4 && manager.processingProgress <= 0.6
                )
                
                ProcessingStepRow(
                    title: "Creating sections",
                    isComplete: manager.processingProgress > 0.8,
                    isActive: manager.processingProgress > 0.6 && manager.processingProgress <= 0.8
                )
                
                ProcessingStepRow(
                    title: "Saving policy",
                    isComplete: manager.processingProgress >= 1.0,
                    isActive: manager.processingProgress > 0.8 && manager.processingProgress < 1.0
                )
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Success View
    private func successView(policy: WorkplacePolicy) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Success Icon
            ZStack {
                Circle()
                    .fill(AppColors.success.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppColors.success)
            }
            
            VStack(spacing: 12) {
                Text("Policy Uploaded!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(textPrimary)
                
                Text("Your policy has been processed and is ready to use")
                    .font(.system(size: 15))
                    .foregroundColor(textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Policy Summary Card
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.primary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(policy.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(textPrimary)
                        
                        Text("Version \(policy.version)")
                            .font(.system(size: 13))
                            .foregroundColor(textSecondary)
                    }
                }
                
                Divider()
                
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(policy.sectionCount)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(textPrimary)
                        Text("Sections")
                            .font(.system(size: 12))
                            .foregroundColor(textSecondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(policy.formattedEffectiveDate)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(textPrimary)
                        Text("Effective Date")
                            .font(.system(size: 12))
                            .foregroundColor(textSecondary)
                    }
                    
                    Spacer()
                }
            }
            .padding(20)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(cardBorder, lineWidth: 1)
            )
            .padding(.horizontal)
            
            Spacer()
            
            // Actions
            VStack(spacing: 12) {
                Button {
                    Task {
                        await manager.activatePolicy(policy)
                    }
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Activate Policy")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.success)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                
                Button {
                    dismiss()
                } label: {
                    Text("Review Later")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(textSecondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Helper Functions
    
    private var isFormValid: Bool {
        selectedFileURL != nil && !policyName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func fileIcon(for url: URL?) -> String {
        guard let url = url else { return "doc.fill" }
        
        switch url.pathExtension.lowercased() {
        case "pdf": return "doc.richtext.fill"
        case "doc", "docx": return "doc.fill"
        case "txt": return "doc.text.fill"
        default: return "doc.fill"
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                // Start accessing the security-scoped resource
                if url.startAccessingSecurityScopedResource() {
                    selectedFileURL = url
                    selectedFileName = url.lastPathComponent
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func uploadPolicy() async {
        guard let fileURL = selectedFileURL else { return }
        
        do {
            let policy = try await manager.createPolicy(
                name: policyName,
                version: policyVersion,
                effectiveDate: effectiveDate,
                description: policyDescription,
                documentURL: fileURL
            )
            
            // Stop accessing the security-scoped resource
            fileURL.stopAccessingSecurityScopedResource()
            
            uploadedPolicy = policy
            showSuccessView = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Processing Step Row
struct ProcessingStepRow: View {
    let title: String
    let isComplete: Bool
    let isActive: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if isComplete {
                    Circle()
                        .fill(AppColors.success)
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else if isActive {
                    Circle()
                        .stroke(AppColors.primary, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: 8, height: 8)
                } else {
                    Circle()
                        .stroke(textSecondary, lineWidth: 1)
                        .frame(width: 24, height: 24)
                }
            }
            
            Text(title)
                .font(.system(size: 15, weight: isActive ? .medium : .regular))
                .foregroundColor(isComplete || isActive ? textPrimary : textSecondary)
        }
    }
}

// MARK: - Custom Text Field Style
struct CustomTextFieldStyle: TextFieldStyle {
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

// MARK: - Preview
#Preview {
    PolicyUploadView()
}
