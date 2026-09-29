import Foundation

/// UI language. The setting lives in `Settings`; default is `.english`.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english
    case russian
    case chinese

    var id: String { rawValue }

    /// The language name in its own language (for the picker).
    var displayName: String {
        switch self {
        case .english: return "English"
        case .russian: return "Русский"
        case .chinese: return "中文"
        }
    }
}

/// Runtime localization catalog. Small enough to keep inline; switching is
/// instant (no `.strings`/`.lproj` or restart needed).
enum L10n {
    static func text(_ key: String, _ language: AppLanguage) -> String {
        catalog[key]?[language] ?? key
    }

    private static let catalog: [String: [AppLanguage: String]] = [
        // Feature titles
        "feature.nowPlaying": [.english: "Now Playing", .russian: "Сейчас играет", .chinese: "正在播放"],
        "feature.clipboard": [.english: "Clipboard", .russian: "Буфер обмена", .chinese: "剪贴板"],
        "feature.battery": [.english: "Battery", .russian: "Батарея", .chinese: "电池"],
        "feature.timer": [.english: "Timer", .russian: "Таймер", .chinese: "计时器"],
        "feature.shelf": [.english: "Shelf", .russian: "Полка", .chinese: "置物架"],

        // Settings
        "settings.windowTitle": [.english: "Ostrovok Settings", .russian: "Настройки Ostrovok", .chinese: "Ostrovok 设置"],
        "settings.features": [.english: "Features", .russian: "Функции", .chinese: "功能"],
        "settings.behavior": [.english: "Behavior", .russian: "Поведение", .chinese: "行为"],
        "settings.displays": [.english: "Displays", .russian: "Экраны", .chinese: "显示器"],
        "settings.sizes": [.english: "Sizes", .russian: "Размеры", .chinese: "尺寸"],
        "settings.language": [.english: "Language", .russian: "Язык", .chinese: "语言"],
        "settings.about": [.english: "About", .russian: "О приложении", .chinese: "关于"],
        "settings.hideUntilHover": [.english: "Hide island until hover", .russian: "Скрывать островок до наведения", .chinese: "悬停前隐藏灵动岛"],
        "settings.expandOnHover": [.english: "Expand on hover", .russian: "Раскрывать при наведении", .chinese: "悬停时展开"],
        "settings.showHUD": [.english: "Show volume/brightness HUD", .russian: "Показывать HUD громкости/яркости", .chinese: "显示音量/亮度提示"],
        "settings.showOnNotched": [.english: "Show on built-in (notched) display", .russian: "Показывать на экране с чёлкой", .chinese: "在内置（刘海）屏幕上显示"],
        "settings.simulateOnExternal": [.english: "Simulate island on external displays", .russian: "Имитировать островок на внешних экранах", .chinese: "在外接显示器上模拟灵动岛"],
        "settings.expandedWidth": [.english: "Expanded width", .russian: "Ширина развёрнутого", .chinese: "展开宽度"],
        "settings.expandedHeight": [.english: "Expanded height", .russian: "Высота развёрнутого", .chinese: "展开高度"],
        "settings.compactSideWidth": [.english: "Compact side width", .russian: "Ширина «ушек»", .chinese: "紧凑侧宽度"],
        "settings.collapsedHeight": [.english: "Collapsed height", .russian: "Высота пилюли", .chinese: "折叠高度"],
        "settings.aboutText": [
            .english: "MIT license · built from open-source research (islet, DynamicNotchKit — MIT).",
            .russian: "Лицензия MIT · собрано на основе open-source (islet, DynamicNotchKit — MIT).",
            .chinese: "MIT 许可 · 基于开源研究构建（islet、DynamicNotchKit — MIT）。",
        ],

        // Menu
        "menu.settings": [.english: "Settings…", .russian: "Настройки…", .chinese: "设置…"],
        "menu.quit": [.english: "Quit Ostrovok", .russian: "Выйти из Ostrovok", .chinese: "退出 Ostrovok"],

        // HUD
        "hud.sound": [.english: "Sound", .russian: "Звук", .chinese: "声音"],
        "hud.muted": [.english: "Muted", .russian: "Без звука", .chinese: "静音"],
        "hud.display": [.english: "Display", .russian: "Экран", .chinese: "显示"],

        // Now Playing
        "nowplaying.nothing": [.english: "Nothing playing", .russian: "Ничего не играет", .chinese: "未在播放"],
        "nowplaying.automation": [
            .english: "Allow Automation for Ostrovok in System Settings › Privacy › Automation",
            .russian: "Разрешите автоматизацию для Ostrovok: Системные настройки › Конфиденциальность › Автоматизация",
            .chinese: "请在 系统设置 › 隐私 › 自动化 中允许 Ostrovok 自动化",
        ],

        // Clipboard
        "clipboard.clear": [.english: "Clear history", .russian: "Очистить историю", .chinese: "清除历史"],
        "clipboard.empty": [.english: "Nothing copied yet", .russian: "Пока ничего не скопировано", .chinese: "还没有复制内容"],

        // Battery
        "battery.charging": [.english: "Charging", .russian: "Заряжается", .chinese: "充电中"],

        // Shelf
        "shelf.empty": [.english: "Drop files here", .russian: "Перетащите файлы сюда", .chinese: "将文件拖到这里"],
        "shelf.clear": [.english: "Clear", .russian: "Очистить", .chinese: "清除"],

        // Island
        "island.noFeatures": [
            .english: "No features enabled.\nEnable at least one in Settings.",
            .russian: "Нет включённых функций.\nВключите хотя бы одну в настройках.",
            .chinese: "未启用任何功能。\n请在设置中至少启用一个。",
        ],
    ]
}
