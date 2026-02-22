//
//  SignatureView.swift
//  CarCardCollector
//
//  Full-screen signature capture on driver card
//

import SwiftUI
import PencilKit

struct SignatureView: View {
    let cardImage: UIImage
    var onSignatureComplete: ((UIImage) -> Void)? = nil
    
    @State private var canvas = PKCanvasView()
    @State private var isDirty = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.pTitle2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Add Signature")
                        .font(.poppins(20))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        canvas.drawing = PKDrawing()
                        isDirty = false
                    }) {
                        Text("Clear")
                            .font(.poppins(16))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                .padding()
                
                // Card with signature overlay — rotated to portrait for driver cards
                GeometryReader { geometry in
                    ZStack {
                        // Card image rotated to portrait
                        Image(uiImage: cardImage)
                            .resizable()
                            .scaledToFit()
                            .rotationEffect(.degrees(90))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // Signature canvas overlay
                        SignatureCanvasView(canvas: $canvas, isDirty: $isDirty)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
                .padding()
                
                // Save button
                Button(action: {
                    let combinedImage = combineImageWithSignature()
                    onSignatureComplete?(combinedImage)
                    dismiss()
                }) {
                    Text("Save Signature")
                        .font(.poppins(18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isDirty ? Color.blue : Color.gray)
                        )
                }
                .disabled(!isDirty)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func combineImageWithSignature() -> UIImage {
        var cardSize = cardImage.size
        
        // Cap render size to prevent GPU memory crash on large RAW images
        let maxDimension: CGFloat = 2048
        if max(cardSize.width, cardSize.height) > maxDimension {
            let ratio = maxDimension / max(cardSize.width, cardSize.height)
            cardSize = CGSize(width: cardSize.width * ratio, height: cardSize.height * ratio)
        }
        
        // The card is displayed rotated 90° CW in the signature view (portrait),
        // but stored as landscape. We need to rotate the signature -90° to match.
        let scale = UITraitCollection.current.displayScale
        let signatureFullImage = canvas.drawing.image(from: canvas.bounds, scale: scale)
        
        let renderer = UIGraphicsImageRenderer(size: cardSize)
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // Draw card image
            cardImage.draw(in: CGRect(origin: .zero, size: cardSize))
            
            // Rotate signature -90° (counter-clockwise) to match landscape orientation
            cgContext.saveGState()
            cgContext.translateBy(x: cardSize.width / 2, y: cardSize.height / 2)
            cgContext.rotate(by: -.pi / 2)
            
            // After -90° rotation, the signature needs to be drawn in portrait dimensions
            // centered at origin
            let sigDrawWidth = cardSize.height  // portrait width maps to landscape height
            let sigDrawHeight = cardSize.width  // portrait height maps to landscape width
            
            signatureFullImage.draw(in: CGRect(
                x: -sigDrawWidth / 2,
                y: -sigDrawHeight / 2,
                width: sigDrawWidth,
                height: sigDrawHeight
            ))
            cgContext.restoreGState()
        }
    }
}

// Signature canvas wrapper
struct SignatureCanvasView: UIViewRepresentable {
    @Binding var canvas: PKCanvasView
    @Binding var isDirty: Bool
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .white, width: 3)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.delegate = context.coordinator
        return canvas
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isDirty: $isDirty)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var isDirty: Bool
        
        init(isDirty: Binding<Bool>) {
            _isDirty = isDirty
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            isDirty = !canvasView.drawing.bounds.isEmpty
        }
    }
}

#Preview {
    SignatureView(cardImage: UIImage(systemName: "person.fill")!)
}
