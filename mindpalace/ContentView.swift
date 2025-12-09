//
//  ContentView.swift
//  mindpalace
//
//  Created by Dmitrii Antonov on 2025-12-07.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    @State private var selectedTab = 0

    private var currentTheme: AppTheme {
        settings.first?.theme ?? .system
    }

    private var colorScheme: ColorScheme? {
        switch currentTheme {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            StudyView()
                .tabItem {
                    Label("Study", systemImage: "brain.head.profile")
                }
                .tag(0)

            DocumentsView()
                .tabItem {
                    Label("Documents", systemImage: "book.fill")
                }
                .tag(1)

            RepositoriesView()
                .tabItem {
                    Label("Repositories", systemImage: "folder")
                }
                .tag(2)

            StatisticsView()
                .tabItem {
                    Label("Statistics", systemImage: "chart.bar")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .preferredColorScheme(colorScheme)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            GitHubRepository.self,
            MarkdownFile.self,
            MarkdownSection.self,
            RepetitionRecord.self,
            UserSettings.self
        ], inMemory: true)
}
