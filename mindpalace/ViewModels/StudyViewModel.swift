import Foundation
import SwiftData

@Observable
class StudyViewModel {
    private let modelContext: ModelContext
    private let repetitionEngine: RepetitionEngine

    var statistics: ReviewStatistics?

    // Navigation state
    var navigationStack: [MarkdownSection] = []
    var currentSection: MarkdownSection?
    var isShowingContext: Bool = false
    var isShowingFullDocument: Bool = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.repetitionEngine = RepetitionEngine(modelContext: modelContext)
        loadStatistics()
    }

    func getNextSection() -> MarkdownSection? {
        let section = repetitionEngine.getNextSection()
        currentSection = section
        navigationStack = []
        isShowingContext = false
        isShowingFullDocument = false
        return section
    }

    /// Get the original section that was loaded for review (before any navigation)
    func getOriginalSection() -> MarkdownSection? {
        // If navigation stack is empty, current section is the original
        if navigationStack.isEmpty {
            return currentSection
        }

        // The first item in the stack is the original section
        return navigationStack.first
    }

    func markAsReviewed(section: MarkdownSection, quality: Int = 3) {
        repetitionEngine.markAsReviewed(section: section, quality: quality)
        loadStatistics()
    }

    func loadStatistics() {
        statistics = repetitionEngine.getStatistics()
    }

    // MARK: - Navigation Methods

    /// Navigate up to parent section or full document
    func navigateToParent() {
        guard let current = currentSection else { return }

        // Get all sections for context
        let allSections = getAllSections()

        if let parent = current.getParentSection(from: allSections) {
            // Found a parent section - navigate to it
            navigationStack.append(current)
            currentSection = parent
            isShowingContext = true
            isShowingFullDocument = false
        } else if current.level >= 1 {
            // No parent section found but level >= 1, go to full document view
            navigationStack.append(current)
            isShowingContext = true
            isShowingFullDocument = true
        }
    }

    /// Navigate back to previous section in stack
    func navigateBack() {
        guard let previous = navigationStack.popLast() else {
            return // Nothing to go back to
        }

        currentSection = previous
        isShowingFullDocument = false
        if navigationStack.isEmpty {
            isShowingContext = false
        }
    }

    /// Navigate directly to a specific section from TOC
    func navigateToSection(_ section: MarkdownSection) {
        // Add current state to stack if we're in full document view
        if isShowingFullDocument, let current = currentSection {
            navigationStack.append(current)
        }

        currentSection = section
        isShowingFullDocument = false
        // Show context with children when navigating from TOC
        isShowingContext = true
    }

    /// Check if can navigate up
    func canNavigateUp() -> Bool {
        guard let current = currentSection else { return false }

        // If showing full document, can't go up anymore
        if isShowingFullDocument { return false }

        // If level >= 1, can always go up (either to parent or to full document)
        return current.level >= 1
    }

    /// Check if can navigate back
    func canNavigateBack() -> Bool {
        !navigationStack.isEmpty
    }

    /// Get content for current view (with children if showing context)
    func getCurrentContent() -> String {
        guard let current = currentSection else { return "" }

        if isShowingFullDocument {
            // Show entire document
            return getFullDocumentContent(for: current)
        } else if isShowingContext {
            // Show section with children
            let allSections = getAllSections()
            return current.getContentWithChildren(from: allSections)
        } else {
            // Show section with its title as markdown
            return "# \(current.title)\n\n\(current.content)"
        }
    }

    /// Get full document content (limited to avoid memory issues)
    private func getFullDocumentContent(for section: MarkdownSection) -> String {
        guard let file = section.file else { return section.content }

        let allSections = getAllSections()
        let fileSections = allSections
            .filter { $0.file?.id == file.id }
            .sorted { $0.orderIndex < $1.orderIndex }

        // Show table of contents instead of full content to avoid memory issues
        var content = "# 📄 \(file.fileName)\n\n"
        content += "## Table of Contents\n\n"

        for (index, section) in fileSections.enumerated() {
            let indent = String(repeating: "  ", count: max(0, section.level - 1))
            let prefix = String(repeating: "#", count: section.level)
            content += "\(indent)\(index + 1). **\(prefix) \(section.title)**\n"
        }

        content += "\n---\n\n"
        content += "_💡 Use the down arrow (↓) to navigate back to specific sections_\n"

        return content
    }

    /// Get all sections for the current file
    func getFileSections() -> [MarkdownSection] {
        guard let current = currentSection, let file = current.file else { return [] }

        let allSections = getAllSections()
        return allSections
            .filter { $0.file?.id == file.id }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    // MARK: - Helper Methods

    private func getAllSections() -> [MarkdownSection] {
        let descriptor = FetchDescriptor<MarkdownSection>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
