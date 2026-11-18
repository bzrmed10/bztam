import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home, activity, insights, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: L10n.t("Home")
        case .activity: L10n.t("Activity")
        case .insights: L10n.t("Insights")
        case .settings: L10n.t("Settings")
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .activity: "list.bullet"
        case .insights: "chart.pie"
        case .settings: "slider.horizontal.3"
        }
    }
}

/// What the Add sheet opens with.
struct AddRequest: Identifiable, Equatable {
    let id = UUID()
    var kind: EntryKind = .expense
    var categoryID: UUID?
}

/// The four tabs with the flat Wise-style tab bar, plus the Add sheet and the Undo toast.
struct MainTabView: View {
    @State private var tab: AppTab = AppTab(rawValue: LaunchOptions.startTab ?? "") ?? .home
    @State private var addRequest: AddRequest?
    @State private var undo = UndoCenter()

    var body: some View {
        Group {
            switch tab {
            case .home: HomeView(onAdd: { addRequest = $0 })
            case .activity: ActivityView(onAdd: { addRequest = AddRequest() })
            case .insights: InsightsView()
            case .settings: SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if let message = undo.message {
                    UndoToast(message: message) { undo.performUndo() }
                        .padding(.horizontal, Theme.Space.l)
                        .padding(.bottom, Theme.Space.s)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                BZTabBar(selection: $tab)
            }
            .animation(.snappy, value: undo.message)
        }
        .background(Theme.Colors.canvas)
        .environment(undo)
        .sheet(item: $addRequest) { request in
            AddEntryView(request: request)
                .environment(undo)
        }
        .onAppear {
            if LaunchOptions.openScreen == "add" { addRequest = AddRequest() }
        }
    }
}

/// Flat tab bar: icon in a lime pill when active, label below.
struct BZTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let active = tab == selection
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 18, weight: active ? .semibold : .regular))
                            .frame(width: 56, height: 32)
                            .background(active ? Theme.Colors.brand : Color.clear, in: Capsule())
                        Text(tab.title)
                            .font(.system(size: 12, weight: active ? .bold : .medium))
                    }
                    .foregroundStyle(active ? Theme.Colors.ink : Theme.Colors.inkMuted)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? .isSelected : [])
                .accessibilityIdentifier("tab.\(tab.rawValue)")
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Theme.Colors.canvas)
        .overlay(alignment: .top) { Rectangle().fill(Theme.Colors.line).frame(height: 1) }
    }
}
