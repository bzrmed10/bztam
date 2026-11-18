import SwiftData
import SwiftUI

/// Settings: payday, categories and budgets, privacy, about. More arrives in Milestone 4.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsRows: [AppSettings]
    @State private var showPlan = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        let settings = settingsRows.first
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ScreenTitle(text: L10n.t("Settings"))

                    VStack(alignment: .leading, spacing: 0) {
                        Text(L10n.t("Money")).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.Colors.inkMuted)
                        Menu {
                            Picker(L10n.t("Payday"), selection: Binding(
                                get: { settings?.payday ?? 1 },
                                set: { settings?.payday = $0; try? context.save() }
                            )) {
                                ForEach(1...28, id: \.self) { Text("\($0)").tag($0) }
                            }
                        } label: {
                            SettingsRow(symbol: "calendar", title: L10n.t("Payday"),
                                        value: L10n.t("Day %d of the month", settings?.payday ?? 1))
                        }
                        .buttonStyle(.plain)
                        SettingsRow(symbol: "dollarsign.circle", title: L10n.t("Currency"),
                                    value: L10n.t("Moroccan dirham (DH)"), chevron: false)
                        Button { showPlan = true } label: {
                            SettingsRow(symbol: "list.bullet", title: L10n.t("Categories and budgets"),
                                        value: L10n.t("Change how much each category gets"))
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.t("Privacy")).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.Colors.inkMuted)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.t("Your data stays on this iPhone")).font(.system(size: 15, weight: .bold))
                            Text(L10n.t("No account, no bank connection, no ads."))
                                .font(.system(size: 14)).foregroundStyle(Theme.Colors.inkMuted)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text(L10n.t("App")).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.Colors.inkMuted)
                        HStack {
                            Text(L10n.t("About Bztam")).font(.bzBodyStrong)
                            Spacer()
                            Text(L10n.t("Version %@", version)).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.Colors.inkMuted)
                        }
                        .frame(height: 52)
                    }
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.top, Theme.Space.m)
                .foregroundStyle(Theme.Colors.ink)
            }
            .background(Theme.Colors.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showPlan) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        CircleIconButton(symbol: "xmark", label: L10n.t("Close")) {
                            try? context.save()
                            showPlan = false
                        }
                        Spacer()
                    }
                    PlanMonthView(income: settings?.expectedIncome ?? 0)
                }
                .padding(Theme.Space.l)
                .foregroundStyle(Theme.Colors.ink)
                .background(Theme.Colors.canvas)
            }
        }
    }
}

private struct SettingsRow: View {
    let symbol: String
    let title: String
    let value: String
    var chevron = true

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            IconCircle(symbol: symbol, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.bzBodyStrong).foregroundStyle(Theme.Colors.ink)
                Text(value).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
            }
            Spacer()
            if chevron {
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.Colors.inkMuted)
            }
        }
        .frame(height: Theme.Size.row)
        .contentShape(Rectangle())
    }
}
