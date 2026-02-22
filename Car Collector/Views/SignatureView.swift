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
    @State private var selectedColor: Color = .white
    @Environment(\.dismiss) private var dismiss
    
    private let colorOptions: [(Color, String)] = [
        (.white, "White"),
        (.black, "Black"),
        (.red, "Red"),
        (.blue, "Blue"),
        (.yellow, "Yellow"),
        (.green, "Green"),
        (.orange, "Orange"),
        (.purple, "Purple")
    ]
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
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
                
                // Card with signature overlay
                GeometryReader { geometry in
                    ZStack {
                        Image(uiImage: cardImage)
                            .resizable()
                            .scaledToFit()
                            .rotationEffect(.degrees(90))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        SignatureCanvasView(canvas: $canvas, isDirty: $isDirty, inkColor: selectedColor)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
                .padding(.horizontal)
                
                // Color picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(colorOptions, id: \.1) { color, name in
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedColor = color
                                    updateCanvasTool()
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(white: 0.2))
                                        .frame(width: 44, height: 44)
                                    
                                    Circle()
                                        .fill(color)
                                        .frame(width: 32, height: 32)
                                    
                                    if selectedColor == color {
                                        Circle()
                                            .stroke(Color.white, lineWidth: 3)
                                            .frame(width: 44, height: 44)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 16)
                
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
    
    private func updateCanvasTool() {
        let uiColor = UIColor(selectedColor)
        canvas.tool = PKInkingTool(.marker, color: uiColor, width: 8)
    }
    
    private func combineImageWithSignature() -> UIImage {
        var cardSize = cardImage.size
        
        let maxDimension: CGFloat = 2048
        if max(cardSize.width, cardSize.height) > maxDimension {
            let ratio = maxDimension / max(cardSize.width, cardSize.height)
            cardSize = CGSize(width: cardSize.width * ratio, height: cardSize.height * ratio)
        }
        
        let scale = UITraitCollection.current.displayScale
        let signatureFullImage = canvas.drawing.image(from: canvas.bounds, scale: scale)
        
        let renderer = UIGraphicsImageRenderer(size: cardSize)
        return renderer.image { context in
            let cgContext = context.cgContext
            cardImage.draw(in: CGRect(origin: .zero, size: cardSize))
            
            cgContext.saveGState()
            cgContext.translateBy(x: cardSize.width / 2, y: cardSize.height / 2)
            cgContext.rotate(by: -.pi / 2)
            
            let sigDrawWidth = cardSize.height
            let sigDrawHeight = cardSize.width
            
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
    var inkColor: Color
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.marker, color: UIColor(inkColor), width: 8)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.delegate = context.coordinator
        return canvas
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.tool = PKInkingTool(.marker, color: UIColor(inkColor), width: 8)
    }
    
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
