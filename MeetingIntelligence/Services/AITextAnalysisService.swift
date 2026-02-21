//
//  AITextAnalysisService.swift
//  MeetingIntelligence
//
//  Enterprise-grade AI Text Analysis Service
//  Provides professional linguistic analysis for HR documentation
//

import Foundation
import NaturalLanguage
import Combine

// MARK: - Text Analysis Models

/// Represents the result of a comprehensive tone analysis
struct ToneAnalysisResult: Equatable {
    let overallTone: ToneType
    let professionalismScore: Double
    let clarityScore: Double
    let objectivityScore: Double
    let readabilityScore: Double
    let sentimentScore: Double
    let suggestions: [ToneSuggestion]
    let metrics: TextMetrics
    
    enum ToneType: String, CaseIterable {
        case professional = "Professional"
        case formal = "Formal"
        case neutral = "Neutral"
        case informal = "Informal"
        case aggressive = "Aggressive"
        case empathetic = "Empathetic"
        case authoritative = "Authoritative"
        
        var color: String {
            switch self {
            case .professional: return "green"
            case .formal: return "blue"
            case .neutral: return "gray"
            case .informal: return "orange"
            case .aggressive: return "red"
            case .empathetic: return "purple"
            case .authoritative: return "teal"
            }
        }
        
        var icon: String {
            switch self {
            case .professional: return "briefcase.fill"
            case .formal: return "building.2.fill"
            case .neutral: return "equal.circle.fill"
            case .informal: return "face.smiling.fill"
            case .aggressive: return "exclamationmark.triangle.fill"
            case .empathetic: return "heart.fill"
            case .authoritative: return "shield.fill"
            }
        }
        
        var description: String {
            switch self {
            case .professional:
                return "Content maintains a balanced, professional tone appropriate for HR documentation."
            case .formal:
                return "Content uses formal language structures. Appropriate for official records."
            case .neutral:
                return "Content is factual and objective. Ideal for documentation purposes."
            case .informal:
                return "Content contains casual language. Consider revising for professional context."
            case .aggressive:
                return "Content may be perceived as confrontational. Consider softening language."
            case .empathetic:
                return "Content demonstrates understanding. Ensure professional boundaries are maintained."
            case .authoritative:
                return "Content conveys authority and confidence. Appropriate for policy enforcement."
            }
        }
    }
    
    struct ToneSuggestion: Identifiable, Equatable {
        let id: UUID
        let original: String
        let suggested: String
        let reason: String
        let category: SuggestionCategory
        let confidence: Double
        
        init(original: String, suggested: String, reason: String, category: SuggestionCategory, confidence: Double = 0.85) {
            self.id = UUID()
            self.original = original
            self.suggested = suggested
            self.reason = reason
            self.category = category
            self.confidence = confidence
        }
        
        enum SuggestionCategory: String {
            case tone = "Tone"
            case clarity = "Clarity"
            case professionalism = "Professionalism"
            case objectivity = "Objectivity"
        }
    }
    
    struct TextMetrics: Equatable {
        let wordCount: Int
        let sentenceCount: Int
        let averageWordsPerSentence: Double
        let averageSyllablesPerWord: Double
        let complexWordPercentage: Double
        let passiveVoicePercentage: Double
        let fleschKincaidGrade: Double
        let fleschReadingEase: Double
    }
}

/// Represents AI-powered content improvement suggestions
struct AIContentSuggestion: Identifiable, Equatable {
    let id: UUID
    let type: SuggestionType
    let title: String
    let description: String
    let originalText: String?
    let suggestedText: String?
    let confidence: Double
    let impact: ImpactLevel
    
    init(type: SuggestionType, title: String, description: String, originalText: String? = nil, suggestedText: String? = nil, confidence: Double = 0.8, impact: ImpactLevel = .medium) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.description = description
        self.originalText = originalText
        self.suggestedText = suggestedText
        self.confidence = confidence
        self.impact = impact
    }
    
    enum SuggestionType: String, CaseIterable {
        case clarity = "Clarity"
        case specificity = "Specificity"
        case policyReference = "Policy Reference"
        case grammar = "Grammar"
        case structure = "Structure"
        case tone = "Tone"
        case compliance = "Compliance"
        case actionability = "Actionability"
        
        var icon: String {
            switch self {
            case .clarity: return "eye.fill"
            case .specificity: return "target"
            case .policyReference: return "doc.text.fill"
            case .grammar: return "textformat.abc"
            case .structure: return "list.bullet.rectangle.fill"
            case .tone: return "waveform"
            case .compliance: return "checkmark.shield.fill"
            case .actionability: return "arrow.right.circle.fill"
            }
        }
        
        var color: String {
            switch self {
            case .clarity: return "blue"
            case .specificity: return "orange"
            case .policyReference: return "purple"
            case .grammar: return "green"
            case .structure: return "teal"
            case .tone: return "pink"
            case .compliance: return "indigo"
            case .actionability: return "cyan"
            }
        }
    }
    
    enum ImpactLevel: String {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case critical = "Critical"
        
        var sortOrder: Int {
            switch self {
            case .critical: return 0
            case .high: return 1
            case .medium: return 2
            case .low: return 3
            }
        }
    }
}

// MARK: - AI Text Analysis Service

/// Enterprise-grade service for analyzing and improving HR documentation text
@MainActor
final class AITextAnalysisService: ObservableObject {
    
    static let shared = AITextAnalysisService()
    
    // MARK: - Published Properties
    
    @Published private(set) var isAnalyzing = false
    @Published private(set) var analysisProgress: Double = 0
    @Published private(set) var currentAnalysisStep: String = ""
    
    // MARK: - Private Properties
    
    private let nlTagger: NLTagger
    private let sentimentPredictor: NLModel?
    
    // Linguistic pattern dictionaries for professional analysis
    private let aggressivePatterns: [String: Double] = [
        "must immediately": 0.8,
        "failure to comply": 0.7,
        "unacceptable": 0.75,
        "intolerable": 0.85,
        "will not be tolerated": 0.8,
        "demand": 0.6,
        "warned": 0.5,
        "final warning": 0.7,
        "termination will": 0.75,
        "zero tolerance": 0.7
    ]
    
    private let informalPatterns: [String: Double] = [
        "gonna": 0.95,
        "wanna": 0.95,
        "kinda": 0.9,
        "sorta": 0.9,
        "stuff": 0.6,
        "things": 0.4,
        "like,": 0.5,
        "you know": 0.7,
        "basically": 0.5,
        "pretty much": 0.6,
        "a lot": 0.4
    ]
    
    private let formalPatterns: [String: Double] = [
        "pursuant to": 0.8,
        "hereby": 0.7,
        "therefore": 0.5,
        "accordingly": 0.6,
        "wherein": 0.7,
        "heretofore": 0.8,
        "notwithstanding": 0.75,
        "in accordance with": 0.6,
        "as per": 0.5
    ]
    
    private let empatheticPatterns: [String: Double] = [
        "understand": 0.5,
        "support": 0.5,
        "help you": 0.6,
        "opportunity": 0.5,
        "growth": 0.5,
        "improve together": 0.7,
        "we value": 0.6,
        "appreciate": 0.5,
        "recognize": 0.4
    ]
    
    private let passiveVoiceIndicators: [String] = [
        "was done", "were made", "has been", "have been", "had been",
        "is being", "are being", "was being", "were being",
        "will be", "would be", "could be", "should be",
        "is considered", "was considered", "are expected", "was expected"
    ]
    
    private let vagueTerms: [String: String] = [
        "some": "specific quantity or examples",
        "several": "exact number",
        "many": "specific count",
        "things": "specific items or actions",
        "stuff": "specific materials or issues",
        "etc": "complete list of items",
        "and so on": "exhaustive enumeration",
        "various": "specific examples",
        "certain": "named individuals or items",
        "somewhat": "precise measurement"
    ]
    
    private let toneReplacements: [(pattern: String, replacement: String, reason: String)] = [
        ("must immediately", "is required to", "Maintains authority while reducing perceived aggression"),
        ("failure to", "not meeting the requirement to", "Focuses on action rather than blame"),
        ("unacceptable behavior", "behavior that does not meet company standards", "More objective phrasing"),
        ("you failed", "the expectation was not met", "Removes personal accusation"),
        ("will be terminated", "may result in termination of employment", "Acknowledges due process"),
        ("warned you", "previously documented", "Factual rather than threatening"),
        ("bad attitude", "behavior inconsistent with workplace expectations", "Objective description"),
        ("refused to", "did not complete", "Removes assumption of intent"),
        ("always late", "has been late on [X] occasions", "Specific and documentable"),
        ("never follows", "has not followed on documented occasions", "Factual and specific")
    ]
    
    // MARK: - Initialization
    
    private init() {
        self.nlTagger = NLTagger(tagSchemes: [.lexicalClass, .lemma, .sentimentScore])
        
        // Attempt to load sentiment model if available
        if let modelURL = Bundle.main.url(forResource: "SentimentClassifier", withExtension: "mlmodelc"),
           let model = try? NLModel(contentsOf: modelURL) {
            self.sentimentPredictor = model
        } else {
            self.sentimentPredictor = nil
        }
    }
    
    // MARK: - Public Analysis Methods
    
    /// Performs comprehensive tone analysis on the provided text
    func analyzeTone(text: String, context: DocumentContext) async -> ToneAnalysisResult {
        isAnalyzing = true
        analysisProgress = 0
        
        defer {
            isAnalyzing = false
            analysisProgress = 1.0
            currentAnalysisStep = ""
        }
        
        // Step 1: Calculate text metrics
        currentAnalysisStep = "Calculating text metrics..."
        analysisProgress = 0.1
        let metrics = await calculateTextMetrics(text)
        
        // Step 2: Analyze linguistic patterns
        currentAnalysisStep = "Analyzing linguistic patterns..."
        analysisProgress = 0.3
        let patternScores = await analyzePatterns(text)
        
        // Step 3: Determine sentiment
        currentAnalysisStep = "Evaluating sentiment..."
        analysisProgress = 0.5
        let sentimentScore = await analyzeSentiment(text)
        
        // Step 4: Calculate quality scores
        currentAnalysisStep = "Computing quality scores..."
        analysisProgress = 0.7
        let qualityScores = calculateQualityScores(text: text, metrics: metrics, patternScores: patternScores)
        
        // Step 5: Generate suggestions
        currentAnalysisStep = "Generating improvement suggestions..."
        analysisProgress = 0.9
        let suggestions = await generateToneSuggestions(text: text, patternScores: patternScores, context: context)
        
        // Determine overall tone
        let overallTone = determineTone(patternScores: patternScores, sentimentScore: sentimentScore)
        
        return ToneAnalysisResult(
            overallTone: overallTone,
            professionalismScore: qualityScores.professionalism,
            clarityScore: qualityScores.clarity,
            objectivityScore: qualityScores.objectivity,
            readabilityScore: qualityScores.readability,
            sentimentScore: sentimentScore,
            suggestions: suggestions,
            metrics: metrics
        )
    }
    
    /// Generates AI-powered content improvement suggestions
    func generateContentSuggestions(text: String, sectionType: String, context: DocumentContext) async -> [AIContentSuggestion] {
        isAnalyzing = true
        analysisProgress = 0
        
        defer {
            isAnalyzing = false
            analysisProgress = 1.0
            currentAnalysisStep = ""
        }
        
        var suggestions: [AIContentSuggestion] = []
        
        // Step 1: Analyze structure
        currentAnalysisStep = "Analyzing document structure..."
        analysisProgress = 0.2
        suggestions.append(contentsOf: await analyzeStructure(text: text, sectionType: sectionType))
        
        // Step 2: Check specificity
        currentAnalysisStep = "Checking content specificity..."
        analysisProgress = 0.4
        suggestions.append(contentsOf: analyzeSpecificity(text: text, sectionType: sectionType))
        
        // Step 3: Evaluate compliance language
        currentAnalysisStep = "Evaluating compliance requirements..."
        analysisProgress = 0.6
        suggestions.append(contentsOf: analyzeCompliance(text: text, context: context))
        
        // Step 4: Check actionability
        currentAnalysisStep = "Assessing actionability..."
        analysisProgress = 0.8
        suggestions.append(contentsOf: analyzeActionability(text: text, sectionType: sectionType))
        
        // Sort by impact and confidence
        suggestions.sort { ($0.impact.sortOrder, -$0.confidence) < ($1.impact.sortOrder, -$1.confidence) }
        
        return suggestions
    }
    
    // MARK: - Private Analysis Methods
    
    private func calculateTextMetrics(_ text: String) async -> ToneAnalysisResult.TextMetrics {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        let wordCount = words.count
        let sentenceCount = max(1, sentences.count)
        let avgWordsPerSentence = Double(wordCount) / Double(sentenceCount)
        
        // Calculate syllables per word (approximation)
        var totalSyllables = 0
        var complexWords = 0
        
        for word in words {
            let syllables = countSyllables(word)
            totalSyllables += syllables
            if syllables >= 3 {
                complexWords += 1
            }
        }
        
        let avgSyllablesPerWord = wordCount > 0 ? Double(totalSyllables) / Double(wordCount) : 0
        let complexWordPct = wordCount > 0 ? (Double(complexWords) / Double(wordCount)) * 100 : 0
        
        // Calculate passive voice percentage
        let lowercaseText = text.lowercased()
        var passiveCount = 0
        for indicator in passiveVoiceIndicators {
            passiveCount += lowercaseText.components(separatedBy: indicator).count - 1
        }
        let passiveVoicePct = sentenceCount > 0 ? (Double(passiveCount) / Double(sentenceCount)) * 100 : 0
        
        // Flesch-Kincaid calculations
        let fleschKincaidGrade = 0.39 * avgWordsPerSentence + 11.8 * avgSyllablesPerWord - 15.59
        let fleschReadingEase = 206.835 - 1.015 * avgWordsPerSentence - 84.6 * avgSyllablesPerWord
        
        return ToneAnalysisResult.TextMetrics(
            wordCount: wordCount,
            sentenceCount: sentenceCount,
            averageWordsPerSentence: avgWordsPerSentence,
            averageSyllablesPerWord: avgSyllablesPerWord,
            complexWordPercentage: complexWordPct,
            passiveVoicePercentage: min(100, passiveVoicePct),
            fleschKincaidGrade: max(0, fleschKincaidGrade),
            fleschReadingEase: max(0, min(100, fleschReadingEase))
        )
    }
    
    private func countSyllables(_ word: String) -> Int {
        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
        let word = word.lowercased()
        var count = 0
        var lastWasVowel = false
        
        for char in word {
            let isVowel = vowels.contains(char)
            if isVowel && !lastWasVowel {
                count += 1
            }
            lastWasVowel = isVowel
        }
        
        // Handle silent e
        if word.hasSuffix("e") && count > 1 {
            count -= 1
        }
        
        // Handle le endings
        if word.hasSuffix("le") && word.count > 2 {
            let beforeLe = word[word.index(word.endIndex, offsetBy: -3)]
            if !vowels.contains(beforeLe) {
                count += 1
            }
        }
        
        return max(1, count)
    }
    
    private func analyzePatterns(_ text: String) async -> PatternScores {
        let lowercaseText = text.lowercased()
        
        var aggressiveScore: Double = 0
        var informalScore: Double = 0
        var formalScore: Double = 0
        var empatheticScore: Double = 0
        
        // Calculate weighted pattern scores
        for (pattern, weight) in aggressivePatterns {
            if lowercaseText.contains(pattern) {
                aggressiveScore += weight
            }
        }
        
        for (pattern, weight) in informalPatterns {
            if lowercaseText.contains(pattern) {
                informalScore += weight
            }
        }
        
        for (pattern, weight) in formalPatterns {
            if lowercaseText.contains(pattern) {
                formalScore += weight
            }
        }
        
        for (pattern, weight) in empatheticPatterns {
            if lowercaseText.contains(pattern) {
                empatheticScore += weight
            }
        }
        
        // Normalize scores to 0-1 range
        let maxPossible = 5.0 // Maximum reasonable accumulated score
        return PatternScores(
            aggressive: min(1.0, aggressiveScore / maxPossible),
            informal: min(1.0, informalScore / maxPossible),
            formal: min(1.0, formalScore / maxPossible),
            empathetic: min(1.0, empatheticScore / maxPossible)
        )
    }
    
    private struct PatternScores {
        let aggressive: Double
        let informal: Double
        let formal: Double
        let empathetic: Double
    }
    
    private func analyzeSentiment(_ text: String) async -> Double {
        // Use NLTagger for sentiment analysis
        nlTagger.string = text
        
        var totalSentiment: Double = 0
        var count = 0
        
        nlTagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .sentence, scheme: .sentimentScore) { tag, _ in
            if let tag = tag, let score = Double(tag.rawValue) {
                totalSentiment += score
                count += 1
            }
            return true
        }
        
        // Return normalized sentiment (-1 to 1 range, converted to 0-100)
        let avgSentiment = count > 0 ? totalSentiment / Double(count) : 0
        return (avgSentiment + 1) * 50 // Convert to 0-100 scale
    }
    
    private func calculateQualityScores(text: String, metrics: ToneAnalysisResult.TextMetrics, patternScores: PatternScores) -> QualityScores {
        // Professionalism: Penalize informal language, reward formal structure
        var professionalism = 100.0
        professionalism -= patternScores.informal * 40
        professionalism -= patternScores.aggressive * 20
        professionalism += patternScores.formal * 10
        professionalism = max(0, min(100, professionalism))
        
        // Clarity: Based on readability metrics
        var clarity = metrics.fleschReadingEase
        // Optimal sentence length is 15-20 words
        if metrics.averageWordsPerSentence > 25 {
            clarity -= (metrics.averageWordsPerSentence - 25) * 2
        }
        // Penalize high passive voice usage
        clarity -= metrics.passiveVoicePercentage * 0.5
        clarity = max(0, min(100, clarity))
        
        // Objectivity: Penalize emotional/aggressive language
        var objectivity = 100.0
        objectivity -= patternScores.aggressive * 35
        objectivity -= patternScores.empathetic * 10 // Some empathy is okay
        objectivity = max(0, min(100, objectivity))
        
        // Readability: Flesch Reading Ease adjusted for business context
        // Business documents should be 40-60 (plain English)
        var readability = metrics.fleschReadingEase
        // Bonus for being in optimal range
        if readability >= 40 && readability <= 70 {
            readability = min(100, readability + 15)
        }
        readability = max(0, min(100, readability))
        
        return QualityScores(
            professionalism: professionalism,
            clarity: clarity,
            objectivity: objectivity,
            readability: readability
        )
    }
    
    private struct QualityScores {
        let professionalism: Double
        let clarity: Double
        let objectivity: Double
        let readability: Double
    }
    
    private func determineTone(patternScores: PatternScores, sentimentScore: Double) -> ToneAnalysisResult.ToneType {
        // Priority-based tone detection
        if patternScores.aggressive > 0.5 {
            return .aggressive
        }
        
        if patternScores.informal > 0.4 {
            return .informal
        }
        
        if patternScores.formal > 0.5 {
            return .formal
        }
        
        if patternScores.empathetic > 0.4 {
            return .empathetic
        }
        
        // Balanced tone detection
        let professionalScore = (1 - patternScores.informal) * (1 - patternScores.aggressive * 0.5)
        
        if professionalScore > 0.7 && patternScores.formal > 0.2 {
            return .authoritative
        }
        
        if professionalScore > 0.6 {
            return .professional
        }
        
        return .neutral
    }
    
    private func generateToneSuggestions(text: String, patternScores: PatternScores, context: DocumentContext) async -> [ToneAnalysisResult.ToneSuggestion] {
        var suggestions: [ToneAnalysisResult.ToneSuggestion] = []
        let lowercaseText = text.lowercased()
        
        // Check for tone replacements
        for replacement in toneReplacements {
            if lowercaseText.contains(replacement.pattern) {
                suggestions.append(ToneAnalysisResult.ToneSuggestion(
                    original: replacement.pattern,
                    suggested: replacement.replacement,
                    reason: replacement.reason,
                    category: .tone,
                    confidence: 0.85
                ))
            }
        }
        
        // Limit to most impactful suggestions
        return Array(suggestions.prefix(5))
    }
    
    private func analyzeStructure(text: String, sectionType: String) async -> [AIContentSuggestion] {
        var suggestions: [AIContentSuggestion] = []
        
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        // Check for very long sentences
        for sentence in sentences {
            let wordCount = sentence.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
            if wordCount > 35 {
                suggestions.append(AIContentSuggestion(
                    type: .structure,
                    title: "Long Sentence Detected",
                    description: "A sentence with \(wordCount) words may be difficult to read. Consider breaking it into shorter, clearer statements.",
                    confidence: 0.9,
                    impact: .medium
                ))
                break // Only report once
            }
        }
        
        // Check for bullet points in description sections
        if sectionType.lowercased().contains("description") || sectionType.lowercased().contains("detail") {
            if !text.contains("•") && !text.contains("-") && !text.contains("1.") && sentences.count > 3 {
                suggestions.append(AIContentSuggestion(
                    type: .structure,
                    title: "Consider Using Bullet Points",
                    description: "Multiple points in narrative form can be easier to read as a bulleted list for clarity and quick reference.",
                    confidence: 0.75,
                    impact: .low
                ))
            }
        }
        
        return suggestions
    }
    
    private func analyzeSpecificity(text: String, sectionType: String) -> [AIContentSuggestion] {
        var suggestions: [AIContentSuggestion] = []
        let lowercaseText = text.lowercased()
        
        // Check for vague terms
        for (term, replacement) in vagueTerms {
            if lowercaseText.contains(term) {
                suggestions.append(AIContentSuggestion(
                    type: .specificity,
                    title: "Vague Term: \"\(term)\"",
                    description: "Replace '\(term)' with \(replacement) for clearer documentation.",
                    originalText: term,
                    suggestedText: nil,
                    confidence: 0.8,
                    impact: .medium
                ))
            }
        }
        
        // Section-specific checks
        if sectionType.lowercased().contains("description") {
            // Check for missing temporal references
            let hasDate = text.contains(where: { $0.isNumber }) || 
                          lowercaseText.contains("january") || lowercaseText.contains("february") ||
                          lowercaseText.contains("monday") || lowercaseText.contains("today")
            
            if !hasDate && text.count > 50 {
                suggestions.append(AIContentSuggestion(
                    type: .specificity,
                    title: "Add Specific Date/Time",
                    description: "Include specific dates and times (e.g., 'On January 15, 2026, at 2:30 PM') to strengthen documentation.",
                    confidence: 0.85,
                    impact: .high
                ))
            }
        }
        
        if sectionType.lowercased().contains("corrective") || sectionType.lowercased().contains("action") {
            let hasTimeframe = lowercaseText.contains("day") || lowercaseText.contains("week") || 
                              lowercaseText.contains("month") || lowercaseText.contains("immediately")
            
            if !hasTimeframe {
                suggestions.append(AIContentSuggestion(
                    type: .actionability,
                    title: "Add Specific Timeframe",
                    description: "Include clear deadlines (e.g., 'within 30 days', 'by March 1, 2026') for corrective actions.",
                    confidence: 0.9,
                    impact: .high
                ))
            }
        }
        
        return suggestions
    }
    
    private func analyzeCompliance(text: String, context: DocumentContext) -> [AIContentSuggestion] {
        var suggestions: [AIContentSuggestion] = []
        let lowercaseText = text.lowercased()
        
        // Check for policy references
        let hasPolicyRef = lowercaseText.contains("policy") || lowercaseText.contains("section") ||
                          lowercaseText.contains("handbook") || lowercaseText.contains("code of conduct")
        
        if !hasPolicyRef && text.count > 100 {
            suggestions.append(AIContentSuggestion(
                type: .policyReference,
                title: "Add Policy Reference",
                description: "Reference the specific company policy or handbook section that applies to this situation (e.g., 'Employee Handbook Section 4.2').",
                confidence: 0.85,
                impact: .high
            ))
        }
        
        // Check for proper documentation language
        if context.documentType == .warning {
            let hasAcknowledgment = lowercaseText.contains("acknowledge") || lowercaseText.contains("understand") ||
                                   lowercaseText.contains("received") || lowercaseText.contains("copy")
            
            if !hasAcknowledgment {
                suggestions.append(AIContentSuggestion(
                    type: .compliance,
                    title: "Include Acknowledgment Statement",
                    description: "Warning documents should include language for employee acknowledgment of receipt.",
                    confidence: 0.8,
                    impact: .medium
                ))
            }
        }
        
        return suggestions
    }
    
    private func analyzeActionability(text: String, sectionType: String) -> [AIContentSuggestion] {
        var suggestions: [AIContentSuggestion] = []
        
        if sectionType.lowercased().contains("corrective") || sectionType.lowercased().contains("action") {
            let lowercaseText = text.lowercased()
            
            // Check for measurable outcomes
            let hasMeasurable = lowercaseText.contains("complete") || lowercaseText.contains("attend") ||
                               lowercaseText.contains("submit") || lowercaseText.contains("demonstrate") ||
                               lowercaseText.contains("achieve") || lowercaseText.contains("meet")
            
            if !hasMeasurable {
                suggestions.append(AIContentSuggestion(
                    type: .actionability,
                    title: "Define Measurable Outcomes",
                    description: "Specify concrete, measurable actions the employee must take (e.g., 'complete training', 'achieve 95% attendance').",
                    confidence: 0.85,
                    impact: .high
                ))
            }
            
            // Check for follow-up mechanism
            let hasFollowUp = lowercaseText.contains("review") || lowercaseText.contains("follow-up") ||
                             lowercaseText.contains("check-in") || lowercaseText.contains("progress")
            
            if !hasFollowUp {
                suggestions.append(AIContentSuggestion(
                    type: .actionability,
                    title: "Add Follow-up Plan",
                    description: "Include a follow-up review date or progress check to monitor improvement.",
                    confidence: 0.8,
                    impact: .medium
                ))
            }
        }
        
        return suggestions
    }
}

// MARK: - Document Context

struct DocumentContext {
    let documentType: DocumentType
    let sectionType: String
    let companyName: String?
    let employeeName: String?
    
    enum DocumentType {
        case warning
        case coaching
        case counseling
        case escalation
        case general
    }
    
    static let `default` = DocumentContext(
        documentType: .warning,
        sectionType: "General",
        companyName: nil,
        employeeName: nil
    )
}
