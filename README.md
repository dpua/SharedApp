# LinkShareApp

SwiftUI iOS 17+ приложение с Share Extension для быстрого сохранения YouTube ссылок.

## Функциональность

- **Share Extension без UI** - мгновенно передает YouTube ссылку в основное приложение
- **URL Scheme** - `linkshareapp://share?url=<encoded_youtube_url>`
- **Поддержка форматов YouTube**:
  - `youtube.com/watch?v=...`
  - `youtu.be/...`
  - `youtube.com/shorts/...`
  - `youtube.com/live/...`
  - `m.youtube.com/...`

## Структура проекта

```
LinkShareApp/
├── LinkShareApp/
│   ├── LinkShareAppApp.swift    # Точка входа, обработка URL Scheme
│   ├── ContentView.swift        # Главный UI с историей ссылок
│   ├── Info.plist               # URL Scheme конфигурация
│   └── Assets.xcassets/
├── Shared/
│   ├── ShareViewController.swift # Share Extension (без UI)
│   └── Info.plist                # Extension конфигурация
└── LinkShareApp.xcodeproj/
```

## Настройка проекта в Xcode

### 1. Откройте проект
```bash
open LinkShareApp.xcodeproj
```

### 2. Настройка основного приложения (LinkShareApp target)

1. Выберите target **LinkShareApp**
2. Перейдите на вкладку **Info**
3. Убедитесь, что **URL Types** содержит:
   - **Identifier**: `com.share.LinkShareApp`
   - **URL Schemes**: `linkshareapp`
   - **Role**: `Editor`

4. Перейдите на вкладку **Build Settings**
5. Найдите **Info.plist File** и установите: `LinkShareApp/Info.plist`

### 3. Настройка Share Extension (Shared target)

1. Выберите target **Shared**
2. Перейдите на вкладку **Build Settings**
3. Найдите **Info.plist File** и установите: `Shared/Info.plist`
4. Убедитесь что **PRODUCT_BUNDLE_IDENTIFIER** = `com.share.LinkShareApp.Shared`

### 4. Удаление ссылки на Storyboard (ВАЖНО!)

1. Выберите target **Shared**
2. Перейдите в **Build Phases** > **Copy Bundle Resources**
3. Удалите `MainInterface.storyboard` если он там есть
4. В **Build Settings** найдите все упоминания `MainInterface` и удалите их

### 5. App Groups (опционально, для передачи данных)

Если нужно сохранять данные между Extension и App:

1. Выберите target **LinkShareApp**
2. Перейдите на вкладку **Signing & Capabilities**
3. Нажмите **+ Capability** > **App Groups**
4. Добавьте группу: `group.com.share.LinkShareApp`
5. Повторите для target **Shared**

### 6. Bundle Identifier

Убедитесь в консистентности Bundle ID:
- **LinkShareApp**: `com.share.LinkShareApp`
- **Shared**: `com.share.LinkShareApp.Shared` (должен начинаться с ID основного приложения)

## Как это работает

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ YouTube/Safari  │────>│ Share Extension  │────>│  Main App       │
│ (Share Sheet)   │     │ (No UI)          │     │ (ContentView)   │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                              │                         │
                              │ 1. Получает URL         │
                              │ 2. Проверяет YouTube    │
                              │ 3. Открывает через      │
                              │    URL Scheme           │
                              │                         │
                              └─────────────────────────┘
                                linkshareapp://share?url=...
```

## Тестирование

### На симуляторе:
1. Запустите приложение (Cmd+R)
2. Откройте Safari и перейдите на youtube.com
3. Нажмите кнопку "Поделиться"
4. Выберите "Save to LinkShare"
5. Приложение откроется автоматически с полученной ссылкой

### На устройстве:
1. Установите приложение на устройство
2. Откройте приложение YouTube
3. На любом видео нажмите "Поделиться"
4. Выберите "Save to LinkShare"
5. Ссылка появится в основном приложении

## Возможные проблемы

### Extension не появляется в Share Sheet
- Убедитесь, что Bundle ID Extension начинается с Bundle ID основного приложения
- Перезагрузите устройство/симулятор
- Убедитесь, что основное приложение было запущено хотя бы раз

### URL Scheme не работает
- Проверьте Info.plist основного приложения
- Убедитесь, что CFBundleURLSchemes содержит `linkshareapp`

### Ошибка "MainInterface.storyboard not found"
- Удалите все ссылки на MainInterface.storyboard в Build Phases
- Убедитесь, что в Info.plist Extension используется `NSExtensionPrincipalClass` вместо `NSExtensionMainStoryboard`

## Требования

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
