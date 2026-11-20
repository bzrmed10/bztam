import AppIntents
import SwiftUI
import WidgetKit

// Same tokens as the app (Theme), light and dark.
private extension Color {
    static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
    static let ink = dyn(0x14290B, 0xE9F2E3)
    static let muted = dyn(0x586452, 0x9DAA95)
    static let surface = dyn(0xEEF2EA, 0x1D261A)
    static let canvas = dyn(0xFFFFFF, 0x0F140D)
    static let lime = Color(UIColor(hex: 0xA6E36F))
    static let onLime = Color(UIColor(hex: 0x14290B))
    static let negative = dyn(0xB3261E, 0xFF8A80)
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry { SnapshotEntry(date: .now, snapshot: .placeholder) }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .placeholder : (WidgetSnapshot.load() ?? .placeholder)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load())
        // The app reloads widgets when money changes; refresh hourly anyway for the days-left line.
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3600))))
    }
}

struct LeftToSpendView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        if let s = entry.snapshot {
            content(s)
        } else {
            Text("Bztam").font(.headline).foregroundStyle(Color.ink)
        }
    }

    @ViewBuilder
    private func content(_ s: WidgetSnapshot) -> some View {
        switch family {
        case .accessoryInline:
            Text("\(s.leftText) · \(s.leftTitle)").privacySensitive()
        case .accessoryCircular:
            Gauge(value: s.progress) { Image(systemName: "wallet.bifold") }
                .gaugeStyle(.accessoryCircularCapacity)
                .privacySensitive()
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(s.leftTitle).font(.caption2).widgetAccentable()
                Text(s.leftText).font(.system(size: 20, weight: .heavy)).minimumScaleFactor(0.6).privacySensitive()
                Gauge(value: s.progress) { EmptyView() }.gaugeStyle(.accessoryLinearCapacity)
            }
        case .systemMedium:
            HStack(alignment: .top, spacing: 16) {
                summary(s)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(s.categories.prefix(3).enumerated()), id: \.offset) { _, c in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(c.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                Spacer(minLength: 4)
                                Text(c.leftText).font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(c.over ? Color.negative : Color.muted).lineLimit(1).privacySensitive()
                            }
                            bar(c.progress, over: c.over, height: 4)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(Color.ink)
        default:
            summary(s).foregroundStyle(Color.ink)
        }
    }

    private func summary(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "wallet.bifold.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.lime)
                Spacer()
                Button(intent: QuickAddIntent()) {
                    Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(Color.lime, in: Circle())
                        .foregroundStyle(Color.onLime)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(s.addTitle)
            }
            Spacer(minLength: 0)
            Text(s.leftTitle).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.muted)
            Text(s.leftText)
                .font(.system(size: 26, weight: .heavy)).tracking(-0.6)
                .minimumScaleFactor(0.5).lineLimit(1)
                .foregroundStyle(s.negative ? Color.negative : Color.ink)
                .privacySensitive()
            bar(s.progress, over: s.negative, height: 6)
            Text(s.daysLeftText).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.muted)
        }
    }

    private func bar(_ value: Double, over: Bool, height: CGFloat) -> some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.surface)
                Capsule().fill(over ? Color.negative : Color.ink).frame(width: max(0, min(1, value)) * g.size.width)
            }
        }
        .frame(height: height)
    }
}

struct LeftToSpendWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LeftToSpend", provider: SnapshotProvider()) { entry in
            LeftToSpendView(entry: entry)
                .containerBackground(Color.canvas, for: .widget)
                .widgetURL(URL(string: "bztam://home"))
        }
        .configurationDisplayName("Left to spend")
        .description("What's left this month, and your categories.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

/// Control Center, Lock Screen and Action button: one press to add an expense.
struct AddExpenseControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.bzrmed.bztam.add") {
            ControlWidgetButton(action: QuickAddIntent()) {
                Label("Add expense", systemImage: "plus.circle")
            }
        }
        .displayName("Add expense")
        .description("Opens Bztam ready to add an expense.")
    }
}

struct ScanReceiptControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.bzrmed.bztam.scan") {
            ControlWidgetButton(action: QuickScanIntent()) {
                Label("Scan receipt", systemImage: "doc.viewfinder")
            }
        }
        .displayName("Scan receipt")
        .description("Opens Bztam on the receipt scanner.")
    }
}

@main
struct BztamWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LeftToSpendWidget()
        AddExpenseControl()
        ScanReceiptControl()
    }
}
