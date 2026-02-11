//
//  SignatureCanvasView.swift
//  MeetingIntelligence
//
//  Created for Document Review & Signature Workflow
//

import SwiftUI
import UIKit

// MARK: - Signature Canvas View
/// A SwiftUI view that provides a canvas for capturing digital signatures
/// Uses UIKit's UIView for smooth drawing performance
struct SignatureCanvasView: View {
    @Binding var signatureImage: UIImage?
    @State private var paths: [SignaturePath] = []
    @State private var currentPath: SignaturePath = SignaturePath()
    @State private var canvasSize: CGSize = .zero
    
    let lineWidth: CGFloat = 3.0
    let strokeColor: Color = .black
    let backgroundColor: Color = Color(.systemGray6)
    
    var body: some View {
        VStack(spacing: 12) {
            // Signature Canvas
            GeometryReader { geometry in
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Signature line guide
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 40)
                    }
                    
                    // "Sign here" placeholder text
                    if paths.isEmpty && currentPath.points.isEmpty {
                        VStack {
                            Spacer()
                            Text("Sign here")
                                .font(.system(size: 14, weight: .regular, design: .default))
                                .foregroundColor(.gray.opacity(0.5))
                                .italic()
                                .padding(.bottom, 48)
                        }
                    }
                    
                    // Drawing canvas
                    Canvas { context, size in
                        // Draw all completed paths
                        for path in paths {
                            var bezierPath = Path()
                            if let firstPoint = path.points.first {
                                bezierPath.move(to: firstPoint)
                                for point in path.points.dropFirst() {
                                    bezierPath.addLine(to: point)
                                }
                            }
                            context.stroke(
                                bezierPath,
                                with: .color(strokeColor),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                            )
                        }
                        
                        // Draw current path
                        var currentBezierPath = Path()
                        if let firstPoint = currentPath.points.first {
                            currentBezierPath.move(to: firstPoint)
                            for point in currentPath.points.dropFirst() {
                                currentBezierPath.addLine(to: point)
                            }
                        }
                        context.stroke(
                            currentBezierPath,
                            with: .color(strokeColor),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                        )
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let point = value.location
                                currentPath.points.append(point)
                            }
                            .onEnded { _ in
                                if !currentPath.points.isEmpty {
                                    paths.append(currentPath)
                                    currentPath = SignaturePath()
                                    // Generate image after each stroke ends
                                    generateSignatureImage(size: geometry.size)
                                }
                            }
                    )
                }
                .onAppear {
                    canvasSize = geometry.size
                }
                .onChange(of: geometry.size) { _, newSize in
                    canvasSize = newSize
                }
            }
            .frame(height: 200)
            
            // Clear button
            HStack {
                Spacer()
                Button(action: clearSignature) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Clear")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                .disabled(paths.isEmpty && currentPath.points.isEmpty)
                .opacity((paths.isEmpty && currentPath.points.isEmpty) ? 0.5 : 1.0)
            }
        }
    }
    
    private func clearSignature() {
        paths.removeAll()
        currentPath = SignaturePath()
        signatureImage = nil
    }
    
    private func generateSignatureImage(size: CGSize) {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Draw all paths
            UIColor.black.setStroke()
            for path in paths {
                let bezierPath = UIBezierPath()
                bezierPath.lineWidth = lineWidth
                bezierPath.lineCapStyle = .round
                bezierPath.lineJoinStyle = .round
                
                if let firstPoint = path.points.first {
                    bezierPath.move(to: firstPoint)
                    for point in path.points.dropFirst() {
                        bezierPath.addLine(to: point)
                    }
                }
                bezierPath.stroke()
            }
        }
        signatureImage = image
    }
}

// MARK: - Signature Path Model
struct SignaturePath: Identifiable {
    let id = UUID()
    var points: [CGPoint] = []
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var signature: UIImage?
        
        var body: some View {
            VStack(spacing: 20) {
                SignatureCanvasView(signatureImage: $signature)
                    .padding()
                
                if signature != nil {
                    Text("Signature captured ✓")
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    return PreviewWrapper()
}
