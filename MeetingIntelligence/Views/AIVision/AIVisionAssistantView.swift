//
//  AIVisionAssistantView.swift
//  MeetingIntelligence
//
//  Industrial Vision Assistant – Professional UI with clean state management
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Analysis Topic
enum AnalysisTopic: String, CaseIterable, Identifiable {
    case safety = "Workplace Safety"
    case foodSafety = "Food Safety & Hygiene"
    case qualityControl = "Quality Control"
    case warehouse = "Warehouse & Logistics"
    case maintenance = "Maintenance & Equipment"
    case operations = "Operations & Efficiency"
    case manufacturing = "Manufacturing Process"
    case humanResources = "Human Resources"
    case ergonomics = "Ergonomics & Wellness"
    case environmental = "Environmental Compliance"
    case electrical = "Electrical Safety"
    case fire = "Fire Safety"
    case chemical = "Chemical Handling"
    case ppe = "PPE Compliance"
    case sanitation = "Sanitation & Cleanliness"
    case pest = "Pest Control"
    case storage = "Storage & Organization"
    case shipping = "Shipping & Receiving"
    case marketing = "Marketing & Branding"
    case finance = "Finance & Assets"
    case nursing = "Nursing & Healthcare"
    case pharmacy = "Pharmacy & Medication"
    case construction = "Construction Safety"
    case automotive = "Automotive & Fleet"
    case retail = "Retail Operations"
    case hospitality = "Hospitality & Service"
    case agriculture = "Agriculture & Farming"
    case general = "General Assessment"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .safety: return "exclamationmark.shield.fill"
        case .foodSafety: return "fork.knife"
        case .qualityControl: return "checkmark.seal.fill"
        case .warehouse: return "shippingbox.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .operations: return "gearshape.2.fill"
        case .manufacturing: return "hammer.fill"
        case .humanResources: return "person.3.fill"
        case .ergonomics: return "figure.stand"
        case .environmental: return "leaf.fill"
        case .electrical: return "bolt.fill"
        case .fire: return "flame.fill"
        case .chemical: return "testtube.2"
        case .ppe: return "shield.checkered"
        case .sanitation: return "sparkles"
        case .pest: return "ant.fill"
        case .storage: return "archivebox.fill"
        case .shipping: return "truck.box.fill"
        case .marketing: return "megaphone.fill"
        case .finance: return "dollarsign.circle.fill"
        case .nursing: return "cross.case.fill"
        case .pharmacy: return "pills.fill"
        case .construction: return "cone.fill"
        case .automotive: return "car.fill"
        case .retail: return "cart.fill"
        case .hospitality: return "bed.double.fill"
        case .agriculture: return "leaf.arrow.triangle.circlepath"
        case .general: return "eye.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .safety, .fire, .electrical: return .red
        case .foodSafety, .sanitation, .pest: return .orange
        case .qualityControl, .ppe: return .blue
        case .warehouse, .storage, .shipping: return .brown
        case .maintenance, .manufacturing: return .gray
        case .operations, .retail: return .purple
        case .humanResources, .ergonomics: return .pink
        case .environmental, .agriculture: return .green
        case .chemical: return .yellow
        case .marketing: return .cyan
        case .finance: return .mint
        case .nursing, .pharmacy: return .teal
        case .construction: return .orange
        case .automotive: return .indigo
        case .hospitality: return .purple
        case .general: return Color(hex: "8B5CF6")
        }
    }
}

// MARK: - AI Vision Assistant View
struct AIVisionAssistantView: View {
    @StateObject private var viewModel = AIVisionViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showTopicSelector = false
    @State private var showVisionSessions = false
    
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreviewView(session: viewModel.captureSession)
                .ignoresSafeArea()
            
            // Dark overlay when not idle
            if viewModel.state != .idle || showTopicSelector {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.2), value: viewModel.state)
            }
            
            // Main UI
            VStack(spacing: 0) {
                // Top Bar
                topBar
                    .padding(.top, 60)
                
                Spacer()
                
                // Feature Cards (only during analyzing)
                if viewModel.state == .analyzing || viewModel.state == .transcribing {
                    AIVisionFeatureCards()
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                Spacer()
                
                // Response Panel (hidden during analyzing)
                if !viewModel.responseText.isEmpty && viewModel.state != .analyzing && viewModel.state != .transcribing {
                    responsePanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Status Indicator
                if viewModel.state != .idle {
                    statusIndicator
                        .padding(.bottom, 20)
                        .transition(.opacity)
                }
                
                // End Session Button (only show when there's an active session)
                if viewModel.hasActiveSession && viewModel.state == .idle {
                    endSessionButton
                        .padding(.bottom, 16)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                // Bottom Controls
                bottomControls
                    .padding(.bottom, 40)
            }
            
            // Topic Selector Overlay
            if showTopicSelector {
                topicSelectorOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.state)
        .animation(.easeInOut(duration: 0.25), value: showTopicSelector)
        .animation(.easeInOut(duration: 0.25), value: viewModel.hasActiveSession)
        .onAppear {
            viewModel.startCamera()
        }
        .onDisappear {
            viewModel.stopCamera()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage)
        }
        .sheet(isPresented: $viewModel.showEndSessionModal) {
            EndSessionModalView(viewModel: viewModel, showVisionSessions: $showVisionSessions)
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showVisionSessions) {
            VisionSessionsView()
        }
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            
            Spacer()
            
            // Topic selector (only when idle or recording)
            if viewModel.state == .idle || viewModel.state == .recording {
                Button {
                    showTopicSelector = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.selectedTopic.icon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(viewModel.selectedTopic.color)
                        
                        Text(viewModel.selectedTopic.rawValue)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.ultraThinMaterial))
                }
            }
            
            // Recording indicator
            if viewModel.state == .recording {
                recordingIndicator
            }
            
            Spacer()
            
            // Sessions history button
            Button {
                showVisionSessions = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            
            // Flash toggle
            Button {
                viewModel.toggleFlash()
            } label: {
                Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(viewModel.isFlashOn ? .yellow : .white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.ultraThinMaterial))
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Recording Indicator
    private var recordingIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
            
            Text(formatDuration(viewModel.recordingDuration))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.red.opacity(0.8)))
    }
    
    // MARK: - Status Indicator
    private var statusIndicator: some View {
        HStack(spacing: 12) {
            switch viewModel.state {
            case .idle:
                EmptyView()
                
            case .recording:
                Image(systemName: "waveform")
                    .font(.title3)
                    .foregroundColor(.white)
                    .symbolEffect(.variableColor.iterative)
                Text("Speak your question...")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                
            case .transcribing:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.9)
                Text("Processing speech...")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                
            case .analyzing:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.9)
                Text("Analyzing...")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                
            case .speaking:
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .symbolEffect(.variableColor.iterative)
                Text("Speaking...")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Capsule().fill(.ultraThinMaterial))
    }
    
    // MARK: - Response Panel
    private var responsePanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Topic badge
                HStack {
                    Image(systemName: viewModel.selectedTopic.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(viewModel.selectedTopic.color)
                    Text(viewModel.selectedTopic.rawValue)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(viewModel.selectedTopic.color.opacity(0.2)))
                
                // User question
                if !viewModel.transcribedQuestion.isEmpty {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppColors.primary)
                        
                        Text(viewModel.transcribedQuestion)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.bottom, 8)
                }
                
                // AI Response
                if !viewModel.responseText.isEmpty {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundStyle(AppGradients.primary)
                        
                        Text(viewModel.responseText)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(16)
        }
        .frame(maxHeight: 280)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Bottom Controls
    private var bottomControls: some View {
        HStack(spacing: 40) {
            // Topic selector button
            Button {
                showTopicSelector = true
            } label: {
                Image(systemName: viewModel.selectedTopic.icon)
                    .font(.title2)
                    .foregroundColor(viewModel.selectedTopic.color)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .opacity(viewModel.state == .idle ? 1 : 0.3)
            .disabled(viewModel.state != .idle)
            
            // Main action button
            mainActionButton
            
            // Switch camera button
            Button {
                viewModel.switchCamera()
            } label: {
                Image(systemName: "camera.rotate")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .opacity(viewModel.state == .idle ? 1 : 0.3)
            .disabled(viewModel.state != .idle)
        }
    }
    
    // MARK: - Main Action Button
    private var mainActionButton: some View {
        Button {
            viewModel.handleMainButtonTap()
        } label: {
            ZStack {
                // Button appearance based on state
                Circle()
                    .fill(buttonColor)
                    .frame(width: 80, height: 80)
                    .shadow(color: buttonColor.opacity(0.5), radius: 10, y: 4)
                
                buttonIcon
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .disabled(viewModel.state == .transcribing || viewModel.state == .analyzing)
        .opacity(viewModel.state == .transcribing || viewModel.state == .analyzing ? 0.5 : 1)
    }
    
    private var buttonColor: Color {
        switch viewModel.state {
        case .idle:
            return viewModel.selectedTopic.color
        case .recording:
            return .red
        case .speaking:
            return .orange
        default:
            return .gray
        }
    }
    
    private var buttonIcon: Image {
        switch viewModel.state {
        case .idle:
            return Image(systemName: "mic.fill")
        case .recording:
            return Image(systemName: "stop.fill")
        case .speaking:
            return Image(systemName: "stop.fill")
        default:
            return Image(systemName: "ellipsis")
        }
    }
    
    // MARK: - Topic Selector Overlay
    private var topicSelectorOverlay: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Analysis Focus")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    showTopicSelector = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            // Topics Grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(AnalysisTopic.allCases) { topic in
                        TopicButton(
                            topic: topic,
                            isSelected: viewModel.selectedTopic == topic
                        ) {
                            viewModel.selectedTopic = topic
                            showTopicSelector = false
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
        .padding(.top, 100)
    }
    
    // MARK: - Helper
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - End Session Button
    private var endSessionButton: some View {
        Button {
            viewModel.endSession()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                
                Text("End Session")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.red.opacity(0.8))
            )
        }
    }
}

// MARK: - Topic Button
struct TopicButton: View {
    let topic: AnalysisTopic
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: topic.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : topic.color)
                    .frame(width: 30)
                
                Text(topic.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? topic.color : topic.color.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.clear : topic.color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.session = session
    }
}

class CameraPreviewUIView: UIView {
    var session: AVCaptureSession? {
        didSet {
            guard let session = session else { return }
            previewLayer.session = session
        }
    }
    
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer()
        layer.videoGravity = .resizeAspectFill
        return layer
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(previewLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

// MARK: - AI Vision Feature Cards (Animated)
struct AIVisionFeatureCards: View {
    @State private var currentIndex = 0
    @State private var isAnimating = false
    
    private let features: [(icon: String, title: String, description: String, color: Color)] = [
        ("eye.fill", "Real-Time Analysis", "System examines your environment through the camera in real-time", .blue),
        ("brain.head.profile", "Expert Insights", "Get professional-level analysis tailored to your selected topic", .purple),
        ("waveform", "Voice Interaction", "Ask questions naturally using your voice", .green),
        ("speaker.wave.2.fill", "Audio Responses", "Hear detailed explanations spoken back to you", .orange),
        ("scope", "28 Industry Topics", "Specialized expertise from safety to healthcare", .red),
        ("arrow.triangle.2.circlepath", "Follow-Up Questions", "Continue the conversation for deeper insights", .teal),
    ]
    
    let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 16) {
            // Current feature card
            featureCard(for: features[currentIndex])
                .id(currentIndex)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            
            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<features.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentIndex ? 1.2 : 1.0)
                }
            }
        }
        .padding(.horizontal, 30)
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentIndex = (currentIndex + 1) % features.count
            }
        }
    }
    
    private func featureCard(for feature: (icon: String, title: String, description: String, color: Color)) -> some View {
        VStack(spacing: 16) {
            // Icon with animated glow
            ZStack {
                Circle()
                    .fill(feature.color.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Circle()
                    .fill(feature.color.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .opacity(isAnimating ? 0 : 0.5)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(feature.color)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
            
            // Title
            Text(feature.title)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
            
            // Description
            Text(feature.description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(feature.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview
#Preview {
    AIVisionAssistantView()
}

// MARK: - End Session Modal View
struct EndSessionModalView: View {
    @ObservedObject var viewModel: AIVisionViewModel
    @Binding var showVisionSessions: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("End Session?")
                    .font(.title2.weight(.bold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Text("You have \(viewModel.sessionManager.currentSession?.messageCount ?? 0) messages in this session")
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6))
            }
            .padding(.top, 8)
            
            // Action Buttons
            VStack(spacing: 12) {
                // Save Session Button
                Button {
                    viewModel.saveAndEndSession()
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.subheadline.weight(.semibold))
                        
                        Text("Save Conversation")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "8B5CF6"), Color(hex: "6366F1")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                
                // View Previous Sessions Button
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showVisionSessions = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.subheadline.weight(.semibold))
                        
                        Text("View Previous Sessions")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.08))
                    )
                }
                
                // Discard Button
                Button {
                    viewModel.discardSession()
                    dismiss()
                } label: {
                    Text("Discard & Exit")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 16)
        .background(colorScheme == .dark ? AppColors.background : Color(.systemBackground))
    }
}
