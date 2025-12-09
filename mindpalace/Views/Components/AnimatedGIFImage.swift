import SwiftUI
import UIKit
import ImageIO

// UIKit wrapper for animated GIF
struct AnimatedGIFImage: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        // Stop any existing animation and clear memory
        uiView.stopAnimating()
        uiView.animationImages = nil

        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }

        let frameCount = CGImageSourceGetCount(source)

        // Limit frame count to prevent memory issues
        let maxFrames = 50 // Limit to 50 frames
        let step = max(1, frameCount / maxFrames)

        var images: [UIImage] = []
        var totalDuration: TimeInterval = 0

        for i in stride(from: 0, to: frameCount, by: step) {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }

            // Get frame duration
            var frameDuration: TimeInterval = 0.1
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
               let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                if let delayTime = gifProperties[kCGImagePropertyGIFUnclampedDelayTime as String] as? TimeInterval {
                    frameDuration = delayTime
                } else if let delayTime = gifProperties[kCGImagePropertyGIFDelayTime as String] as? TimeInterval {
                    frameDuration = delayTime
                }
            }

            // Scale down images to reduce memory
            let maxSize: CGFloat = 800
            let scaledImage = scaleImage(UIImage(cgImage: cgImage), maxSize: maxSize)
            images.append(scaledImage)
            totalDuration += frameDuration * Double(step)
        }

        if !images.isEmpty {
            uiView.animationImages = images
            uiView.animationDuration = totalDuration
            uiView.animationRepeatCount = 0 // Loop forever
            uiView.startAnimating()
        }
    }

    private func scaleImage(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        if size.width <= maxSize && size.height <= maxSize {
            return image
        }

        let scale = min(maxSize / size.width, maxSize / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return scaledImage ?? image
    }

    static func dismantleUIView(_ uiView: UIImageView, coordinator: ()) {
        // Clean up when view is removed
        uiView.stopAnimating()
        uiView.animationImages = nil
        uiView.image = nil
    }
}

// Enhanced TappableAsyncImage with GIF support
struct EnhancedAsyncImage: View {
    let url: URL?
    @State private var imageData: Data?
    @State private var isLoading = true
    @State private var showingZoom = false
    @State private var isGIFPlaying = false

    private var isGIF: Bool {
        url?.pathExtension.lowercased() == "gif"
    }

    var body: some View {
        Group {
            if url != nil {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .task {
                            await loadImage()
                        }
                } else if let data = imageData, isGIF {
                    // Animated GIF with play button overlay
                    ZStack {
                        if isGIFPlaying {
                            AnimatedGIFImage(data: data)
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: 400)
                        } else {
                            // Show first frame as static image
                            if let firstFrame = getFirstFrame(from: data) {
                                Image(uiImage: firstFrame)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                                    .frame(maxHeight: 400)
                            }
                        }

                        // Play button overlay
                        if !isGIFPlaying {
                            Button {
                                isGIFPlaying = true
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                        .frame(width: 60, height: 60)

                                    Image(systemName: "play.fill")
                                        .font(.title)
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                    .onTapGesture {
                        if isGIFPlaying {
                            showingZoom = true
                        }
                    }
                } else if let data = imageData, let uiImage = UIImage(data: data) {
                    // Static image
                    Button {
                        showingZoom = true
                    } label: {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "photo.fill")
                        .foregroundStyle(.gray)
                        .frame(height: 200)
                }
            } else {
                Image(systemName: "photo.fill")
                    .foregroundStyle(.gray)
            }
        }
        .fullScreenCover(isPresented: $showingZoom) {
            if isGIF, let data = imageData {
                // Use custom GIF viewer for animated GIFs
                ZoomableGIFView(data: data)
            } else if let url = url {
                // Use optimized ZoomableImageView for static images
                ZoomableImageView(url: url)
            }
        }
    }

    private func loadImage() async {
        guard let url = url else {
            isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            await MainActor.run {
                imageData = data
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func getFirstFrame(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

// Zoomable view for animated GIFs
struct ZoomableGIFView: View {
    let data: Data
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()

                    AnimatedGIFImage(data: data)
                        .scaleEffect(scale)
                        .offset(offset)
                }
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let newScale = lastScale * value
                            scale = min(max(newScale, 1.0), 5.0) // Limit zoom between 1x and 5x
                        }
                        .onEnded { value in
                            lastScale = scale
                            // Reset if zoomed out completely
                            if scale <= 1.0 {
                                withAnimation(.spring(response: 0.3)) {
                                    scale = 1.0
                                    lastScale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if scale > 1.0 {
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                        }
                        .onEnded { value in
                            lastOffset = offset
                        }
                )
                .onTapGesture(count: 2) {
                    // Double tap to zoom in/out
                    withAnimation(.spring(response: 0.3)) {
                        if scale > 1.0 {
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2.5
                            lastScale = 2.5
                        }
                    }
                }
            }
            .navigationTitle("Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .background(Color.black)
        }
    }
}
