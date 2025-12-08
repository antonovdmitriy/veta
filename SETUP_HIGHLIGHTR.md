# Простая инструкция по добавлению подсветки синтаксиса

## Что нужно сделать в Xcode

### Шаг 1: Откройте проект

1. Откройте Xcode
2. Откройте файл: `/Users/Dimaantonov/CODE/mindpalaceapp/mindpalace/mindpalace.xcodeproj`

### Шаг 2: Добавьте библиотеку Highlightr

1. В Xcode выберите ваш проект в левом меню (синяя иконка "mindpalace")
2. Выберите target "mindpalace"
3. Перейдите на вкладку **"Package Dependencies"** (или "Swift Packages")
4. Нажмите кнопку **"+"** внизу
5. Вставьте URL: `https://github.com/raspu/Highlightr`
6. Нажмите **"Add Package"**
7. В следующем окне убедитесь, что выбран **"Highlightr"**
8. Нажмите **"Add Package"**

### Шаг 3: Добавьте файлы в проект

Файлы уже созданы, но нужно добавить их в Xcode:

1. В Xcode, в левом меню найдите папку `mindpalace/Utilities`
2. Правой кнопкой мыши на `Utilities` → **"Add Files to mindpalace"**
3. Выберите оба файла:
   - `CodeSyntaxHighlighter.swift`
   - `MarkdownCodeBlockStyle.swift`
4. Убедитесь, что стоит галочка **"Copy items if needed"** и **"Add to targets: mindpalace"**
5. Нажмите **"Add"**

### Шаг 4: Соберите проект

1. Нажмите **Cmd+B** (или Product → Build)
2. Подождите, пока Xcode скачает и соберет зависимости
3. Если появятся ошибки, следуйте разделу "Решение проблем" ниже

### Шаг 5: Запустите приложение

1. Выберите симулятор или устройство
2. Нажмите **Cmd+R** (или Product → Run)
3. Откройте любой markdown файл с кодом - код должен быть цветным!

---

## Альтернативный способ (если первый не работает)

### Через меню Xcode:

1. **File** → **Add Package Dependencies...**
2. Вставьте: `https://github.com/raspu/Highlightr`
3. Выберите **"Up to Next Major Version"** → **"2.1.2"**
4. Нажмите **"Add Package"**

---

## Решение проблем

### Ошибка: "No such module 'Highlightr'"

**Решение 1:**
1. В Xcode: **File** → **Packages** → **Reset Package Caches**
2. Затем: **File** → **Packages** → **Resolve Package Versions**
3. Пересоберите проект (Cmd+B)

**Решение 2:**
1. Закройте Xcode
2. Удалите папку `DerivedData`:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
3. Откройте проект снова и пересоберите

### Файлы не компилируются

Убедитесь, что файлы добавлены в target:
1. Выберите файл `CodeSyntaxHighlighter.swift` в Xcode
2. В правой панели **"File Inspector"** → **"Target Membership"**
3. Поставьте галочку напротив **"mindpalace"**
4. Повторите для `MarkdownCodeBlockStyle.swift`

### Подсветка все равно не работает

1. Проверьте, что изменения применились в `SectionCardView.swift`
2. Откройте файл и найдите строку с `.markdownBlockStyle`
3. Она должна быть там, где код рендерится

---

## Проверка результата

После запуска приложения:

1. Добавьте репозиторий с markdown файлами
2. Откройте файл с блоком кода, например:

\`\`\`markdown
```swift
struct Test {
    let name: String
}
```
\`\`\`

3. Вы должны увидеть:
   - Заголовок "SWIFT" вверху блока кода
   - Ключевые слова `struct` и `let` раскрашены в **розовый/магента**
   - `String` раскрашен в **бирюзовый**
   - Темный фон блока кода

---

## Если совсем ничего не работает

Напишите скриншот ошибки или вывод консоли, и я помогу!

Также можете проверить, что файлы существуют:
```bash
ls -la /Users/Dimaantonov/CODE/mindpalaceapp/mindpalace/mindpalace/Utilities/
```

Должны быть:
- CodeSyntaxHighlighter.swift
- MarkdownCodeBlockStyle.swift
