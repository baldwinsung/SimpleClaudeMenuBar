import SwiftUI

@main
struct SimpleClaudeMenuBarApp: App {
    @StateObject private var model = UsageModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Text(model.menuBarTitle)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuContent: View {
    @ObservedObject var model: UsageModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Claude Usage")
                .font(.headline)

            usageRow(label: "Session", line: model.snapshot.session)
            usageRow(label: "Week", line: model.snapshot.week)

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
        .padding(12)
        .frame(width: 280)
    }

    @ViewBuilder
    private func usageRow(label: String, line: UsageLine?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .frame(width: 60, alignment: .leading)
            if let line {
                Text("\(line.percent)% used")
                Spacer()
                Text("resets \(line.resetFull)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("—").foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private var updatedText: String {
        guard let updated = model.lastUpdated else { return "Not yet updated" }
        return "Updated \(updated.formatted(date: .omitted, time: .shortened))"
    }
}
