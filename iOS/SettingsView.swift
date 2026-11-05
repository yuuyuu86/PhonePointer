import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: Settings

    var body: some View {
        Form {
            Section("カーソル") {
                slider("移動の速さ", value: $settings.cursorSpeed, in: 0.2...3, format: "×%.1f")
                slider("手ブレ除去", value: $settings.jitterFilter, in: 0...0.15, format: "%.2f")
            }
            Section {
                slider("必要なひねり角度", value: $settings.twistAngle, in: 10...60, format: "%.0f°")
                Toggle("タップで左クリック", isOn: $settings.tapToClick)
                Toggle("クリック時に振動", isOn: $settings.haptics)
            } header: {
                Text("クリック")
            } footer: {
                Text("角度を小さくするとクリックしやすく、大きくすると誤操作しにくくなります。")
            }
            Section("スクロール") {
                slider("スクロールの速さ", value: $settings.scrollSpeed, in: 0.2...3, format: "×%.1f")
                slider("反応し始める傾き", value: $settings.scrollDeadzone, in: 2...20, format: "%.0f°")
            }
            Section {
                Button("初期設定に戻す", role: .destructive) { settings.resetToDefaults() }
            }
        }
        .navigationTitle("設定")
    }

    private func slider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value.wrappedValue)).foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: value, in: range)
        }
    }
}
