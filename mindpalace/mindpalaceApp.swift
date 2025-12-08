import SwiftUI
import SwiftData

@main
struct mindpalaceApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                GitHubRepository.self,
                MarkdownFile.self,
                MarkdownSection.self,
                RepetitionRecord.self,
                UserSettings.self
            ])

            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )

            modelContainer = try ModelContainer(
                for: schema,
                configurations: configuration
            )
        } catch {
            // If migration fails, delete old store and create fresh container
            print("⚠️ Migration failed: \(error)")
            print("🗑️ Attempting to delete old database and create fresh container...")

            // Delete old store files
            let fileManager = FileManager.default
            if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let storeURL = appSupportURL.appendingPathComponent("default.store")
                let shmURL = appSupportURL.appendingPathComponent("default.store-shm")
                let walURL = appSupportURL.appendingPathComponent("default.store-wal")

                for url in [storeURL, shmURL, walURL] {
                    if fileManager.fileExists(atPath: url.path) {
                        do {
                            try fileManager.removeItem(at: url)
                            print("✅ Removed: \(url.lastPathComponent)")
                        } catch {
                            print("⚠️ Failed to remove \(url.lastPathComponent): \(error)")
                        }
                    }
                }
            }

            // Create fresh container
            do {
                let schema = Schema([
                    GitHubRepository.self,
                    MarkdownFile.self,
                    MarkdownSection.self,
                    RepetitionRecord.self,
                    UserSettings.self
                ])

                let configuration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false
                )

                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: configuration
                )
                print("✅ Successfully created fresh container")
            } catch {
                fatalError("❌ Failed to initialize ModelContainer even after cleanup: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
        }
    }
}
