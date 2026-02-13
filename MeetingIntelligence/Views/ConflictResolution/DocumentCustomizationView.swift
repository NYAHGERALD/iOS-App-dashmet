//
//  DocumentCustomizationView.swift
//  MeetingIntelligence
//
//  Phase 8: Document Customization Panel
//  Allows users to adjust tone, length, and other document settings
//

import SwiftUI

// MARK: - Document Customization Settings
struct DocumentCustomizationSettings: Equatable {
    var toneLevel: Double = 0.5 // 0 = Formal, 1 = Conversational
    var lengthPreference: LengthPreference = .standard
    var includeExamples: Bool = false
    var simplifyLanguage: Bool = false
    var removeTechnicalJargon: Bool = false
    var addMoreContext: Bool = false
    var useOrganizationalTemplate: Bool = false
    var selectedTemplateId: String? = nil
    
    enum LengthPreference: String, CaseIterable, Identifiable {
        case concise = "concise"
        case standard = "standard"
        case detailed = "detailed"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .concise: return "Concise"
            case .standard: return "Standard"
            case .detailed: return "Detailed"
            }
        }
        
        var description: String {
            switch self {
            case .concise: return "Brief and to the point"
            case .standard: return "Balanced coverage"
            case .detailed: return "Comprehensive details"
            }
        }
        
        var icon: String {
            switch self {
            case .concise: return "text.alignleft"
            case .standard: return "text.justify"
            case .detailed: return "doc.text"
            }
        }
    }
}

// MARK: - Document Customization View
struct DocumentCustomizationView: View {
    @Binding var settings: DocumentCustomizationSettings
    let actionType: ActionType
    let onApply: () -> Void
    let onCancel: () -> Void
    
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
                    // Tone Adjustment
                    toneSection
                    
                    // Length Preference
                    lengthSection
                    
                    // Language Options
                    languageOptionsSection
                    
                    // Template Options
                    templateSection
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Customize Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Tone Section
    private var toneSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Tone Adjustment")
            
            VStack(spacing: 12) {
                // Tone Slider with Labels
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Formal")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(settings.toneLevel < 0.3 ? .blue : textSecondary)
                        Text("Professional")
                            .font(.system(size: 10))
                            .foregroundColor(textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text("Balanced")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(settings.toneLevel >= 0.3 && settings.toneLevel <= 0.7 ? .blue : textSecondary)
                        Text("Neutral")
                            .font(.system(size: 10))
                            .foregroundColor(textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Conversational")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(settings.toneLevel > 0.7 ? .blue : textSecondary)
                        Text("Approachable")
                            .font(.system(size: 10))
                            .foregroundColor(textSecondary)
                    }
                }
                
                // Custom Slider
                Slider(value: $settings.toneLevel, in: 0...1, step: 0.1)
                    .tint(.blue)
                
                // Current tone description
                Text(toneDescription)
                    .font(.system(size: 12))
                    .foregroundColor(textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(innerCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var toneDescription: String {
        switch settings.toneLevel {
        case 0..<0.3:
            return "Document will use formal, professional language appropriate for official records."
        case 0.3..<0.7:
            return "Document will use balanced language that is professional yet accessible."
        default:
            return "Document will use friendly, approachable language while maintaining professionalism."
        }
    }
    
    // MARK: - Length Section
    private var lengthSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Length Preference")
            
            HStack(spacing: 12) {
                ForEach(DocumentCustomizationSettings.LengthPreference.allCases) { preference in
                    lengthOptionButton(preference)
                }
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func lengthOptionButton(_ preference: DocumentCustomizationSettings.LengthPreference) -> some View {
        let isSelected = settings.lengthPreference == preference
        
        return Button {
            settings.lengthPreference = preference
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue.opacity(0.15) : innerCardBackground)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: preference.icon)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .blue : textSecondary)
                }
                
                VStack(spacing: 2) {
                    Text(preference.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSelected ? .blue : textPrimary)
                    
                    Text(preference.description)
                        .font(.system(size: 10))
                        .foregroundColor(textSecondary)
                        .multilineTextAlignment(.center)
                }
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
    
    // MARK: - Language Options Section
    private var languageOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Language Options")
            
            VStack(spacing: 0) {
                languageToggle(
                    icon: "textformat",
                    title: "Simplify Language",
                    description: "Use simpler words and shorter sentences",
                    isOn: $settings.simplifyLanguage
                )
                
                Divider().padding(.leading, 52)
                
                languageToggle(
                    icon: "plus.bubble",
                    title: "Add More Context",
                    description: "Include additional background information",
                    isOn: $settings.addMoreContext
                )
                
                Divider().padding(.leading, 52)
                
                languageToggle(
                    icon: "lightbulb",
                    title: "Include Examples",
                    description: "Add practical examples where relevant",
                    isOn: $settings.includeExamples
                )
                
                Divider().padding(.leading, 52)
                
                languageToggle(
                    icon: "xmark.circle",
                    title: "Remove Technical Jargon",
                    description: "Replace industry terms with plain language",
                    isOn: $settings.removeTechnicalJargon
                )
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func languageToggle(icon: String, title: String, description: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textPrimary)
                    
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
                }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .blue))
        .padding(.vertical, 12)
    }
    
    // MARK: - Template Section
    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Template Options")
            
            VStack(spacing: 12) {
                Toggle(isOn: $settings.useOrganizationalTemplate) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .frame(width: 28)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use Organizational Template")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(textPrimary)
                            
                            Text("Apply company-specific document format")
                                .font(.system(size: 12))
                                .foregroundColor(textSecondary)
                        }
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                if settings.useOrganizationalTemplate {
                    // Template Selection
                    VStack(spacing: 8) {
                        templateOption(id: "default", name: "Default Template", isRecommended: true)
                        templateOption(id: "formal", name: "Formal HR Template", isRecommended: false)
                        templateOption(id: "progressive", name: "Progressive Discipline", isRecommended: false)
                    }
                    .padding()
                    .background(innerCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func templateOption(id: String, name: String, isRecommended: Bool) -> some View {
        let isSelected = settings.selectedTemplateId == id
        
        return Button {
            settings.selectedTemplateId = id
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .blue : textSecondary)
                
                Text(name)
                    .font(.system(size: 14))
                    .foregroundColor(textPrimary)
                
                if isRecommended {
                    Text("Recommended")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green)
                        .clipShape(Capsule())
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helper
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(textPrimary)
    }
}

// MARK: - Preview
#Preview {
    DocumentCustomizationView(
        settings: .constant(DocumentCustomizationSettings()),
        actionType: .coaching,
        onApply: {},
        onCancel: {}
    )
}
