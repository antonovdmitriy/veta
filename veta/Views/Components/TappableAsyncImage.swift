import SwiftUI

struct TappableAsyncImage: View {
    let url: URL?
    @State private var showingZoom = false

    var body: some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        Button {
                            showingZoom = true
                        } label: {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                        .buttonStyle(.plain)
                    case .failure:
                        Image(systemName: "photo.fill")
                            .foregroundStyle(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
                .fullScreenCover(isPresented: $showingZoom) {
                    ZoomableImageView(url: url)
                }
            } else {
                Image(systemName: "photo.fill")
                    .foregroundStyle(.gray)
            }
        }
    }
}

#Preview {
    TappableAsyncImage(url: URL(string: "https://picsum.photos/400/300"))
        .frame(height: 200)
}
