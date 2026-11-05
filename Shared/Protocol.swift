import Foundation

/// iPhone ⇄ Mac 間の通信プロトコル。改行区切りの JSON を TCP で送る。
enum PP {
    static let serviceType = "_phonepointer._tcp"
}

enum MouseButton: String, Codable {
    case left, right
}

enum PPMessage: Codable, Equatable {
    /// iPhone → Mac: 接続要求。初回は code が必要、承認済み端末は nil で通る。
    case hello(deviceID: String, name: String, code: String?)
    /// Mac → iPhone: 認証結果
    case helloResult(accepted: Bool)
    /// カーソル相対移動 (px)
    case move(dx: Double, dy: Double)
    /// ひねり開始。Mac はこの時点のカーソル位置を記録する(手ブレ補正)
    case twistBegin
    case twistCancel
    /// クリック。atTwistStart=true ならひねり開始時の位置でクリック
    case click(button: MouseButton, atTwistStart: Bool)
    case dragBegin
    case dragEnd
    /// スクロール量 (px)。正 = 上へ
    case scroll(dy: Double)
    /// カーソルを画面中央へ
    case recenter
}

/// 改行区切り JSON のフレーミング
struct LineFramer {
    private var buffer = Data()

    mutating func reset() { buffer.removeAll() }

    mutating func append(_ data: Data) -> [PPMessage] {
        buffer.append(data)
        var out: [PPMessage] = []
        while let idx = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<idx]
            buffer.removeSubrange(buffer.startIndex...idx)
            if let msg = try? JSONDecoder().decode(PPMessage.self, from: line) {
                out.append(msg)
            }
        }
        return out
    }

    static func encode(_ message: PPMessage) -> Data {
        var data = (try? JSONEncoder().encode(message)) ?? Data()
        data.append(0x0A)
        return data
    }
}
