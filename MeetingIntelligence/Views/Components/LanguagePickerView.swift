//
//  LanguagePickerView.swift
//  MeetingIntelligence
//
//  Language selection UI for speech recognition
//  Supports Pidgin English via Nigerian/Ghanaian English variants
//

import SwiftUI

// MARK: - Language Picker Button
struct LanguagePickerButton: View {
    @ObservedObject var languageManager = LanguageManager.shared
    @State private var showPicker = false
    
    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 6) {
                Text(languageManager.selectedLanguage.flag)
                    .font(.title2)
                
                Text(languageManager.selectedLanguage.name.components(separatedBy: " (").first ?? "")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.15))
            .cornerRadius(20)
        }
        .sheet(isPresented: $showPicker) {
            LanguagePickerSheet(languageManager: languageManager)
        }
    }
}

// MARK: - Compact Language Picker (for toolbar)
struct CompactLanguagePicker: View {
    @ObservedObject var speechService: SpeechRecognitionService
    @State private var showPicker = false
    
    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 4) {
                Text(speechService.currentLanguage?.flag ?? "🌍")
                    .font(.title3)
                
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .sheet(isPresented: $showPicker) {
            LanguagePickerSheet(languageManager: LanguageManager.shared, onSelect: { language in
                speechService.setLanguage(language)
            })
        }
    }
}

// MARK: - Language Picker Sheet
struct LanguagePickerSheet: View {
    @ObservedObject var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var onSelect: ((SupportedLanguage) -> Void)?
    
    var body: some View {
        NavigationStack {
            List {
                // Pidgin English Info Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Pidgin English Support")
                                .font(.headline)
                        }
                        
                        Text("For Pidgin English (Cameroon/Nigeria), select **English (Nigeria)** or **English (Ghana)** for best results. System correction will help improve accuracy.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Tip")
                }
                
                // Recent Languages
                if !languageManager.recentLanguages.isEmpty && searchText.isEmpty {
                    Section {
                        ForEach(languageManager.recentLanguages) { language in
                            LanguageRow(
                                language: language,
                                isSelected: language.id == languageManager.selectedLanguage.id,
                                onSelect: { selectLanguage(language) }
                            )
                        }
                    } header: {
                        Text("Recent")
                    }
                }
                
                // Recommended for Pidgin
                if searchText.isEmpty || searchText.lowercased().contains("pidgin") || 
                   searchText.lowercased().contains("nigeria") || searchText.lowercased().contains("cameroon") {
                    Section {
                        ForEach(languageManager.pidginSupportedLanguages()) { language in
                            LanguageRow(
                                language: language,
                                isSelected: language.id == languageManager.selectedLanguage.id,
                                onSelect: { selectLanguage(language) },
                                badge: "Pidgin Friendly"
                            )
                        }
                    } header: {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                            Text("Recommended for Pidgin English")
                        }
                    }
                }
                
                // English Variants
                if searchText.isEmpty || searchText.lowercased().contains("english") {
                    Section {
                        ForEach(languageManager.englishVariants().filter { 
                            !["en-NG", "en-GH", "en-KE", "en-ZA"].contains($0.id) 
                        }) { language in
                            LanguageRow(
                                language: language,
                                isSelected: language.id == languageManager.selectedLanguage.id,
                                onSelect: { selectLanguage(language) }
                            )
                        }
                    } header: {
                        Text("English Variants")
                    }
                }
                
                // All Languages (filtered)
                Section {
                    ForEach(filteredLanguages) { language in
                        LanguageRow(
                            language: language,
                            isSelected: language.id == languageManager.selectedLanguage.id,
                            onSelect: { selectLanguage(language) }
                        )
                    }
                } header: {
                    Text("All Languages")
                }
            }
            .searchable(text: $searchText, prompt: "Search languages...")
            .navigationTitle("Select Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var filteredLanguages: [SupportedLanguage] {
        if searchText.isEmpty {
            return languageManager.availableLanguages.filter { !$0.id.hasPrefix("en-") }
        } else {
            return languageManager.searchLanguages(searchText)
        }
    }
    
    private func selectLanguage(_ language: SupportedLanguage) {
        languageManager.selectLanguage(language)
        onSelect?(language)
        dismiss()
    }
}

// MARK: - Language Row
struct LanguageRow: View {
    let language: SupportedLanguage
    let isSelected: Bool
    let onSelect: () -> Void
    var badge: String? = nil
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Text(language.flag)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(language.name)
                            .foregroundColor(.primary)
                        
                        if let badge = badge {
                            Text(badge)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                    }
                    
                    if language.nativeName != language.name {
                        Text(language.nativeName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Language Switcher (inline)
struct QuickLanguageSwitcher: View {
    @ObservedObject var speechService: SpeechRecognitionService
    let languages: [SupportedLanguage]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(languages) { language in
                    Button {
                        speechService.setLanguage(language)
                    } label: {
                        HStack(spacing: 4) {
                            Text(language.flag)
                            Text(language.name.components(separatedBy: " (").first ?? "")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            speechService.currentLanguage?.id == language.id
                                ? Color.blue
                                : Color(.systemGray5)
                        )
                        .foregroundColor(
                            speechService.currentLanguage?.id == language.id
                                ? .white
                                : .primary
                        )
                        .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Language Status Badge
struct LanguageStatusBadge: View {
    @ObservedObject var speechService: SpeechRecognitionService
    
    var body: some View {
        HStack(spacing: 6) {
            Text(speechService.currentLanguage?.flag ?? "🌍")
            
            if speechService.isRecognizing {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                
                Text(speechService.recognizerStatus)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        LanguagePickerButton()
        
        LanguageStatusBadge(speechService: SpeechRecognitionService.shared)
        
        QuickLanguageSwitcher(
            speechService: SpeechRecognitionService.shared,
            languages: LanguageManager.shared.pidginSupportedLanguages()
        )
    }
    .padding()
}
