//
//  DocumentShareSheet.swift
//  MeetingIntelligence
//
//  Phase 8: Document Share Sheet
//  UIActivityViewController wrapper for sharing exported documents
//

import SwiftUI
import UIKit

struct DocumentShareSheet: UIViewControllerRepresentable {
    let data: Data
    let filename: String
    let format: ExportFormat
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Write data to temporary file
        let fileExtension: String
        let mimeType: String
        
        switch format {
        case .pdf:
            fileExtension = "pdf"
            mimeType = "application/pdf"
        case .html:
            fileExtension = "html"
            mimeType = "text/html"
        case .plainText:
            fileExtension = "txt"
            mimeType = "text/plain"
        case .email:
            fileExtension = "eml"
            mimeType = "message/rfc822"
        }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(filename).\(fileExtension)")
        
        do {
            try data.write(to: tempURL)
        } catch {
            print("Failed to write temp file: \(error)")
        }
        
        let activityVC = UIActivityViewController(
            activityItems: [tempURL],
            applicationActivities: nil
        )
        
        // Exclude certain activity types if needed
        activityVC.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks
        ]
        
        return activityVC
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}

// MARK: - Document Preview Sheet
struct DocumentPreviewSheet: UIViewControllerRepresentable {
    let data: Data
    let filename: String
    let format: ExportFormat
    @Binding var isPresented: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let previewVC = DocumentPreviewViewController()
        previewVC.delegate = context.coordinator
        
        // Write data to temp file
        let fileExtension = format == .pdf ? "pdf" : (format == .html ? "html" : "txt")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(filename).\(fileExtension)")
        
        do {
            try data.write(to: tempURL)
            previewVC.documentURL = tempURL
        } catch {
            print("Failed to write temp file: \(error)")
        }
        
        let navController = UINavigationController(rootViewController: previewVC)
        return navController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No update needed
    }
    
    class Coordinator: NSObject, DocumentPreviewDelegate {
        let parent: DocumentPreviewSheet
        
        init(_ parent: DocumentPreviewSheet) {
            self.parent = parent
        }
        
        func documentPreviewDidDismiss() {
            parent.isPresented = false
        }
    }
}

// MARK: - Document Preview Delegate
protocol DocumentPreviewDelegate: AnyObject {
    func documentPreviewDidDismiss()
}

// MARK: - Document Preview View Controller
class DocumentPreviewViewController: UIViewController {
    weak var delegate: DocumentPreviewDelegate?
    var documentURL: URL?
    
    private var textView: UITextView!
    private var webView: WKWebView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        title = "Preview"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissPreview)
        )
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(shareDocument)
        )
        
        setupPreview()
    }
    
    private func setupPreview() {
        guard let url = documentURL else { return }
        
        let fileExtension = url.pathExtension.lowercased()
        
        if fileExtension == "pdf" {
            // Use PDFKit for PDF preview
            if let pdfDocument = PDFDocument(url: url) {
                let pdfView = PDFView(frame: view.bounds)
                pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                pdfView.document = pdfDocument
                pdfView.autoScales = true
                view.addSubview(pdfView)
            }
        } else if fileExtension == "html" {
            // Use WKWebView for HTML
            let webView = WKWebView(frame: view.bounds)
            webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            view.addSubview(webView)
            self.webView = webView
        } else {
            // Use text view for plain text
            textView = UITextView(frame: view.bounds)
            textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            textView.isEditable = false
            textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
            
            if let content = try? String(contentsOf: url) {
                textView.text = content
            }
            
            view.addSubview(textView)
        }
    }
    
    @objc private func dismissPreview() {
        dismiss(animated: true) {
            self.delegate?.documentPreviewDidDismiss()
        }
    }
    
    @objc private func shareDocument() {
        guard let url = documentURL else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        present(activityVC, animated: true)
    }
}

import PDFKit
import WebKit

// MARK: - Email Composer Sheet
struct EmailComposerSheet: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let attachmentData: Data?
    let attachmentFilename: String?
    let attachmentMimeType: String?
    let recipients: [String]
    let ccRecipients: [String]
    @Binding var isPresented: Bool
    let onResult: (MFMailComposeResult) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UINavigationController {
        // Check if mail is available
        guard MFMailComposeViewController.canSendMail() else {
            // Return a placeholder if mail not available
            let alertVC = UIAlertController(
                title: "Mail Unavailable",
                message: "Please configure an email account in Settings",
                preferredStyle: .alert
            )
            alertVC.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                isPresented = false
            })
            let navController = UINavigationController(rootViewController: UIViewController())
            return navController
        }
        
        let mailVC = MFMailComposeViewController()
        mailVC.mailComposeDelegate = context.coordinator
        mailVC.setSubject(subject)
        mailVC.setMessageBody(body, isHTML: false)
        mailVC.setToRecipients(recipients)
        mailVC.setCcRecipients(ccRecipients)
        
        if let data = attachmentData,
           let filename = attachmentFilename,
           let mimeType = attachmentMimeType {
            mailVC.addAttachmentData(data, mimeType: mimeType, fileName: filename)
        }
        
        return mailVC
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No update needed
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: EmailComposerSheet
        
        init(_ parent: EmailComposerSheet) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.isPresented = false
            parent.onResult(result)
        }
    }
}

import MessageUI

// MARK: - Quick Share View
struct QuickShareView: View {
    let document: GeneratedDocument
    let caseNumber: String
    let onShareMethod: (ShareMethod) -> Void
    let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    enum ShareMethod: String, CaseIterable {
        case email = "Email"
        case messages = "Messages"
        case airdrop = "AirDrop"
        case files = "Save to Files"
        case clipboard = "Copy to Clipboard"
        
        var icon: String {
            switch self {
            case .email: return "envelope.fill"
            case .messages: return "message.fill"
            case .airdrop: return "airplayaudio"
            case .files: return "folder.fill"
            case .clipboard: return "doc.on.doc.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .email: return .blue
            case .messages: return .green
            case .airdrop: return .purple
            case .files: return .orange
            case .clipboard: return .gray
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Document info
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    
                    Text(document.title)
                        .font(.system(size: 15, weight: .semibold))
                    
                    Text("Case: \(caseNumber)")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                }
                .padding()
                
                Divider()
                
                // Share options
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(ShareMethod.allCases, id: \.self) { method in
                        shareButton(method: method)
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private func shareButton(method: ShareMethod) -> some View {
        Button {
            onShareMethod(method)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(method.color.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: method.icon)
                        .font(.system(size: 22))
                        .foregroundColor(method.color)
                }
                
                Text(method.rawValue)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
    }
}
