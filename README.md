# Ostrovok — «островок» (Dynamic Island) для macOS

Превращает чёлку MacBook (или центр верхней кромки любого экрана) в
интерактивный «островок» в духе Dynamic Island.

Написан с нуля по мотивам разобранных open-source проектов: ядро повторяет
проверенные паттерны **islet** и **DynamicNotchKit** (MIT), а UX-идеи —
**BoringNotch** / **Atoll** (GPL, только как референс, без копирования кода).

## Стек

- **Swift 5.9+ / SwiftUI** (UI и анимации) + **AppKit** (`NSPanel`, CoreAudio, IOKit).
- Без внешних зависимостей. **macOS 14+**.
- Сборка через **SwiftPM** (Xcode не обязателен, достаточно Command Line Tools).

## Запуск

```sh
./build-app.sh           # соберёт build/Ostrovok.app (release)
open build/Ostrovok.app
```

Или просто `swift build && swift run` (без `.app`-обвязки и подписи).

> Для сохранения разрешений (автоматизация для AppleScript, Accessibility при
> надобности) соберите с Developer ID — см. `OSTROVOK_SIGN_IDENTITY` в `build-app.sh`.

## Поведение

- **По умолчанию островок скрыт**, пока не наведёшь курсор на чёлку (или на
  верх-центр экрана без чёлки). Навёл — появляется «пилюля», через мгновение
  раскрывается. Отключается в настройках («Hide island until hover»).
- Управляется из **шестерёнки в островке** или из **иконки в меню-баре**
  (Settings…).

## Функции

Реализованы:
- **Now Playing** — управление Spotify / Apple Music: play/pause, трек, шаффл,
  перемотка, обложка, прогресс (AppleScript; MediaRemote закрыт с macOS 15.4).
- **Clipboard** — история буфера обмена (текст), клик — копировать обратно.
- **Battery** — процент/зарядка через IOKit.
- **HUD громкости/яркости** — замена системного HUD (CoreAudio + приватный `DisplayServices`).
- **Timer** — помодоро-таймер.
- **Shelf** — полка для файлов: перетащи файл в островок, забери обратно в другое приложение или покажи в Finder.

## Настройки

Окно настроек (шестерёнка в островке или меню-бар) позволяет:

- **Language** — русский / English / 中文 (по умолчанию английский).
- **Features** — включать/выключать табы.
- **Behavior** — «Hide island until hover», «Expand on hover», HUD, перехват медиа-клавиш, автозапуск.
- **Displays** — показывать на экране с чёлкой / имитировать на внешних.
- **Sizes** — ширина/высота развёрнутого островка, ширина «ушек», высота пилюли.

## Архитектура

```
Sources/Ostrovok/
  main.swift                  точка входа (menu-bar-only, LSUIElement)
  AppDelegate.swift           сборка AppModel + DisplayManager + статус-иконка
  App/
    Feature.swift             протокол фичи (плаг-ин-таб)
    AppModel.swift            корень: все фичи + сервисы + порядок табов
    Settings.swift            настройки (UserDefaults)
    Localization.swift        локализация (en/ru/zh)
    SettingsView.swift        окно настроек (SwiftUI)
    SettingsWindowController.swift хост NSWindow
    StatusItemController.swift меню в статус-баре
  Core/
    IslandGeometry.swift      измерение чёлки + геометрия окна
    IslandWindow.swift        NSPanel поверх меню-бара + PassthroughView
    IslandState.swift         состояние островка (collapsed/expanded/hud) + размеры
    IslandController.swift    hover + click-through на один экран
    DisplayManager.swift      по одному островку на экран + общий таймер мыши
    SystemHUDMonitor.swift    громкость (CoreAudio) + яркость (DisplayServices)
    AudioVolume.swift         громкость: чтение/запись (CoreAudio)
    DisplayBrightness.swift   яркость: чтение/запись (DisplayServices)
    MediaKeyTap.swift         event tap медиа-клавиш
    MediaKeyController.swift  применяет громкость/яркость + скрытие нативного HUD
    LoginItem.swift           автозапуск (SMAppService)
  UI/
    NotchShape.swift          squircle + вогнутые «крылья»
    IslandView.swift          корневая вью: compact / expanded / HUD + таб-бар
  Features/
    NowPlaying/  …            медиа
    Clipboard/   …            буфер обмена
    Battery/     …            батарея
    Timer/       …            таймер
    Shelf/       …            полка для файлов (drag & drop)
```

### Ключевые приёмы (что переиспользовано)

- **Определение чёлки**: `NSScreen.auxiliaryTopLeftArea/RightArea` + `safeAreaInsets.top`.
- **Окно**: `NSPanel` `.borderless + .nonactivatingPanel`, `level = .mainMenu + 3`,
  `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`,
  `canBecomeKey = false`.
- **Клик сквозь**: `PassthroughView.hitTest` возвращает `nil` вне островка +
  переключение `window.ignoresMouseEvents` по позиции курсора (таймер 30 Гц).
- **Скрытие до наведения**: островок рисуется с `opacity: 0`, пока не hover;
  детект остаётся по позиции курсора, поэтому «невидимость» не ломает появление.
- **Форма**: `RoundedRectangle(style: .continuous)` + `CGPath.union` с «крыльями».
- **Медиа**: AppleScript (сериализован на отдельной очереди) + `DistributedNotificationCenter`.

## Как добавить свою фичу

1. Создай `final class MyFeature: ObservableObject, Feature`
   (см. `Features/Battery/BatteryMonitor.swift`).
2. Реализуй `expandedView`.
3. Зарегистрируй в `AppModel` (массив `features` + `featureIDs`).

## Roadmap до релиза

- [x] Иконка приложения (`.icns`).
- [x] Окно настроек, скрытие до наведения, настраиваемые размеры, локализация.
- [x] Автозапуск (`SMAppService`) и автообновления (Sparkle).
- [x] Полный HUD: event tap для скрытия нативного HUD.
- [x] Арт-палитра из обложки.

## Обновления (Sparkle)

Sparkle встроен (SPM) и добавлен пункт «Check for Updates…» в меню-бар. Чтобы
обновления реально заработали, нужно:

1. Сгенерировать ключи EdDSA (`Sparkle/bin/generate_keys`) и добавить
   `SUPublicEDKey` в `Resources/Info.plist`.
2. Сгенерировать appcast (`generate_appcast`) и выложить его по адресу из
   `SUFeedURL` в `Info.plist` (сейчас там плейсхолдер GitHub Releases).
3. Подписывать релизы Developer ID — без подписи Sparkle не проверит обновление.

## Лицензия

[MIT](LICENSE).
