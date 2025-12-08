# Mind Palace - План проекта

## Описание проекта
Система интервального повторения знаний из Markdown файлов, хранящихся в GitHub репозиториях.

## Основные требования
- Просмотр Markdown файлов на iPhone и Desktop (macOS)
- Повторение по подзаголовкам (sections)
- Равномерное распределение повторений по всему материалу
- Отслеживание прогресса повторений
- Синхронизация через GitHub Gist
- Обновление данных из GitHub по кнопке
- Поддержка приватных репозиториев (требуется GitHub OAuth)

## Технологический стек
- **iOS**: SwiftUI + Swift 5.9+
- **macOS**: SwiftUI (shared codebase)
- **Минимальная версия**: iOS 16+, macOS 13+
- **Хранение данных**: SwiftData (Core Data замена)
- **Сеть**: URLSession + async/await
- **Markdown**: Down или MarkdownUI библиотека
- **Синхронизация**: GitHub Gist API

## Архитектура приложения

### Слои приложения
```
┌─────────────────────────────────────┐
│         Presentation Layer          │
│    (SwiftUI Views + ViewModels)     │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│         Business Logic Layer        │
│  (RepetitionEngine, SyncManager)    │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│          Data Layer                 │
│  (Models, Repositories, Services)   │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│      External Services              │
│  (GitHub API, Gist API, Storage)    │
└─────────────────────────────────────┘
```

### Основные модули

#### 1. Data Models (Models/)
- `GitHubRepository` - конфигурация репозитория
- `MarkdownFile` - файл из репозитория
- `MarkdownSection` - подзаголовок с контентом
- `RepetitionRecord` - запись о повторении
- `UserSettings` - настройки пользователя

#### 2. Services (Services/)
- `GitHubService` - работа с GitHub API
  - Аутентификация (OAuth)
  - Получение файлов из репозитория
  - Работа с приватными репо
- `GistService` - синхронизация через Gist
  - Сохранение прогресса
  - Загрузка прогресса
  - Merge локального и удаленного состояния
- `MarkdownParser` - парсинг Markdown
  - Извлечение заголовков
  - Группировка контента по секциям
  - Обработка изображений (локальные + URL)
- `StorageService` - локальное хранилище (SwiftData)

#### 3. Business Logic (Core/)
- `RepetitionEngine` - алгоритм повторения
  - Выбор следующей секции для повторения
  - Обновление статистики
  - Фильтрация по критериям
- `SyncManager` - управление синхронизацией
  - Обновление из GitHub
  - Синхронизация прогресса через Gist
  - Conflict resolution

#### 4. Presentation (Views/)
- `RepositoriesView` - список репозиториев
- `StudyView` - экран повторения (карточка с секцией)
- `SettingsView` - настройки и GitHub авторизация
- `StatisticsView` - статистика прогресса

## Детальный план разработки

### Этап 1: Инициализация проекта ✓
- [x] Создать структуру каталогов
- [ ] Создать Xcode проект (iOS + macOS targets)
- [ ] Настроить Package.swift для зависимостей
- [ ] Инициализировать Git репозиторий

### Этап 2: Data Layer
**Цель**: Создать модели данных и базовое хранилище

#### 2.1 SwiftData Models
```swift
// GitHubRepository.swift
@Model
class GitHubRepository {
    var id: UUID
    var name: String
    var owner: String
    var url: String
    var isPrivate: Bool
    var accessToken: String?
    var lastSync: Date?
    var files: [MarkdownFile]
}

// MarkdownFile.swift
@Model
class MarkdownFile {
    var id: UUID
    var path: String
    var repository: GitHubRepository
    var content: String?
    var lastUpdated: Date
    var sections: [MarkdownSection]
}

// MarkdownSection.swift
@Model
class MarkdownSection {
    var id: UUID
    var file: MarkdownFile
    var title: String
    var content: String
    var level: Int // H1=1, H2=2, etc.
    var lineStart: Int
    var lineEnd: Int
}

// RepetitionRecord.swift
@Model
class RepetitionRecord {
    var id: UUID
    var section: MarkdownSection
    var reviewedAt: Date
    var reviewCount: Int
    var ease: Double // для будущего SM-2 алгоритма
}
```

#### 2.2 Storage Service
- Настроить SwiftData ModelContainer
- CRUD операции для всех моделей
- Queries для получения секций по критериям

### Этап 3: GitHub Integration
**Цель**: Интеграция с GitHub API

#### 3.1 GitHub OAuth
```swift
// AuthenticationService.swift
- Настроить OAuth flow через ASWebAuthenticationSession
- Получить Personal Access Token
- Сохранить токен в Keychain
```

#### 3.2 GitHub API Client
```swift
// GitHubService.swift
- GET /repos/{owner}/{repo}/contents/{path}
- Рекурсивное получение всех .md файлов
- Скачивание raw контента
- Обработка rate limits
- Кэширование ответов
```

Эндпоинты:
- `listFiles(repo:path:)` - список файлов
- `downloadFile(repo:path:)` - скачать содержимое
- `getRepositoryInfo(owner:name:)` - информация о репо

#### 3.3 Обработка изображений
- Локальные изображения: скачать вместе с markdown
- URL изображения: lazy loading в UI
- Кэширование изображений

### Этап 4: Markdown Parsing
**Цель**: Парсинг и структурирование Markdown

#### 4.1 Интеграция библиотеки
Использовать: **MarkdownUI** (https://github.com/gonzalezreal/swift-markdown-ui)
```swift
dependencies: [
    .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.0.0")
]
```

#### 4.2 Parser Implementation
```swift
// MarkdownParser.swift
class MarkdownParser {
    func parse(content: String) -> [MarkdownSection]
    func extractSections(document: Document) -> [Section]
    func resolveImagePaths(in: String, basePath: String) -> String
}
```

Логика:
1. Парсить Markdown в AST
2. Найти все заголовки (H1-H6)
3. Группировать контент между заголовками
4. Создать `MarkdownSection` объекты

### Этап 5: Repetition Algorithm
**Цель**: Алгоритм равномерного повторения

#### 5.1 Simple Round-Robin (MVP)
```swift
// RepetitionEngine.swift
class RepetitionEngine {
    // Получить следующую секцию для повторения
    func getNextSection() -> MarkdownSection?

    // Отметить секцию как повторенную
    func markAsReviewed(section: MarkdownSection)

    // Получить статистику
    func getStatistics() -> ReviewStatistics
}
```

Алгоритм:
1. Получить все секции из всех файлов
2. Отсортировать по `lastReviewedAt` (ASC) или nil
3. Вернуть первую (самую давно не повторенную)
4. После показа: создать `RepetitionRecord`, обновить timestamp

#### 5.2 Advanced (Future)
- Spaced Repetition (SM-2 algorithm)
- Приоритеты секций
- Фильтры по репозиториям/файлам
- "Сложные" секции повторять чаще

### Этап 6: Gist Synchronization
**Цель**: Синхронизация прогресса между устройствами

#### 6.1 Gist Service
```swift
// GistService.swift
class GistService {
    private let gistId: String = "mindpalace_progress"

    func uploadProgress(_ records: [RepetitionRecord]) async throws
    func downloadProgress() async throws -> [RepetitionRecord]
    func mergeProgress(local: [RepetitionRecord],
                       remote: [RepetitionRecord]) -> [RepetitionRecord]
}
```

Структура Gist файла (JSON):
```json
{
  "version": "1.0",
  "lastSync": "2025-12-07T10:00:00Z",
  "records": [
    {
      "sectionId": "repo_owner_file_section_hash",
      "reviewedAt": "2025-12-07T09:30:00Z",
      "reviewCount": 3,
      "ease": 2.5
    }
  ]
}
```

#### 6.2 Sync Strategy
- **Auto-sync**: при запуске приложения
- **Manual sync**: кнопка "обновить"
- **Conflict resolution**: последняя дата побеждает (last-write-wins)

#### 6.3 Offline Support
- Локальная очередь изменений
- Sync при появлении сети
- Показывать индикатор "не синхронизировано"

### Этап 7: SwiftUI Views (iOS)

#### 7.1 App Structure
```
MindPalaceApp
├── RepositoriesView (главный экран)
│   ├── RepositoryRow
│   └── AddRepositorySheet
├── StudyView (повторение)
│   ├── SectionCard
│   └── ProgressBar
├── SettingsView
│   ├── GitHubAuthSection
│   ├── SyncSection
│   └── AppearanceSection
└── StatisticsView
    ├── ProgressChart
    └── StreakCounter
```

#### 7.2 RepositoriesView
- Список добавленных репозиториев
- Кнопка "+" для добавления нового
- Pull-to-refresh для синхронизации
- Badge с количеством файлов/секций

#### 7.3 StudyView (основной экран)
- Карточка с Markdown секцией
- Рендеринг Markdown (текст, код, изображения)
- Навигация:
  - Swipe right: следующая секция
  - Swipe left: предыдущая
- Кнопки:
  - "Понятно" (mark as reviewed)
  - "Сложно" (review again soon)
  - "Пропустить"
- Progress bar: сколько секций повторено сегодня

#### 7.4 SettingsView
- GitHub авторизация (OAuth кнопка)
- Управление репозиториями
- Настройки синхронизации (auto/manual)
- Экспорт/импорт данных
- О приложении

#### 7.5 StatisticsView
- Общее количество секций
- Повторено сегодня/неделю/месяц
- Streak (дни подряд)
- График прогресса (опционально)
- Топ репозитории по повторениям

### Этап 8: macOS Version
**Цель**: Адаптировать для macOS

#### 8.1 Shared Code
- Все Models, Services, Core - общие
- SwiftUI Views - минимальная адаптация

#### 8.2 macOS Specific UI
- Sidebar navigation (вместо TabView)
- Toolbar с кнопками
- Keyboard shortcuts (←→ для навигации)
- Larger canvas для Markdown

#### 8.3 macOS Target в Xcode
- Добавить macOS target
- Настроить entitlements (network, keychain)
- Shared framework для общего кода

### Этап 9: Polish & Testing

#### 9.1 Error Handling
- Graceful failures для network requests
- Retry logic для GitHub API
- User-friendly error messages
- Logging для debugging

#### 9.2 Performance
- Lazy loading файлов
- Pagination для больших репозиториев
- Image caching
- Background fetch для синхронизации

#### 9.3 UI/UX
- Dark mode support
- Accessibility (VoiceOver)
- Haptic feedback
- Animations (subtle)
- Loading states

#### 9.4 Testing
- Unit tests для RepetitionEngine
- Integration tests для GitHub API
- UI tests для основных flows

## Структура файлов проекта

```
MindPalace/
├── MindPalace.xcodeproj
├── Shared/
│   ├── Models/
│   │   ├── GitHubRepository.swift
│   │   ├── MarkdownFile.swift
│   │   ├── MarkdownSection.swift
│   │   ├── RepetitionRecord.swift
│   │   └── UserSettings.swift
│   ├── Services/
│   │   ├── GitHub/
│   │   │   ├── GitHubService.swift
│   │   │   ├── GitHubAuthService.swift
│   │   │   └── GitHubModels.swift
│   │   ├── Gist/
│   │   │   ├── GistService.swift
│   │   │   └── GistModels.swift
│   │   ├── Markdown/
│   │   │   ├── MarkdownParser.swift
│   │   │   └── ImageResolver.swift
│   │   └── Storage/
│   │       └── StorageService.swift
│   ├── Core/
│   │   ├── RepetitionEngine.swift
│   │   ├── SyncManager.swift
│   │   └── Statistics.swift
│   └── Utilities/
│       ├── Constants.swift
│       ├── Extensions/
│       └── Keychain.swift
├── iOS/
│   ├── MindPalaceApp.swift
│   ├── Views/
│   │   ├── Repositories/
│   │   │   ├── RepositoriesView.swift
│   │   │   └── AddRepositoryView.swift
│   │   ├── Study/
│   │   │   ├── StudyView.swift
│   │   │   └── SectionCardView.swift
│   │   ├── Settings/
│   │   │   └── SettingsView.swift
│   │   └── Statistics/
│   │       └── StatisticsView.swift
│   ├── ViewModels/
│   │   ├── RepositoriesViewModel.swift
│   │   ├── StudyViewModel.swift
│   │   └── SettingsViewModel.swift
│   ├── Assets.xcassets/
│   └── Info.plist
├── macOS/
│   ├── MindPalaceApp.swift
│   └── Views/
│       └── (адаптированные версии iOS views)
├── Tests/
│   ├── ModelTests/
│   ├── ServiceTests/
│   └── CoreTests/
└── Package.swift
```

## Зависимости (Package.swift)

```swift
dependencies: [
    // Markdown rendering
    .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.0.0"),

    // Networking (опционально, если нужен более мощный клиент)
    // .package(url: "https://github.com/Alamofire/Alamofire", from: "5.8.0"),

    // Keychain
    .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2"),
]
```

## MVP Features (Минимальная версия)

### Must Have:
1. ✅ Добавление репозиториев (URL + токен)
2. ✅ Скачивание .md файлов из GitHub
3. ✅ Парсинг Markdown на секции
4. ✅ Показ секций по одной (карточка)
5. ✅ Round-robin алгоритм повторения
6. ✅ Локальное сохранение прогресса
7. ✅ Кнопка обновления из GitHub

### Nice to Have (v1.1+):
- Синхронизация через Gist
- macOS версия
- Статистика и графики
- Spaced repetition алгоритм
- Фильтры и поиск
- Темная тема
- Экспорт данных

## Timeline (оценка)

- **Этапы 1-2** (проект + модели): 1-2 дня
- **Этап 3** (GitHub интеграция): 3-5 дней
- **Этап 4** (Markdown парсинг): 2-3 дня
- **Этап 5** (алгоритм повторения): 2 дня
- **Этап 6** (Gist sync): 3-4 дня
- **Этап 7** (iOS UI): 5-7 дней
- **Этап 8** (macOS): 3-5 дней
- **Этап 9** (polish): 3-5 дней

**Итого MVP**: ~2-3 недели
**Полная версия**: ~1.5-2 месяца

## Важные технические решения

### 1. Идентификация секций
Проблема: как уникально идентифицировать секцию между синхронизациями?

Решение: Hash на основе:
```swift
let sectionId = "\(repo.owner)_\(repo.name)_\(file.path)_\(section.title)_\(section.lineStart)"
// или
let sectionId = SHA256("\(repo.url)/\(file.path)#\(section.title)")
```

### 2. Обновление контента
Если Markdown файл обновился на GitHub:
- Пересоздать секции
- Попытаться сопоставить старые секции с новыми (по заголовку)
- Сохранить прогресс для сопоставленных
- Новые секции - как непросмотренные

### 3. Приватные репозитории
- Personal Access Token через OAuth
- Сохранение в Keychain
- Scope: `repo` (для приватных), `public_repo` (для публичных)

### 4. Rate Limits
GitHub API rate limit: 5000 requests/hour (authenticated)
- Кэшировать responses
- Batch requests где возможно
- Показывать оставшийся лимит в UI

## Следующий шаг
Создать Xcode проект со следующей структурой:
- iOS target (основной)
- macOS target (shared code)
- SwiftData для моделей
- Настроить Package dependencies

---
**Создано**: 2025-12-07
**Версия**: 1.0
