//
//  SignatureCaptureSheet.swift
//  MeetingIntelligence
//
//  Phase 8: Signature Capture Integration Sheet
//  Modal sheet for capturing signatures on documents
//

import SwiftUI
import UIKit

// MARK: - Signature Type
enum SignatureType: String, CaseIterable, Identifiable {
    case employee = "employee"
    case supervisor = "supervisor"
    case hrRepresentative = "hr_representative"
    case witness = "witness"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .employee: return "Employee"
        case .supervisor: return "Supervisor"
        case .hrRepresentative: return "HR Representative"
        case .witness: return "Witness"
        }
    }
    
    var icon: String {
        switch self {
        case .employee: return "person.fill"
        case .supervisor: return "person.badge.shield.checkmark.fill"
        case .hrRepresentative: return "person.crop.rectangle.stack.fill"
        case .witness: return "eye.fill"
        }
    }
}

// MARK: - Captured Signature
struct CapturedSignature: Identifiable {
    let id: UUID
    let type: SignatureType
    let signerName: String
    let image: UIImage
    let capturedAt: Date
    var firebaseURL: String?  // Firebase Storage URL - NOT stored locally
    var isUploading: Bool = false
    var uploadError: String?
    
    init(id: UUID = UUID(), type: SignatureType, signerName: String, image: UIImage, capturedAt: Date = Date(), firebaseURL: String? = nil) {
        self.id = id
        self.type = type
        self.signerName = signerName
        self.image = image
        self.capturedAt = capturedAt
        self.firebaseURL = firebaseURL
    }
}

// MARK: - Signature Capture Sheet
struct SignatureCaptureSheet: View {
    @Binding var capturedSignatures: [CapturedSignature]
    let documentType: ActionType
    let employeeNames: [String]
    let supervisorName: String
    let caseNumber: String      // Required for Firebase Storage path
    let documentId: String      // Document ID for Firebase Storage path
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    @State private var currentSignatureType: SignatureType = .employee
    @State private var currentSignerName: String = ""
    @State private var signatureImage: UIImage?
    @State private var showSignatureCanvas = false
    @State private var isUploadingSignature = false
    @State private var uploadError: String?
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    private var innerCardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.gray.opacity(0.08)
    }
    
    private var requiredSignatures: [SignatureType] {
        switch documentType {
        case .coaching:
            return [.employee, .supervisor]
        case .counseling:
            return [.employee, .supervisor]
        case .warning:
            return [.employee, .supervisor, .hrRepresentative]
        case .escalate:
            return [.supervisor]
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection
                    
                    // Required Signatures Status
                    signaturesStatusSection
                    
                    // Add Signature Section
                    addSignatureSection
                    
                    // Captured Signatures
                    if !capturedSignatures.isEmpty {
                        capturedSignaturesSection
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Capture Signatures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onComplete()
                    }
                    .fontWeight(.semibold)
                    .disabled(!allRequiredSignaturesCaptured)
                }
            }
            .sheet(isPresented: $showSignatureCanvas) {
                SignatureCanvasSheet(
                    signatureType: currentSignatureType,
                    signerName: currentSignerName,
                    onSign: { image in
                        // Create signature with pending upload
                        var signature = CapturedSignature(
                            type: currentSignatureType,
                            signerName: currentSignerName,
                            image: image
                        )
                        signature.isUploading = true
                        capturedSignatures.append(signature)
                        showSignatureCanvas = false
                        
                        // Upload to Firebase Storage in background
                        Task {
                            await uploadSignatureToFirebase(signature: signature, image: image)
                        }
                    },
                    onCancel: {
                        showSignatureCanvas = false
                    }
                )
            }
            .alert("Upload Error", isPresented: .constant(uploadError != nil)) {
                Button("OK") { uploadError = nil }
            } message: {
                Text(uploadError ?? "Unknown error")
            }
        }
    }
    
    // MARK: - Upload Signature to Firebase
    private func uploadSignatureToFirebase(signature: CapturedSignature, image: UIImage) async {
        guard let userId = ConflictResolutionManager.shared.currentUserId else {
            await MainActor.run {
                updateSignatureError(signature.id, error: "User not authenticated")
            }
            return
        }
        
        guard let imageData = image.pngData() else {
            await MainActor.run {
                updateSignatureError(signature.id, error: "Failed to convert signature to data")
            }
            return
        }
        
        do {
            let signatureId = "\(signature.type.rawValue)_\(signature.id.uuidString)"
            let firebaseURL = try await FirebaseStorageService.shared.uploadSignatureImage(
                imageData,
                caseNumber: caseNumber,
                documentId: "\(documentId)_\(signatureId)",
                userId: userId
            )
            
            await MainActor.run {
                updateSignatureURL(signature.id, url: firebaseURL)
            }
            
            // Log to audit trail
            AuditTrailService.shared.logSignatureCaptured(
                caseId: UUID(uuidString: documentId) ?? UUID(),
                caseNumber: caseNumber,
                signatureType: signature.type.rawValue,
                signerName: signature.signerName
            )
            
            print("✅ Signature uploaded to Firebase: \(firebaseURL)")
        } catch {
            print("❌ Failed to upload signature: \(error)")
            await MainActor.run {
                updateSignatureError(signature.id, error: error.localizedDescription)
            }
        }
    }
    
    private func updateSignatureURL(_ id: UUID, url: String) {
        if let index = capturedSignatures.firstIndex(where: { $0.id == id }) {
            capturedSignatures[index].firebaseURL = url
            capturedSignatures[index].isUploading = false
        }
    }
    
    private func updateSignatureError(_ id: UUID, error: String) {
        if let index = capturedSignatures.firstIndex(where: { $0.id == id }) {
            capturedSignatures[index].isUploading = false
            capturedSignatures[index].uploadError = error
        }
        uploadError = error
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "signature")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("Document Signatures Required")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Text("Capture signatures from all required parties to finalize the document.")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Signatures Status Section
    private var signaturesStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Required Signatures")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                Spacer()
                
                Text("\(capturedSignaturesCount)/\(requiredSignatures.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(allRequiredSignaturesCaptured ? .green : .orange)
            }
            
            ForEach(requiredSignatures) { type in
                signatureStatusRow(type)
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func signatureStatusRow(_ type: SignatureType) -> some View {
        let isCaptured = capturedSignatures.contains { $0.type == type }
        
        return HStack(spacing: 12) {
            Image(systemName: isCaptured ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundColor(isCaptured ? .green : textSecondary)
            
            Image(systemName: type.icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(type.displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(textPrimary)
            
            Spacer()
            
            if isCaptured {
                Text("Signed")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green)
                    .clipShape(Capsule())
            } else {
                Text("Pending")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var capturedSignaturesCount: Int {
        Set(capturedSignatures.map { $0.type }).intersection(Set(requiredSignatures)).count
    }
    
    private var allRequiredSignaturesCaptured: Bool {
        capturedSignaturesCount == requiredSignatures.count
    }
    
    // MARK: - Add Signature Section
    private var addSignatureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Signature")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textPrimary)
            
            // Signature Type Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Signature Type")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textSecondary)
                
                Picker("Type", selection: $currentSignatureType) {
                    ForEach(requiredSignatures) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Signer Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Signer Name")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textSecondary)
                
                if currentSignatureType == .employee && !employeeNames.isEmpty {
                    Picker("Employee", selection: $currentSignerName) {
                        ForEach(employeeNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding()
                    .background(innerCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else if currentSignatureType == .supervisor {
                    Text(supervisorName)
                        .font(.system(size: 14))
                        .foregroundColor(textPrimary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(innerCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onAppear {
                            currentSignerName = supervisorName
                        }
                } else {
                    TextField("Enter name", text: $currentSignerName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            
            // Capture Button
            Button {
                if currentSignerName.isEmpty {
                    if currentSignatureType == .supervisor {
                        currentSignerName = supervisorName
                    } else if currentSignatureType == .employee && !employeeNames.isEmpty {
                        currentSignerName = employeeNames[0]
                    }
                }
                showSignatureCanvas = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.tip")
                    Text("Capture Signature")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(currentSignerName.isEmpty && currentSignatureType != .supervisor ? Color.gray : Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(currentSignerName.isEmpty && currentSignatureType != .supervisor && currentSignatureType != .employee)
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            if !employeeNames.isEmpty {
                currentSignerName = employeeNames[0]
            }
        }
    }
    
    // MARK: - Captured Signatures Section
    private var capturedSignaturesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Captured Signatures")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textPrimary)
            
            ForEach(capturedSignatures) { signature in
                capturedSignatureRow(signature)
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func capturedSignatureRow(_ signature: CapturedSignature) -> some View {
        HStack(spacing: 12) {
            // Signature Preview
            Image(uiImage: signature.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 40)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(signature.signerName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textPrimary)
                    
                    // Upload status indicator
                    if signature.isUploading {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else if signature.firebaseURL != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    } else if signature.uploadError != nil {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                }
                
                HStack(spacing: 4) {
                    Text("\(signature.type.displayName)")
                        .font(.system(size: 11))
                        .foregroundColor(textSecondary)
                    
                    if signature.firebaseURL != nil {
                        Text("• Saved to cloud")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    } else if signature.isUploading {
                        Text("• Uploading...")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    } else if let error = signature.uploadError {
                        Text("• \(error)")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Retry button if upload failed
            if signature.uploadError != nil {
                Button {
                    Task {
                        await retryUpload(signature)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }
            }
            
            // Delete Button
            Button {
                // If uploaded to Firebase, also delete from storage
                if let url = signature.firebaseURL {
                    Task {
                        await deleteFromFirebase(url: url)
                    }
                }
                capturedSignatures.removeAll { $0.id == signature.id }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(innerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func retryUpload(_ signature: CapturedSignature) async {
        if let index = capturedSignatures.firstIndex(where: { $0.id == signature.id }) {
            await MainActor.run {
                capturedSignatures[index].isUploading = true
                capturedSignatures[index].uploadError = nil
            }
            await uploadSignatureToFirebase(signature: signature, image: signature.image)
        }
    }
    
    private func deleteFromFirebase(url: String) async {
        // Firebase Storage deletion happens server-side or via URL reference
        // For now, just log the deletion intent
        print("🗑️ Signature deleted from app (Firebase URL: \(url))")
    }
}

// MARK: - Signature Canvas Sheet
struct SignatureCanvasSheet: View {
    let signatureType: SignatureType
    let signerName: String
    let onSign: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var signatureImage: UIImage?
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Sign as \(signatureType.displayName)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    Text(signerName)
                        .font(.system(size: 14))
                        .foregroundColor(textSecondary)
                }
                .padding(.top)
                
                // Signature Canvas
                SignatureCanvasView(signatureImage: $signatureImage)
                    .frame(height: 200)
                    .padding(.horizontal)
                
                // Instructions
                Text("Sign in the box above using your finger")
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
                
                Spacer()
                
                // Buttons
                HStack(spacing: 16) {
                    Button {
                        signatureImage = nil
                    } label: {
                        Text("Clear")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button {
                        if let image = signatureImage {
                            onSign(image)
                        }
                    } label: {
                        Text("Confirm Signature")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(signatureImage == nil ? Color.gray : Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(signatureImage == nil)
                }
                .padding()
            }
            .navigationTitle("Capture Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SignatureCaptureSheet(
        capturedSignatures: .constant([]),
        documentType: .warning,
        employeeNames: ["John Smith", "Jane Doe"],
        supervisorName: "Mike Johnson",
        caseNumber: "CASE-2026-001",
        documentId: "doc-123",
        onComplete: {},
        onCancel: {}
    )
}
