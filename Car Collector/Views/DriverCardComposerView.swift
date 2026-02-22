//
//  DriverCardComposerView.swift
//  CarCardCollector
//
//  Portrait-oriented composer for driver-only cards
//  Card is 9:16 portrait ratio so driver photos look natural
//  Name renders vertically along the right edge
//

import SwiftUI

struct DriverCardComposerView: View {
    let image: UIImage
    let onSave: (UIImage) -> Void
    let onRetake: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var displayImage: UIImage = UIImage()
    @State private var rotation: Angle = .zero
    @State private var isFlippedHorizontally = false
    @State private var isFlippedVertically = false
    
    // Portrait card dimensions (9:16 ratio)
    private let cardWidth: CGFloat = 270
    private var cardHeight: CGFloat { cardWidth * (16.0 / 9.0) } // 480
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Portrait card frame with zoomable/pannable image
                ZStack {
                    // The photo (zoomable and pannable)
                    Image(uiImage: displayImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(x: isFlippedHorizontally ? -1 : 1, y: isFlippedVertically ? -1 : 1)
                        .rotationEffect(rotation)
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                    
                    // Portrait frame border
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: cardWidth, height: cardHeight)
                        .allowsHitTesting(false)
                }
                
                // Transform controls
                HStack(spacing: 24) {
                    Button(action: rotateLeft) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.pTitle3)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.gray.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    Button(action: rotateRight) {
                        Image(systemName: "arrow.clockwise")
                            .font(.pTitle3)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.gray.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    Button(action: flipHorizontal) {
                        Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                            .font(.pTitle3)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.gray.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    Button(action: flipVertical) {
                        Image(systemName: "arrow.up.and.down.righttriangle.up.righttriangle.down")
                            .font(.pTitle3)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.gray.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 16)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 20) {
                    Button(action: onRetake) {
                        Text("Retake")
                            .font(.pHeadline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.red)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        let finalImage = renderPortraitCard()
                        onSave(finalImage)
                    }) {
                        Text("Save")
                            .font(.pHeadline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green)
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
            
            // Instructions
            VStack {
                Text("Pinch to zoom, drag to position")
                    .font(.pCaption)
                    .foregroundStyle(.white)
                    .padding()
                    .background(.black.opacity(0.6))
                    .cornerRadius(10)
                    .padding()
                
                Spacer()
            }
            .allowsHitTesting(false)
        }
        .onAppear {
            displayImage = image
        }
    }
    
    // MARK: - Render Card
    
    private func renderPortraitCard() -> UIImage {
        // Step 1: Render what the user framed in the portrait 9:16 composer
        let portraitWidth: CGFloat = 1080
        let portraitHeight: CGFloat = 1920
        let portraitSize = CGSize(width: portraitWidth, height: portraitHeight)
        
        let scaleX = portraitWidth / cardWidth
        let scaleY = portraitHeight / cardHeight
        
        let portraitRenderer = UIGraphicsImageRenderer(size: portraitSize)
        let portraitImage = portraitRenderer.image { context in
            let cgContext = context.cgContext
            
            cgContext.saveGState()
            cgContext.clip(to: CGRect(origin: .zero, size: portraitSize))
            cgContext.translateBy(x: portraitSize.width / 2, y: portraitSize.height / 2)
            
            cgContext.translateBy(x: offset.width * scaleX, y: offset.height * scaleY)
            cgContext.scaleBy(x: scale, y: scale)
            cgContext.rotate(by: rotation.radians)
            cgContext.scaleBy(x: isFlippedHorizontally ? -1 : 1, y: isFlippedVertically ? -1 : 1)
            
            let imageSize = displayImage.size
            let imageAspect = imageSize.width / imageSize.height
            let frameAspect = portraitSize.width / portraitSize.height
            
            var drawSize: CGSize
            if imageAspect > frameAspect {
                drawSize = CGSize(width: portraitSize.height * imageAspect, height: portraitSize.height)
            } else {
                drawSize = CGSize(width: portraitSize.width, height: portraitSize.width / imageAspect)
            }
            
            let imageRect = CGRect(
                x: -drawSize.width / 2,
                y: -drawSize.height / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            displayImage.draw(in: imageRect)
            cgContext.restoreGState()
        }
        
        // Step 2: Rotate 90° counter-clockwise to produce 16:9 landscape card (1920x1080)
        // Fullscreen view adds 90° clockwise, so this restores portrait orientation
        let landscapeSize = CGSize(width: portraitHeight, height: portraitWidth)
        let landscapeRenderer = UIGraphicsImageRenderer(size: landscapeSize)
        return landscapeRenderer.image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: landscapeSize.width / 2, y: landscapeSize.height / 2)
            cgContext.rotate(by: -.pi / 2)
            portraitImage.draw(in: CGRect(
                x: -portraitSize.width / 2,
                y: -portraitSize.height / 2,
                width: portraitSize.width,
                height: portraitSize.height
            ))
        }
    }
    
    // MARK: - Transforms
    
    private func rotateLeft() {
        rotation -= .degrees(90)
    }
    
    private func rotateRight() {
        rotation += .degrees(90)
    }
    
    private func flipHorizontal() {
        isFlippedHorizontally.toggle()
    }
    
    private func flipVertical() {
        isFlippedVertically.toggle()
    }
}

#Preview {
    DriverCardComposerView(
        image: UIImage(systemName: "person.fill")!,
        onSave: { _ in },
        onRetake: { }
    )
}
