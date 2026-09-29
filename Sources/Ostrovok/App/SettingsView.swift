import SwiftUI

struct SettingsView: View {
    @ObservedObject var app: AppModel
    @ObservedObject private var settings: Settings

    init(app: AppModel) {
        self.app = app
        self._settings = ObservedObject(wrappedValue: app.settings)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                languageSection
                featuresSection
                behaviorSection
                displaysSection
                sizesSection
                aboutSection
            }
            .padding(20)
        }
        .frame(width: 440)
    }

    private func t(_ key: String) -> String {
        L10n.text(key, settings.language)
    }

    // MARK: - Language

    private var languageSection: some View {
        SettingsSection(t("settings.language")) {
            Picker(t("settings.language"), selection: $settings.language) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        SettingsSection(t("settings.features")) {
            ForEach(app.features, id: \.id) { feature in
                Toggle(isOn: featureBinding(feature.id)) {
                    Label(L10n.text(feature.titleKey, settings.language), systemImage: feature.symbolName)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }
        }
    }

    private func featureBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { settings.isEnabled(id) },
            set: { app.setFeatureEnabled(id, $0) }
        )
    }

    // MARK: - Behavior

    private var behaviorSection: some View {
        SettingsSection(t("settings.behavior")) {
            Toggle(t("settings.hideUntilHover"), isOn: $settings.hideUntilHover)
            Toggle(t("settings.expandOnHover"), isOn: $settings.expandOnHover)
            Toggle(t("settings.showHUD"), isOn: $settings.showSystemHUD)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    // MARK: - Displays

    private var displaysSection: some View {
        SettingsSection(t("settings.displays")) {
            Toggle(t("settings.showOnNotched"), isOn: $settings.showOnNotchedScreen)
            Toggle(t("settings.simulateOnExternal"), isOn: $settings.simulateOnExternal)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    // MARK: - Sizes

    private var sizesSection: some View {
        SettingsSection(t("settings.sizes")) {
            SliderRow(label: t("settings.expandedWidth"), value: $settings.expandedWidth, range: 280...460, step: 10, unit: "pt")
            SliderRow(label: t("settings.expandedHeight"), value: $settings.expandedContentHeight, range: 150...300, step: 10, unit: "pt")
            SliderRow(label: t("settings.compactSideWidth"), value: $settings.compactSideWidth, range: 20...60, step: 2, unit: "pt")
            SliderRow(label: t("settings.collapsedHeight"), value: $settings.collapsedHeight, range: 26...50, step: 2, unit: "pt")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        SettingsSection(t("settings.about")) {
            Text("Ostrovok 0.1.0")
                .font(.system(size: 13, weight: .semibold))
            Text(t("settings.aboutText"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Helpers

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            VStack(alignment: .leading, spacing: 9) {
                content()
            }
        }
    }
}

private struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).font(.system(size: 12))
                Spacer()
                Text("\(Int(value)) \(unit)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}
