import SwiftUI
import UIKit
import ImageIO

// UIKit wrapper for animated GIF
struct AnimatedGIFImage: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }

        let frameCount = CGImageSourceGetCount(source)
        var images: [UIImage] = []
        var totalDuration: TimeInterval = 0

        for i in 0..<frameCount {
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

            images.append(UIImage(cgImage: cgImage))
            totalDuration += frameDuration
        }

        if !images.isEmpty {
            uiView.animationImages = images
            uiView.animationDuration = totalDuration
            uiView.animationRepeatCount = 0 // Loop forever
            uiView.startAnimating()
        }
    }
}

// Enhanced TappableAsyncImage with GIF support
struct EnhancedAsyncImage: View {
    let url: URL?
    @State private var imageData: Data?
    @State private var isLoading = true
    @State private var showingZoom = false

    private var isGIF: Bool {
        url?.pathExtension.lowercased() == "gif"
    }

    var body: some View {
        Group {
            if let url = url {
                if isLoading {
                    ProgressView()
                        .task {
                            await loadImage()
                        }
                } else if let data = imageData, isGIF {
                    // Animated GIF
                    Button {
                        showingZoom = true
                    } label: {
                        AnimatedGIFImage(data: data)
                            .frame(maxHeight: 400)
                    }
                    .buttonStyle(.plain)
                } else if let data = imageData, let uiImage = UIImage(data: data) {
                    // Static image
                    Button {
                        showingZoom = true
                    } label: {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "photo.fill")
                        .foregroundStyle(.gray)
                }

                // Full screen zoom view
                if showingZoom, let data = imageData {
                    EmptyView()
                        .fullScreenCover(isPresented: $showingZoom) {
                            ZoomableGIFView(data: data, url: url, isGIF: isGIF)
                        }
                }
            } else {
                Image(systemName: "photo.fill")
                    .foregroundStyle(.gray)
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
}

// Zoomable view for both GIF and static images
struct ZoomableGIFView: View {
    let data: Data
    let url: URL?
    let isGIF: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    if isGIF {
                        AnimatedGIFImage(data: data)
                            .frame(
                                width: geometry.size.width * scale,
                                height: geometry.size.height * scale
                            )
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = lastScale * value
                                    }
                                    .onEnded { value in
                                        lastScale = scale
                                    }
                            )
                    } else if let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(
                                width: geometry.size.width * scale,
                                height: geometry.size.height * scale
                            )
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = lastScale * value
                                    }
                                    .onEnded { value in
                                        lastScale = scale
                                    }
                            )
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
