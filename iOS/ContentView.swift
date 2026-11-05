import SwiftUI

struct ContentView: View {
    @EnvironmentObject var connection: ConnectionManager

    var body: some View {
        NavigationStack {
            Group {
                if connection.isConnected {
                    ControllerView()
                } else {
                    HostListView()
                }
            }
        }
    }
}

// MARK: - 接続先一覧

struct HostListView: View {
    @EnvironmentObject var connection: ConnectionManager
    @State private var code = ""

    var body: some View {
        List {
            Section {
                if connection.hosts.isEmpty {
                    HStack {
                        ProgressView()
                        Text("同じWi-Fi内のMacを探しています…").foregroundStyle(.secondary)
                    }
                }
                ForEach(connection.hosts, id: \.endpoint) { host in
                    Button {
                        connection.connect(to: host)
                    } label: {
                        Label(ConnectionManager.name(of: host), systemImage: "desktopcomputer")
                    }
                }
            } header: {
                Text("Mac")
            } footer: {
                Text("MacでPhonePointer Macアプリを起動してください。")
            }

            switch connection.state {
            case .connecting(let name):
                Section { HStack { ProgressView(); Text("\(name) に接続中…") } }
            case .failed(let msg):
                Section { Label(msg, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
            default:
                EmptyView()
            }
        }
        .navigationTitle("PhonePointer")
        .toolbar {
            NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
        }
        .alert("ペアリングコード", isPresented: Binding(
            get: { if case .needsCode = connection.state { return true } else { return false } },
            set: { if !$0, case .needsCode = connection.state { connection.disconnect() } }
        )) {
            TextField("4桁のコード", text: $code).keyboardType(.numberPad)
            Button("接続") {
                connection.submitCode(code)
                code = ""
            }
            Button("キャンセル", role: .cancel) { connection.disconnect() }
        } message: {
            Text("Macのメニューバーに表示されているコードを入力してください")
        }
    }
}

// MARK: - 操作画面

struct ControllerView: View {
    @EnvironmentObject var connection: ConnectionManager
    @EnvironmentObject var motion: MotionController

    var body: some View {
        VStack(spacing: 16) {
            ScrollPad()
            HStack(spacing: 12) {
                DragButton()
                VStack(spacing: 12) {
                    Button {
                        motion.recenter()
                    } label: {
                        Label("中心合わせ", systemImage: "scope")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Button {
                        motion.paused.toggle()
                    } label: {
                        Label(motion.paused ? "再開" : "一時停止",
                              systemImage: motion.paused ? "play.fill" : "pause.fill")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(motion.paused ? .orange : nil)
                }
            }
            .frame(height: 150)
        }
        .padding()
        .navigationTitle(connectedName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("切断") { connection.disconnect() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
            }
        }
    }

    private var connectedName: String {
        if case .connected(let n) = connection.state { return n }
        return ""
    }
}

/// 親指を置いてスクロールする領域。短くタップすると左クリック
struct ScrollPad: View {
    @EnvironmentObject var motion: MotionController
    @EnvironmentObject var settings: Settings

    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(motion.thumbDown ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.12))
            .overlay {
                VStack(spacing: 10) {
                    if motion.paused {
                        Image(systemName: "pause.circle").font(.system(size: 48))
                        Text("一時停止中").font(.headline)
                    } else if motion.thumbDown {
                        Image(systemName: motion.scrollLevel > 0 ? "arrow.up" : motion.scrollLevel < 0 ? "arrow.down" : "hand.raised")
                            .font(.system(size: 48))
                        Text(motion.scrollLevel == 0 ? "傾けてスクロール" : "スクロール中")
                            .font(.headline)
                    } else {
                        Image(systemName: "cursorarrow.motionlines").font(.system(size: 48))
                        Text("iPhoneを向けてカーソル移動").font(.headline)
                        Text("右ひねり: 左クリック / 左ひねり: 右クリック\n親指を置いて傾ける: スクロール"
                             + (settings.tapToClick ? "\nタップ: 左クリック" : ""))
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in motion.thumbBegan() }
                    .onEnded { _ in motion.thumbEnded() }
            )
    }
}

/// 押している間ドラッグ
struct DragButton: View {
    @EnvironmentObject var motion: MotionController

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(motion.dragging ? Color.accentColor : Color.accentColor.opacity(0.18))
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: "hand.point.up.left.fill").font(.title)
                    Text(motion.dragging ? "ドラッグ中" : "押してドラッグ").font(.headline)
                }
                .foregroundStyle(motion.dragging ? Color.white : Color.accentColor)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in motion.dragBegan() }
                    .onEnded { _ in motion.dragEnded() }
            )
    }
}
