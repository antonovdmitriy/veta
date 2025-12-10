import SwiftUI
import SwiftData

@main
struct vetaApp: App {
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
            // If migration fails, warn and delete old store
            print("⚠️ Migration failed: \(error)")
            print("⚠️ DATABASE MIGRATION ERROR: Your data will be reset due to incompatible schema changes.")
            print("⚠️ This is a one-time reset. Future updates will preserve your data.")

            // Delete old store files
            let fileManager = FileManager.default
            if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let storeURL = appSupportURL.appendingPathComponent("default.store")
                let shmURL = appSupportURL.appendingPathComponent("default.store-shm")
                let walURL = appSupportURL.appendingPathComponent("default.store-wal")

                print("⚠️ Deleting old database at: \(storeURL.path)")

                for url in [storeURL, shmURL, walURL] {
                    if fileManager.fileExists(atPath: url.path) {
                        try? fileManager.removeItem(at: url)
                        print("⚠️ Deleted: \(url.lastPathComponent)")
                    }
                }
            }

            print("⚠️ Creating fresh database. Please re-add your repositories.")

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
            } catch {
                fatalError("❌ Failed to initialize ModelContainer: \(error)")
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
