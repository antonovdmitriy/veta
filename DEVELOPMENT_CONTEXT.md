# Mind Palace - Контекст разработки

**Документ для восстановления контекста при продолжении разработки**

## 📋 Что это за проект?

**Mind Palace** - iOS приложение для интервального повторения знаний из Markdown файлов, хранящихся в GitHub репозиториях.

### Основная идея
Пользователь добавляет свои репозитории с заметками в Markdown формате, приложение:
1. Парсит файлы на секции (по заголовкам)
2. Показывает секции по одной для повторения
3. Отслеживает прогресс (что повторено, когда)
4. Равномерно распределяет повторения по всему материалу

## 🏗️ Архитектура проекта

### Структура файлов
```
/Users/Dimaantonov/CODE/mindpalaceapp/mindpalace/
├── mindpalace.xcodeproj          # Xcode проект
├── Package.swift                  # Swift Package зависимости
├── PROJECT_STATUS.md              # Текущий статус (ЧТО сделано)
├── DEVELOPMENT_CONTEXT.md         # Этот файл (КАК это сделано)
└── mindpalace/                    # Исходники
    ├── mindpalaceApp.swift        # Entry point
    ├── ContentView.swift          # Main TabView
    ├── Models/                    # SwiftData модели
    │   ├── GitHubRepository.swift
    │   ├── MarkdownFile.swift
    │   ├── MarkdownSection.swift
    │   ├── RepetitionRecord.swift
    │   └── UserSettings.swift
    ├── Services/
    │   ├── GitHub/
    │   │   ├── GitHubService.swift       # REST API клиент
    │   │   └── GitHubModels.swift        # DTO модели
    │   └── Markdown/
    │       ├── MarkdownParser.swift      # Парсинг на секции
    │       └── GitHubImageProvider.swift # Загрузка картинок
    ├── Core/
    │   ├── RepetitionEngine.swift        # Алгоритм повторения
    │   └── SyncManager.swift             # Синхронизация с GitHub
    ├── Views/
    │   ├── Study/
    │   │   ├── StudyView.swift           # Главный экран повторения
    │   │   ├── SectionCardView.swift     # Карточка секции
    │   │   └── FullDocumentView.swift    # Просмотр полного файла
    │   ├── Repositories/
    │   │   ├── RepositoriesView.swift    # Список репо
    │   │   └── AddRepositoryView.swift   # Добавление репо
    │   ├── Statistics/
    │   │   └── StatisticsView.swift      # Статистика
    │   └── Settings/
    │       └── SettingsView.swift        # Настройки + GitHub токен
    ├── ViewModels/
    │   └── StudyViewModel.swift
    └── Utilities/
        ├── Constants.swift
        └── Extensions/
```

### Технологический стек
- **Language**: Swift 5.9+
- **Framework**: SwiftUI
- **Database**: SwiftData (Core Data обертка)
- **Networking**: URLSession + async/await
- **Markdown**: MarkdownUI 2.4.1
- **Security**: KeychainAccess 4.2.2
- **Min iOS**: 17.0+

## 🔑 Ключевые концепции

### 1. SwiftData модели

#### GitHubRepository
```swift
@Model
final class GitHubRepository {
    var id: UUID
    var name: String            // Имя репо
    var owner: String           // Владелец
    var url: String            // URL репозитория
    var isPrivate: Bool        // Публичный/приватный
    var defaultBranch: String  // main/master/etc
    var lastSync: Date?        // Последняя синхронизация

    @Relationship var files: [MarkdownFile]
}
```

#### MarkdownFile
```swift
@Model
final class MarkdownFile {
    var id: UUID
    var path: String           // Путь в репо (e.g., "docs/README.md")
    var fileName: String
    var content: String?       // Полный контент файла
    var sha: String?          // Git SHA для отслеживания изменений

    var repository: GitHubRepository?
    @Relationship var sections: [MarkdownSection]
}
```

#### MarkdownSection
```swift
@Model
final class MarkdownSection {
    var id: UUID
    var title: String          // Заголовок секции
    var content: String        // Контент секции
    var level: Int            // Уровень заголовка (H1=1, H2=2...)
    var lineStart: Int
    var lineEnd: Int
    var orderIndex: Int       // Порядок в файле

    var file: MarkdownFile?
    @Relationship var repetitionRecords: [RepetitionRecord]
}
```

#### RepetitionRecord
```swift
@Model
final class RepetitionRecord {
    var id: UUID
    var reviewedAt: Date      // Когда повторена
    var ease: Double          // Для будущего SM-2
    var quality: Int          // Оценка 0-5

    var section: MarkdownSection?
}
```

### 2. GitHub интеграция

#### Аутентификация
- **Personal Access Token** сохраняется глобально в `UserSettings`
- Хранится в SwiftData (можно перенести в Keychain)
- Используется для всех запросов к GitHub API

#### GitHubService (actor)
```swift
actor GitHubService {
    // Получить инфо о репозитории
    func getRepository(owner: String, name: String)
        async throws -> GitHubRepositoryResponse

    // Список всех .md файлов рекурсивно
    func listMarkdownFiles(owner: String, repo: String, path: String)
        async throws -> [GitHubContent]

    // Скачать raw содержимое файла
    func downloadFileContent(owner: String, repo: String, path: String, ref: String)
        async throws -> String
}
```

**Важно**:
- Использует GitHub REST API v3
- Rate limit: 5000 req/hour (с токеном), 60 req/hour (без)
- Raw файлы: `https://raw.githubusercontent.com/owner/repo/branch/path`

### 3. Markdown парсинг

#### MarkdownParser
```swift
class MarkdownParser {
    func parse(content: String) -> [ParsedSection]
}
```

**Логика**:
1. Разбивает контент построчно
2. Ищет ATX-style заголовки (`# Title`, `## Title`)
3. Группирует контент между заголовками
4. Возвращает массив `ParsedSection`

**Пример**:
```markdown
# Section 1
Content 1

## Section 2
Content 2
```
→ Создаст 2 секции с контентом

### 4. Загрузка изображений

#### GitHubImageProvider
Кастомный `ImageProvider` для MarkdownUI, который:

1. **Определяет тип пути**:
   - Абсолютный URL (`https://...`) → используется как есть
   - Относительный путь → резолвится в GitHub raw URL

2. **Резолвинг относительных путей**:
```swift
// Markdown файл: docs/guide/README.md
// Изображение: ![](images/img.png)
// Результат: https://raw.githubusercontent.com/owner/repo/main/docs/guide/images/img.png

// ./images/img.png  → в той же папке
// ../images/img.png → в родительской папке
// images/img.png    → относительно текущей
// /images/img.png   → от корня репо
```

3. **Использует AsyncImage** для загрузки с индикатором прогресса

### 5. Алгоритм повторения

#### RepetitionEngine
```swift
class RepetitionEngine {
    // Получить следующую секцию для повторения
    func getNextSection() -> MarkdownSection?

    // Отметить как повторенную
    func markAsReviewed(section: MarkdownSection, quality: Int)

    // Статистика
    func getStatistics() -> ReviewStatistics
}
```

**Текущий алгоритм**: Simple Round-Robin
- Сортирует секции по `reviewPriority`
- Priority = дни с последнего повторения (или 1000 для новых)
- Самая "старая" секция показывается первой

**Будущее**: SM-2 Spaced Repetition

### 6. Синхронизация

#### SyncManager
```swift
class SyncManager {
    func syncRepository(_ repository: GitHubRepository) async throws
}
```

**Процесс**:
1. Получает info о репо (для defaultBranch)
2. Рекурсивно получает список .md файлов
3. Скачивает содержимое каждого файла
4. Парсит на секции
5. Сохраняет в SwiftData
6. Обновляет `lastSync` timestamp

**Важно**: При повторной синхронизации:
- Существующие файлы обновляются
- Старые секции удаляются и создаются заново
- История повторений теряется (TODO: сопоставление по title)

## 🎨 UI/UX паттерны

### TabView структура
```
┌─────────────────────────────┐
│         TabView             │
├─────────────────────────────┤
│ Study      (brain icon)     │  ← Главный экран
│ Repositories (folder icon)  │
│ Statistics  (chart icon)    │
│ Settings    (gear icon)     │
└─────────────────────────────┘
```

### StudyView
- Показывает карточку с одной секцией
- Кнопка "Got it" → следующая секция
- Кнопка документа → открывает полный файл
- Счетчик повторений сверху

### FullDocumentView
- **LazyVStack** для производительности
- Секции с pinned headers
- Каждая секция рендерится только при скролле
- Использует тот же `GitHubImageProvider`

## 🔧 Как работают ключевые фичи

### Добавление репозитория
```
1. User вводит URL → AddRepositoryView
2. Парсится owner/name из URL
3. GitHubService.getRepository() → получает инфо + defaultBranch
4. Создается GitHubRepository → сохраняется в SwiftData
5. User нажимает sync → SyncManager.syncRepository()
6. Файлы и секции появляются в базе
```

### Повторение секции
```
1. StudyView показывает карточку
2. RepetitionEngine.getNextSection() → возвращает секцию с highest priority
3. GitHubImageProvider резолвит картинки
4. User нажимает "Got it"
5. RepetitionEngine.markAsReviewed() → создает RepetitionRecord
6. Загружается следующая секция
```

### Загрузка изображения
```
1. Markdown: ![](images/pic.png)
2. MarkdownUI парсит → вызывает GitHubImageProvider
3. Provider получает:
   - repository.owner = "antonovdmitriy"
   - repository.name = "it-notes"
   - repository.defaultBranch = "main"
   - filePath = "docs/guide.md"
   - imagePath = "images/pic.png"
4. Резолвит в: raw.githubusercontent.com/antonovdmitriy/it-notes/main/docs/images/pic.png
5. AsyncImage загружает и показывает
```

## 🐛 Известные особенности

### SwiftData миграции
При изменении моделей SwiftData требуется:
1. Удалить приложение с симулятора
2. Clean Build Folder (⇧⌘K)
3. Пересобрать проект

### GitHub Rate Limits
- Без токена: 60 req/hour
- С токеном: 5000 req/hour
- При превышении: `rateLimitExceeded` error с временем reset

### Картинки и ветки
- defaultBranch сохраняется при добавлении репо
- Если репо уже добавлен БЕЗ defaultBranch → нужно пересоздать
- Картинки не работают если ветка неправильная

## 📝 TODO список (приоритетный)

### High Priority
1. **GitHub Gist синхронизация**
   - Сохранение RepetitionRecords в Gist
   - Синхронизация между устройствами
   - Conflict resolution (last-write-wins)

2. **Улучшение алгоритма**
   - Implement SM-2 spaced repetition
   - Difficulty rating для секций

3. **UI улучшения**
   - Поиск по секциям
   - Фильтры по репозиториям
   - Закладки

### Medium Priority
4. **macOS версия**
   - Shared code уже готов
   - Нужна адаптация UI (Sidebar вместо TabView)

5. **Offline mode**
   - Кэширование изображений
   - Background sync

6. **Better markdown**
   - Syntax highlighting для кода (Splash)
   - Styled tables

### Low Priority
7. **Analytics**
   - Графики прогресса
   - Heatmap повторений

8. **Export/Import**
   - JSON export прогресса
   - Backup/restore

## 🚀 Как продолжить разработку

### Setup окружения
```bash
cd /Users/Dimaantonov/CODE/mindpalaceapp/mindpalace
open mindpalace.xcodeproj
```

### Запуск
1. Выбрать симулятор iPhone (iOS 17+)
2. ⌘R для запуска
3. Если ошибки компиляции → Clean Build Folder (⇧⌘K)

### Тестирование
Используется реальный репозиторий: `antonovdmitriy/it-notes`
- 39 markdown файлов
- ~2200 секций
- Публичный, но лучше использовать токен

### Коммиты
Git репозиторий: `/Users/Dimaantonov/CODE/mindpalaceapp/mindpalace/.git`
```bash
git status
git add .
git commit -m "Your message"
```

## 🔗 Полезные ссылки

### Документация
- [GitHub REST API](https://docs.github.com/en/rest)
- [SwiftData](https://developer.apple.com/documentation/swiftdata)
- [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui)

### Проект
- Основной план: `PROJECT_PLAN.md` (из первого каталога)
- Текущий статус: `PROJECT_STATUS.md`
- Тестовый репо: https://github.com/antonovdmitriy/it-notes

## 💡 Архитектурные решения

### Почему SwiftData а не Core Data?
- Современный API от Apple
- Меньше boilerplate кода
- Лучше интеграция с SwiftUI

### Почему Actor для GitHubService?
- Thread-safety для сетевых запросов
- Встроенная сериализация
- Избегаем data races

### Почему Round-Robin вместо SM-2?
- Проще для MVP
- Работает "из коробки"
- SM-2 можно добавить позже без изменения архитектуры

### Почему нет Gist sync пока?
- MVP сначала с локальным хранением
- Gist sync добавится в v2
- Архитектура готова (SyncData protocol в RepetitionRecord)

## 🎓 Lessons Learned

1. **SwiftData изменения моделей** = требуют пересоздания базы
2. **MarkdownUI не имеет встроенной network image загрузки** → нужен custom provider
3. **GitHub raw URLs требуют правильной ветки** → храним defaultBranch
4. **Большие markdown файлы** → нужен LazyVStack
5. **Rate limits** → обязательно показывать пользователю токен UI

---

**Последнее обновление**: 2025-12-07 23:15
**Версия**: 0.3.0
**Статус**: Fully functional MVP ✅
