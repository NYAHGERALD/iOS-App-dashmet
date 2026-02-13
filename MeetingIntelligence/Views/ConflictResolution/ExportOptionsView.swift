//
//  ExportOptionsView.swift
//  MeetingIntelligence
//
//  Phase 8: Export Options View
//  Allows users to select export format and destination
//

import SwiftUI
import UIKit

struct ExportOptionsView: View {
    let document: GeneratedDocument
    let caseNumber: String
    let onExport: (ExportFormat, ExportDestination, Data) -> Void
    let onCancel: () -> Void
    
    @State private var selectedFormat: ExportFormat = .pdf
    @State private var selectedDestination: ExportDestination = .download
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var includeSignatures = false
    
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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Document Preview Card
                    documentPreviewCard
                    
                    // Format Selection
                    formatSelectionSection
                    
                    // Destination Selection
                    destinationSelectionSection
                    
                    // Options
                    optionsSection
                    
                    // Export Button
                    exportButton
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Export Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
            .alert("Export Error", isPresented: .constant(exportError != nil)) {
                Button("OK") {
                    exportError = nil
                }
            } message: {
                Text(exportError ?? "")
            }
        }
    }
    
    // MARK: - Document Preview Card
    private var documentPreviewCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 48, height: 56)
                    
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textPrimary)
                        .lineLimit(2)
                    
                    Text("Case \(caseNumber)")
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Format Selection Section
    private var formatSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Format")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textPrimary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(ExportFormat.allCases) { format in
                    formatOption(format)
                }
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func formatOption(_ format: ExportFormat) -> some View {
        let isSelected = selectedFormat == format
        
        return Button {
            selectedFormat = format
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue.opacity(0.15) : innerCardBackground)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: format.icon)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .blue : textSecondary)
                }
                
                Text(format.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .blue : textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Destination Selection Section
    private var destinationSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export To")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textPrimary)
            
            ForEach(ExportDestination.allCases) { destination in
                destinationOption(destination)
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func destinationOption(_ destination: ExportDestination) -> some View {
        let isSelected = selectedDestination == destination
        
        return Button {
            selectedDestination = destination
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .blue : textSecondary)
                
                Image(systemName: destination.icon)
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                Text(destination.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textPrimary)
                
                Spacer()
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Options Section
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Toggle(isOn: $includeSignatures) {
                HStack(spacing: 12) {
                    Image(systemName: "signature")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Include Signatures")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(textPrimary)
                        
                        Text("Add captured signatures to document")
                            .font(.system(size: 12))
                            .foregroundColor(textSecondary)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Export Button
    private var exportButton: some View {
        Button {
            performExport()
        } label: {
            HStack(spacing: 8) {
                if isExporting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: selectedDestination.icon)
                }
                
                Text(isExporting ? "Exporting..." : "Export \(selectedFormat.displayName)")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isExporting ? Color.gray : Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isExporting)
    }
    
    // MARK: - Export Logic
    private func performExport() {
        isExporting = true
        
        Task {
            do {
                let data = try await DocumentExportService.shared.exportDocument(
                    document,
                    format: selectedFormat,
                    caseNumber: caseNumber,
                    includeSignatures: includeSignatures
                )
                
                await MainActor.run {
                    isExporting = false
                    onExport(selectedFormat, selectedDestination, data)
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ExportOptionsView(
        document: .coaching(CoachingDocument(
            title: "Coaching Session Guide",
            overview: "Overview text",
            discussionOutline: DiscussionOutline(opening: "Opening", keyPoints: [], transitionStatements: []),
            talkingPoints: [],
            questionsToAsk: [],
            behavioralFocusAreas: [],
            followUpPlan: FollowUpPlan(timeline: "2 weeks", checkInDates: [], successIndicators: [])
        )),
        caseNumber: "CR-2025-001",
        onExport: { _, _, _ in },
        onCancel: {}
    )
}
