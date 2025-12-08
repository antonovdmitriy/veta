import Foundation
import SwiftUI
import MarkdownUI

struct GitHubImageProvider: ImageProvider {
    let repository: GitHubRepository?
    let filePath: String
    let branch: String

    init(repository: GitHubRepository?, filePath: String, branch: String = "main") {
        self.repository = repository
        self.filePath = filePath
        self.branch = branch
    }

    func makeImage(url: URL?) -> some View {
        Group {
            if let url = url {
                if url.scheme != nil {
                    // Absolute URL (http/https)
                    TappableAsyncImage(url: url)
                } else {
                    // Relative URL - resolve to GitHub raw URL
                    if let resolvedURL = resolveGitHubURL(relativePath: url.path) {
                        TappableAsyncImage(url: resolvedURL)
                    } else {
                        Image(systemName: "photo.fill")
                            .foregroundStyle(.gray)
                    }
                }
            } else {
                Image(systemName: "photo.fill")
                    .foregroundStyle(.gray)
            }
        }
    }

    private func resolveGitHubURL(relativePath: String) -> URL? {
        guard let repository = repository else { return nil }

        // Get directory of the current markdown file
        let fileDirectory = (filePath as NSString).deletingLastPathComponent

        // Resolve relative path
        var resolvedPath: String
        if relativePath.hasPrefix("./") {
            // Same directory: ./images/image.png
            let imagePath = String(relativePath.dropFirst(2))
            resolvedPath = fileDirectory.isEmpty ? imagePath : "\(fileDirectory)/\(imagePath)"
        } else if relativePath.hasPrefix("../") {
            // Parent directory: ../images/image.png
            var components = fileDirectory.components(separatedBy: "/")
            var imageComponents = relativePath.components(separatedBy: "/")

            // Remove parent directory references
            while imageComponents.first == ".." {
                imageComponents.removeFirst()
                if !components.isEmpty {
                    components.removeLast()
                }
            }

            let basePath = components.joined(separator: "/")
            let imagePath = imageComponents.joined(separator: "/")
            resolvedPath = basePath.isEmpty ? imagePath : "\(basePath)/\(imagePath)"
        } else if relativePath.hasPrefix("/") {
            // Root relative: /images/image.png
            resolvedPath = String(relativePath.dropFirst())
        } else {
            // Direct relative: images/image.png
            resolvedPath = fileDirectory.isEmpty ? relativePath : "\(fileDirectory)/\(relativePath)"
        }

        // Build GitHub raw URL
        // Format: https://raw.githubusercontent.com/owner/repo/branch/path
        let urlString = "\(Constants.GitHub.rawContentURL)/\(repository.owner)/\(repository.name)/\(branch)/\(resolvedPath)"

        return URL(string: urlString)
    }
}
