import SwiftUI

@main
struct SimpleClaudeMenuBarApp: App {
    @StateObject private var model = UsageModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(nsImage: AppLogo.menuBarImage)
            Text(model.menuBarTitle)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuContent: View {
    @ObservedObject var model: UsageModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ClaudeSpark()
                    .frame(width: 18, height: 18)
                Text("Claude Usage")
                    .font(.headline)
            }

            usageGauge(label: "Session", line: model.snapshot.session)
            usageGauge(label: "Week", line: model.snapshot.week)

            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Text(updatedText)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Text("Refresh every")
                    .font(.caption)
                Picker("", selection: $model.refreshMinutes) {
                    Text("1 min").tag(1)
                    Text("5 min").tag(5)
                    Text("15 min").tag(15)
                    Text("30 min").tag(30)
                }
                .labelsHidden()
                .frame(width: 90)
            }

            HStack {
                Button(model.isRefreshing ? "Refreshing…" : "Refresh now") {
                    Task { await model.refresh() }
                }
                .disabled(model.isRefreshing)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    @ViewBuilder
    private func usageGauge(label: String, line: UsageLine?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let line {
                    Text("\(line.percent)% used")
                        .font(.subheadline.weight(.medium).monospacedDigit())
                        .foregroundStyle(color(for: line.percent))
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            UsageBar(percent: line?.percent ?? 0, tint: color(for: line?.percent ?? 0))
            if let line {
                Text("resets \(line.resetFull)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func color(for percent: Int) -> Color {
        switch percent {
        case ..<70: return .green
        case 70..<90: return .claudeOrange
        default: return .red
        }
    }

    private var updatedText: String {
        guard let updated = model.lastUpdated else { return "Not yet updated" }
        return "Updated \(updated.formatted(date: .omitted, time: .shortened))"
    }
}

/// A simple horizontal usage bar (0–100%).
struct UsageBar: View {
    var percent: Int
    var tint: Color

    var body: some View {
        GeometryReader { geo in
            let fraction = max(0, min(Double(percent), 100)) / 100
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 8)
    }
}
