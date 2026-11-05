import SwiftUI

@main
struct PhonePointerMacApp: App {
    @StateObject private var server = Server()

    var body: some Scene {
        MenuBarExtra("PhonePointer", systemImage: server.connectedName == nil ? "iphone.radiowaves.left.and.right" : "cursorarrow.motionlines") {
            MenuView(server: server)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuView: View {
    @ObservedObject var server: Server

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PhonePointer").font(.headline)
            Text(server.status).font(.callout)

            if server.connectedName == nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ペアリングコード").font(.caption).foregroundStyle(.secondary)
                    Text(server.pairingCode)
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                    Text("初回接続時にiPhoneで入力してください").font(.caption).foregroundStyle(.secondary)
                }
            }

            if !server.accessibilityGranted {
                VStack(alignment: .leading, spacing: 6) {
                    Label("カーソル操作にはアクセシビリティの許可が必要です", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Button("許可をリクエスト") { InputInjector.requestAccessibility() }
                }
            }

            Divider()
            HStack {
                if server.connectedName != nil {
                    Button("切断") { server.disconnect() }
                }
                Button("登録端末をリセット") { server.forgetDevices() }
                Spacer()
                Button("終了") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding()
        .frame(width: 300)
    }
}
