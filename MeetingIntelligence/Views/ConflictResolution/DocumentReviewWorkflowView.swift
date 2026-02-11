//
//  DocumentReviewWorkflowView.swift
//  MeetingIntelligence
//
//  Created for Document Review & Signature Workflow
//

import SwiftUI
import UIKit
import CryptoKit
import FirebaseAuth

// MARK: - Document Audit Log Model
/// Comprehensive audit log for document acceptance tracking
struct DocumentAuditLog: Codable, Identifiable {
    let id: UUID
    let complaintId: String                    // Case/Complaint ID
    let documentId: UUID                       // Document ID
    let originalText: String                   // Original OCR text
    let cleanedText: String                    // AI-cleaned text
    let translatedText: String?                // Translated text (if applicable)
    let originalImageBase64: String?           // Original scanned image
    let signatureImageBase64: String           // Employee signature as PNG
    let employeeReviewTimestamp: Date          // When employee confirmed review
    let employeeSignatureTimestamp: Date       // When employee signed
    let supervisorCertificationTimestamp: Date // When supervisor certified
    let supervisorId: String?                  // Supervisor's employee ID
    let supervisorName: String?                // Supervisor's name
    let submittedBy: String                    // Employee who submitted
    let submittedById: String?                 // Employee's ID
    let deviceId: String                       // Device identifier
    let appVersion: String                     // App version
    let versionHash: String                    // Hash of document content for integrity
    let submissionTimestamp: Date              // Final submission timestamp
    
    init(
        id: UUID = UUID(),
        complaintId: String,
        documentId: UUID,
        originalText: String,
        cleanedText: String,
        translatedText: String? = nil,
        originalImageBase64: String? = nil,
        signatureImageBase64: String,
        employeeReviewTimestamp: Date,
        employeeSignatureTimestamp: Date,
        supervisorCertificationTimestamp: Date,
        supervisorId: String? = nil,
        supervisorName: String? = nil,
        submittedBy: String,
        submittedById: String? = nil,
        deviceId: String,
        appVersion: String,
        versionHash: String,
        submissionTimestamp: Date = Date()
    ) {
        self.id = id
        self.complaintId = complaintId
        self.documentId = documentId
        self.originalText = originalText
        self.cleanedText = cleanedText
        self.translatedText = translatedText
        self.originalImageBase64 = originalImageBase64
        self.signatureImageBase64 = signatureImageBase64
        self.employeeReviewTimestamp = employeeReviewTimestamp
        self.employeeSignatureTimestamp = employeeSignatureTimestamp
        self.supervisorCertificationTimestamp = supervisorCertificationTimestamp
        self.supervisorId = supervisorId
        self.supervisorName = supervisorName
        self.submittedBy = submittedBy
        self.submittedById = submittedById
        self.deviceId = deviceId
        self.appVersion = appVersion
        self.versionHash = versionHash
        self.submissionTimestamp = submissionTimestamp
    }
    
    /// Generate a SHA-256 hash of the document content for integrity verification
    static func generateVersionHash(
        originalText: String,
        cleanedText: String,
        translatedText: String?,
        signatureData: Data
    ) -> String {
        var content = originalText + cleanedText
        if let translated = translatedText {
            content += translated
        }
        content += signatureData.base64EncodedString()
        
        let data = Data(content.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Workflow Step Enum
enum DocumentWorkflowStep: Int, CaseIterable {
    case employeeReview = 0
    case employeeSignature = 1
    case supervisorCertification = 2
    
    var title: String {
        switch self {
        case .employeeReview:
            return "Step 1: Employee Review"
        case .employeeSignature:
            return "Step 2: Digital Signature"
        case .supervisorCertification:
            return "Step 3: Supervisor Certification"
        }
    }
    
    var description: String {
        switch self {
        case .employeeReview:
            return "Please review the document content carefully before signing."
        case .employeeSignature:
            return "Provide your digital signature to confirm the document."
        case .supervisorCertification:
            return "Supervisor must certify the document acceptance."
        }
    }
    
    var icon: String {
        switch self {
        case .employeeReview:
            return "doc.text.magnifyingglass"
        case .employeeSignature:
            return "signature"
        case .supervisorCertification:
            return "checkmark.seal.fill"
        }
    }
}

// MARK: - Document Review Workflow View
struct DocumentReviewWorkflowView: View {
    // MARK: - Properties
    let caseId: String
    let documentType: CaseDocumentType
    let originalText: String
    let cleanedText: String
    let translatedText: String?
    let originalImageBase64: String?
    let submittedBy: InvolvedEmployee?
    let onComplete: (DocumentAuditLog) -> Void
    let onCancel: () -> Void
    
    // MARK: - Environment
    @EnvironmentObject private var appState: AppState
    
    // MARK: - State
    @State private var currentStep: DocumentWorkflowStep = .employeeReview
    @State private var employeeReviewConfirmed: Bool = false
    @State private var employeeReviewTimestamp: Date?
    @State private var signatureImage: UIImage?
    @State private var employeeSignatureTimestamp: Date?
    @State private var supervisorCertificationConfirmed: Bool = false
    @State private var supervisorCertificationTimestamp: Date?
    @State private var supervisorId: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    /// Current user's full name from AppState (auto-populated, read-only)
    private var supervisorName: String {
        let first = appState.firstName ?? ""
        let last = appState.lastName ?? ""
        let fullName = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        return fullName.isEmpty ? (appState.email ?? "Unknown User") : fullName
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                
                Divider()
                
                // Step content
                ScrollView {
                    VStack(spacing: 20) {
                        stepHeader
                        
                        // Content based on current step
                        switch currentStep {
                        case .employeeReview:
                            employeeReviewContent
                        case .employeeSignature:
                            employeeSignatureContent
                        case .supervisorCertification:
                            supervisorCertificationContent
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                // Navigation buttons
                navigationButtons
                    .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Document Acceptance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.red)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        HStack(spacing: 0) {
            ForEach(DocumentWorkflowStep.allCases, id: \.rawValue) { step in
                HStack(spacing: 0) {
                    // Step circle
                    ZStack {
                        Circle()
                            .fill(stepCircleColor(for: step))
                            .frame(width: 32, height: 32)
                        
                        if isStepCompleted(step) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(step.rawValue + 1)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(step == currentStep ? .white : .gray)
                        }
                    }
                    
                    // Connector line (except for last step)
                    if step != .supervisorCertification {
                        Rectangle()
                            .fill(isStepCompleted(step) ? Color.green : Color.gray.opacity(0.3))
                            .frame(height: 3)
                    }
                }
                .layoutPriority(step == .supervisorCertification ? 0 : 1)
            }
        }
        .padding(.horizontal, 24)
    }
    
    private func stepCircleColor(for step: DocumentWorkflowStep) -> Color {
        if isStepCompleted(step) {
            return .green
        } else if step == currentStep {
            return .accentColor
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    private func isStepCompleted(_ step: DocumentWorkflowStep) -> Bool {
        switch step {
        case .employeeReview:
            return employeeReviewTimestamp != nil
        case .employeeSignature:
            return employeeSignatureTimestamp != nil && signatureImage != nil
        case .supervisorCertification:
            return supervisorCertificationTimestamp != nil
        }
    }
    
    // MARK: - Step Header
    private var stepHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: currentStep.icon)
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            
            Text(currentStep.title)
                .font(.headline)
            
            Text(currentStep.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Employee Review Content
    private var employeeReviewContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Document preview
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Document Type", systemImage: "doc.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(documentType.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            // Original text preview (in original language)
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Original Text", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView {
                        Text(originalText)
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                }
            }
            
            // Translated text preview (if available)
            if let translated = translatedText, !translated.isEmpty {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Translated Text", systemImage: "globe")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView {
                            Text(translated)
                                .font(.system(size: 14))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 200)
                    }
                }
            }
            
            // Confirmation checkbox
            confirmationCheckbox(
                isChecked: $employeeReviewConfirmed,
                text: "I confirm that I have reviewed this complaint and the text accurately reflects the submitted complaint based on my review."
            )
            .padding(.top, 8)
        }
    }
    
    // MARK: - Employee Signature Content
    private var employeeSignatureContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Signature instructions
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Digital Signature", systemImage: "signature")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Please sign using your finger in the box below. Your signature will be recorded as part of the document audit trail.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Signature canvas
            SignatureCanvasView(signatureImage: $signatureImage)
                .padding(.vertical, 8)
            
            // Signature status
            if signatureImage != nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Signature captured")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            
            // Employee acknowledgment
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Acknowledgment", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("By signing above, I acknowledge that I have reviewed the document content and confirm its accuracy to the best of my knowledge.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Supervisor Certification Content
    private var supervisorCertificationContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Supervisor info
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Supervisor Information", systemImage: "person.badge.shield.checkmark")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Supervisor or Manager ID", text: $supervisorId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.allCharacters)
                    
                    // Supervisor name (auto-populated, read-only)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Supervisor Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(supervisorName)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
            
            // Summary of previous steps
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Document Review Summary", systemImage: "list.bullet.clipboard")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        summaryRow(
                            icon: "doc.text.magnifyingglass",
                            label: "Employee Review",
                            status: employeeReviewTimestamp != nil ? "Completed" : "Pending",
                            timestamp: employeeReviewTimestamp
                        )
                        
                        summaryRow(
                            icon: "signature",
                            label: "Digital Signature",
                            status: signatureImage != nil ? "Captured" : "Pending",
                            timestamp: employeeSignatureTimestamp
                        )
                    }
                }
            }
            
            // Supervisor certification checkbox
            confirmationCheckbox(
                isChecked: $supervisorCertificationConfirmed,
                text: "As the supervising authority, I certify that the employee has properly reviewed the document, provided their digital signature, and the submission process has been completed in accordance with company policy."
            )
            .padding(.top, 8)
            
            // Audit log notice
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Audit Trail Notice", systemImage: "lock.shield")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    
                    Text("Upon submission, a comprehensive audit log will be created containing all timestamps, signatures, and document content. This log is tamper-evident and includes a cryptographic hash for verification purposes.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Helper Views
    private func confirmationCheckbox(isChecked: Binding<Bool>, text: String) -> some View {
        Button(action: {
            isChecked.wrappedValue.toggle()
        }) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isChecked.wrappedValue ? Color.accentColor : Color.gray, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isChecked.wrappedValue {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func summaryRow(icon: String, label: String, status: String, timestamp: Date?) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            Text(label)
                .font(.caption)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(status)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(status == "Pending" ? .orange : .green)
                
                if let time = timestamp {
                    Text(time, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            // Back button
            if currentStep != .employeeReview {
                Button(action: goToPreviousStep) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            
            Spacer()
            
            // Next/Submit button
            if currentStep == .supervisorCertification {
                Button(action: submitDocument) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Submit Document")
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(canSubmit ? Color.green : Color.gray)
                    .cornerRadius(10)
                }
                .disabled(!canSubmit || isSubmitting)
            } else {
                Button(action: goToNextStep) {
                    HStack {
                        Text("Continue")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(canProceed ? Color.accentColor : Color.gray)
                    .cornerRadius(10)
                }
                .disabled(!canProceed)
            }
        }
    }
    
    // MARK: - Navigation Logic
    private var canProceed: Bool {
        switch currentStep {
        case .employeeReview:
            return employeeReviewConfirmed
        case .employeeSignature:
            return signatureImage != nil
        case .supervisorCertification:
            return supervisorCertificationConfirmed
        }
    }
    
    private var canSubmit: Bool {
        return employeeReviewTimestamp != nil &&
            signatureImage != nil &&
            employeeSignatureTimestamp != nil &&
            supervisorCertificationConfirmed
    }
    
    private func goToNextStep() {
        switch currentStep {
        case .employeeReview:
            if employeeReviewConfirmed {
                employeeReviewTimestamp = Date()
                withAnimation {
                    currentStep = .employeeSignature
                }
            }
        case .employeeSignature:
            if signatureImage != nil {
                employeeSignatureTimestamp = Date()
                withAnimation {
                    currentStep = .supervisorCertification
                }
            }
        case .supervisorCertification:
            break // Handled by submit
        }
    }
    
    private func goToPreviousStep() {
        switch currentStep {
        case .employeeReview:
            break // Can't go back
        case .employeeSignature:
            withAnimation {
                currentStep = .employeeReview
            }
        case .supervisorCertification:
            withAnimation {
                currentStep = .employeeSignature
            }
        }
    }
    
    // MARK: - Submit Document
    private func submitDocument() {
        guard canSubmit,
              let signature = signatureImage,
              let signatureData = signature.pngData(),
              let reviewTime = employeeReviewTimestamp,
              let signatureTime = employeeSignatureTimestamp else {
            errorMessage = "Please complete all required steps before submitting."
            showError = true
            return
        }
        
        isSubmitting = true
        supervisorCertificationTimestamp = Date()
        
        // Get device and app information
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        
        // Generate version hash
        let versionHash = DocumentAuditLog.generateVersionHash(
            originalText: originalText,
            cleanedText: cleanedText,
            translatedText: translatedText,
            signatureData: signatureData
        )
        
        // Create audit log
        let auditLog = DocumentAuditLog(
            complaintId: caseId,
            documentId: UUID(),
            originalText: originalText,
            cleanedText: cleanedText,
            translatedText: translatedText,
            originalImageBase64: originalImageBase64,
            signatureImageBase64: signatureData.base64EncodedString(),
            employeeReviewTimestamp: reviewTime,
            employeeSignatureTimestamp: signatureTime,
            supervisorCertificationTimestamp: supervisorCertificationTimestamp ?? Date(),
            supervisorId: supervisorId.isEmpty ? nil : supervisorId,
            supervisorName: supervisorName,  // Auto-populated from current user
            submittedBy: submittedBy?.name ?? "Unknown",
            submittedById: submittedBy?.id.uuidString,
            deviceId: deviceId,
            appVersion: appVersion,
            versionHash: versionHash
        )
        
        // Complete the workflow
        onComplete(auditLog)
    }
}

// MARK: - Preview
#Preview {
    DocumentReviewWorkflowView(
        caseId: "CASE-001",
        documentType: .complaintA,
        originalText: "This is the original OCR text from the scanned document...",
        cleanedText: "This is the cleaned and structured text after AI processing...",
        translatedText: nil as String?,
        originalImageBase64: nil as String?,
        submittedBy: nil as InvolvedEmployee?,
        onComplete: { auditLog in
            print("Document submitted with audit log: \(auditLog.id)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}
