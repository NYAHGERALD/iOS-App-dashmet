import SwiftUI
import UIKit

// MARK: - Signature Drawing Canvas (UIKit-backed)

class SignatureDrawingView: UIView, UIGestureRecognizerDelegate {
    private var strokes: [[CGPoint]] = []
    private var currentStroke: [CGPoint] = []
    
    var onChanged: ((UIImage?, Bool) -> Void)?
    var onDrawingStateChanged: ((Bool) -> Void)?
    
    private weak var ancestorScrollView: UIScrollView?
    
    private lazy var panGesture: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        pan.maximumNumberOfTouches = 1
        pan.minimumNumberOfTouches = 1
        return pan
    }()
    
    // Tap gesture to draw dots
    private lazy var tapGesture: UILongPressGestureRecognizer = {
        let tap = UILongPressGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.minimumPressDuration = 0.001
        tap.delegate = self
        return tap
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        isOpaque = true
        isMultipleTouchEnabled = false
        contentMode = .redraw
        addGestureRecognizer(panGesture)
        addGestureRecognizer(tapGesture)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Cache the ancestor scroll view
        ancestorScrollView = findAncestorScrollView()
    }
    
    private func findAncestorScrollView() -> UIScrollView? {
        var view: UIView? = superview
        while let v = view {
            if let scrollView = v as? UIScrollView {
                return scrollView
            }
            view = v.superview
        }
        return nil
    }
    
    // MARK: - Gesture Handlers
    
    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let point = recognizer.location(in: self)
        
        switch recognizer.state {
        case .began:
            // Disable ancestor scroll view to prevent interference
            ancestorScrollView?.isScrollEnabled = false
            currentStroke = [point]
            onDrawingStateChanged?(true)
        case .changed:
            currentStroke.append(point)
        case .ended:
            if !currentStroke.isEmpty {
                strokes.append(currentStroke)
                currentStroke = []
            }
            ancestorScrollView?.isScrollEnabled = true
            onDrawingStateChanged?(false)
            onChanged?(renderImage(), strokes.isEmpty)
        case .cancelled, .failed:
            if !currentStroke.isEmpty {
                strokes.append(currentStroke)
                currentStroke = []
            }
            ancestorScrollView?.isScrollEnabled = true
            onDrawingStateChanged?(false)
            onChanged?(renderImage(), strokes.isEmpty)
        default:
            break
        }
        setNeedsDisplay()
    }
    
    @objc private func handleTap(_ recognizer: UILongPressGestureRecognizer) {
        // Only handle the initial touch for dot drawing
        guard recognizer.state == .began else { return }
        let point = recognizer.location(in: self)
        // Add small dot as a single-point stroke
        strokes.append([point, CGPoint(x: point.x + 0.5, y: point.y + 0.5)])
        setNeedsDisplay()
        onChanged?(renderImage(), false)
    }
    
    // MARK: - Gesture Recognizer Delegate
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow our own gestures to work simultaneously
        if gestureRecognizer == panGesture && otherGestureRecognizer == tapGesture { return true }
        if gestureRecognizer == tapGesture && otherGestureRecognizer == panGesture { return true }
        // Block simultaneous recognition with scroll view gestures
        return false
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Only allow our own gesture recognizers to begin
        if gestureRecognizer == panGesture || gestureRecognizer == tapGesture {
            return true
        }
        // Prevent scroll view gesture recognizers from starting on this view
        return false
    }
    
    // MARK: - Drawing
    
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        
        // Clear with white background
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill(rect)
        
        // Configure stroke style
        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(2.5)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        
        // Draw completed strokes
        for stroke in strokes {
            guard !stroke.isEmpty else { continue }
            ctx.beginPath()
            ctx.move(to: stroke[0])
            for i in 1..<stroke.count {
                ctx.addLine(to: stroke[i])
            }
            ctx.strokePath()
        }
        
        // Draw current in-progress stroke
        if !currentStroke.isEmpty {
            ctx.beginPath()
            ctx.move(to: currentStroke[0])
            for i in 1..<currentStroke.count {
                ctx.addLine(to: currentStroke[i])
            }
            ctx.strokePath()
        }
    }
    
    func clear() {
        strokes.removeAll()
        currentStroke.removeAll()
        setNeedsDisplay()
        onChanged?(nil, true)
    }
    
    private func renderImage() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { ctx in
            layer.render(in: ctx.cgContext)
        }
    }
}

// MARK: - UIViewRepresentable Wrapper

struct SignatureCanvas: UIViewRepresentable {
    @Binding var image: UIImage?
    @Binding var isEmpty: Bool
    @Binding var isDrawing: Bool
    var clearSignal: UUID
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> SignatureDrawingView {
        let view = SignatureDrawingView()
        context.coordinator.lastClearSignal = clearSignal
        
        view.onChanged = { img, empty in
            DispatchQueue.main.async {
                image = img
                isEmpty = empty
            }
        }
        view.onDrawingStateChanged = { drawing in
            DispatchQueue.main.async {
                isDrawing = drawing
            }
        }
        return view
    }
    
    func updateUIView(_ uiView: SignatureDrawingView, context: Context) {
        // Detect clear signal change
        if clearSignal != context.coordinator.lastClearSignal {
            context.coordinator.lastClearSignal = clearSignal
            uiView.clear()
        }
    }
    
    static func dismantleUIView(_ uiView: SignatureDrawingView, coordinator: Coordinator) {
        uiView.onChanged = nil
        uiView.onDrawingStateChanged = nil
    }
    
    class Coordinator {
        var lastClearSignal: UUID = UUID()
    }
}

// MARK: - Signature Capture View

struct SignatureCaptureView: View {
    let title: String
    let signerName: String
    @Binding var signatureImage: UIImage?
    @Binding var isEmpty: Bool
    @Binding var isDrawing: Bool
    var onClear: () -> Void
    
    @State private var clearSignal = UUID()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(signerName)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                
                Button {
                    clearSignal = UUID()
                    onClear()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12))
                        Text("Clear")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(AppColors.error)
                }
                .disabled(isEmpty)
                .opacity(isEmpty ? 0.4 : 1)
            }
            
            // Signature canvas
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isEmpty ? AppColors.border : Color(hex: "10B981"), lineWidth: isEmpty ? 1 : 2)
                    )
                
                SignatureCanvas(
                    image: $signatureImage,
                    isEmpty: $isEmpty,
                    isDrawing: $isDrawing,
                    clearSignal: clearSignal
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                if isEmpty {
                    Text("Sign here")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textTertiary)
                        .allowsHitTesting(false)
                }
                
                // Signature line
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(AppColors.textTertiary.opacity(0.3))
                        .frame(height: 1)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 30)
                }
                .allowsHitTesting(false)
            }
            .frame(height: 200)
        }
    }
}
