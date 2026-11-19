import SwiftUI

/// The only settings: language and the page sound.
struct SettingsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appLanguage) private var lang
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(lang.t("Settings", "الإعدادات"))
                .font(.system(size: 22, weight: .regular, design: .serif))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity)
                .padding(.top, 26)

            VStack(alignment: .leading, spacing: 10) {
                Text(lang.t("Language", "اللغة"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.inkSoft)
                HStack(spacing: 10) {
                    ForEach(AppLanguage.allCases) { l in
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            model.setLanguage(l)
                        } label: {
                            Text(l.displayName)
                                .font(.system(.body, design: .serif, weight: lang == l ? .semibold : .regular))
                                .foregroundStyle(lang == l ? Color.white : Palette.ink)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(lang == l ? Palette.mutedTeal : Palette.softBeige.opacity(0.6))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(lang == l ? .isSelected : [])
                    }
                }
                Text(lang.t("Notebooks keep the direction they were created with.", "تحتفظ الدفاتر باتجاه الكتابة الذي أُنشئت به."))
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
            }

            Toggle(isOn: Binding(get: { model.soundEnabled }, set: { model.setSound($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.t("Page sound", "صوت تقليب الورق"))
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(Palette.ink)
                    Text(lang.t("A soft paper sound while turning", "صوت ورق خافت أثناء التقليب"))
                        .font(.caption)
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            .tint(Palette.mutedTeal)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26)
        .background(Palette.ivory.ignoresSafeArea())
        .environment(\.layoutDirection, lang.layoutDirection)
    }
}
