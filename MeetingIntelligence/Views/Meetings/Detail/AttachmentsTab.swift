//
//  AttachmentsTab.swift
//  MeetingIntelligence
//
//  Phase 2 - Attachments Viewer
//

import SwiftUI
import QuickLook

struct AttachmentsTab: View {
    @ObservedObject var viewModel: MeetingDetailViewModel
    @State private var selectedAttachment: MeetingAttachment?
    @State private var showDocumentPicker = false
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: AppSpacing.md)
    ]
    
    var body: some View {
        ScrollView {
            if viewModel.attachments.isEmpty {
                emptyState
            } else {
                attachmentsGrid
            }
        }
        .background(AppColors.background)
        .refreshable {
            await viewModel.refreshMeeting()
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "paperclip")
                .font(.system(size: 60))
                .foregroundColor(AppColors.textTertiary)
            
            Text("No Attachments")
                .font(AppTypography.title3)
                .foregroundColor(AppColors.textPrimary)
            
            Text("Files and documents shared during the meeting will appear here.")
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    // MARK: - Attachments Grid
    private var attachmentsGrid: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header
            HStack {
                Text("\(viewModel.attachments.count) attachments")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                
                Spacer()
                
                Text(totalSize)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.horizontal, AppSpacing.md)
            
            // Grid
            LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                ForEach(viewModel.attachments, id: \.id) { attachment in
                    AttachmentCard(attachment: attachment) {
                        selectedAttachment = attachment
                    }
                }
            }
            .padding(AppSpacing.md)
        }
    }
    
    private var totalSize: String {
        let total = viewModel.attachments.reduce(0) { $0 + ($1.fileSize ?? 0) }
        return formatFileSize(total)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Attachment Card
struct AttachmentCard: View {
    let attachment: MeetingAttachment
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: AppSpacing.sm) {
                // Preview or Icon
                attachmentPreview
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
                    .background(AppColors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.small))
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(attachment.fileName)
                        .font(AppTypography.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                    
                    HStack(spacing: AppSpacing.xs) {
                        Text(attachment.fileExtension.uppercased())
                            .font(AppTypography.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(fileTypeColor)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(fileTypeColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        if let size = attachment.fileSize {
                            Text(formatFileSize(size))
                                .font(AppTypography.caption2)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(AppSpacing.sm)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var attachmentPreview: some View {
        if attachment.isImage, let thumbnailUrl = attachment.thumbnailUrl {
            AsyncImage(url: URL(string: thumbnailUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                fileTypeIcon
            }
        } else {
            fileTypeIcon
        }
    }
    
    private var fileTypeIcon: some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: fileTypeSystemImage)
                .font(.system(size: 32))
                .foregroundColor(fileTypeColor)
            
            Text(attachment.fileExtension.uppercased())
                .font(AppTypography.caption2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textTertiary)
        }
    }
    
    private var fileTypeSystemImage: String {
        switch attachment.fileType {
        case .image: return "photo"
        case .pdf: return "doc.text"
        case .document: return "doc.richtext"
        case .spreadsheet: return "tablecells"
        case .presentation: return "rectangle.on.rectangle"
        case .video: return "video"
        case .audio: return "waveform"
        case .other: return "doc"
        }
    }
    
    private var fileTypeColor: Color {
        switch attachment.fileType {
        case .image: return Color.pink
        case .pdf: return Color.red
        case .document: return AppColors.primary
        case .spreadsheet: return Color.green
        case .presentation: return Color.orange
        case .video: return Color.purple
        case .audio: return AppColors.accent
        case .other: return AppColors.textSecondary
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Meeting Attachment Model Extension
extension MeetingAttachment {
    // Map 'name' to 'fileName' for convenience
    var fileName: String { name }
    
    // Map 'size' to 'fileSize' for convenience
    var fileSize: Int64? {
        guard let size = size else { return nil }
        return Int64(size)
    }
    
    // Thumbnail URL (derive from URL if available)
    var thumbnailUrl: String? { nil }
    
    var fileExtension: String {
        URL(string: name)?.pathExtension ?? (name.components(separatedBy: ".").last ?? "")
    }
    
    var isImage: Bool {
        fileType == .image
    }
    
    var fileType: AttachmentFileType {
        let ext = fileExtension.lowercased()
        
        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "webp":
            return .image
        case "pdf":
            return .pdf
        case "doc", "docx", "txt", "rtf", "pages":
            return .document
        case "xls", "xlsx", "csv", "numbers":
            return .spreadsheet
        case "ppt", "pptx", "key":
            return .presentation
        case "mp4", "mov", "avi", "mkv":
            return .video
        case "mp3", "wav", "m4a", "aac":
            return .audio
        default:
            return .other
        }
    }
}

enum AttachmentFileType {
    case image
    case pdf
    case document
    case spreadsheet
    case presentation
    case video
    case audio
    case other
}

// MARK: - Preview
#Preview {
    Text("Attachments Tab Preview")
}
