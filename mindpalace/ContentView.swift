//
//  ContentView.swift
//  mindpalace
//
//  Created by Dmitrii Antonov on 2025-12-07.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            StudyView()
                .tabItem {
                    Label("Study", systemImage: "brain.head.profile")
                }
                .tag(0)

            RepositoriesView()
                .tabItem {
                    Label("Repositories", systemImage: "folder")
                }
                .tag(1)

            StatisticsView()
                .tabItem {
                    Label("Statistics", systemImage: "chart.bar")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
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
