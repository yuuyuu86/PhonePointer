import Foundation

/// 感度などの調整値。UserDefaults に保存する
final class Settings: ObservableObject {
    private let d = UserDefaults.standard

    /// カーソル移動量の倍率
    @Published var cursorSpeed: Double { didSet { d.set(cursorSpeed, forKey: "cursorSpeed") } }
    /// クリック判定に必要なひねり角度 (度)。小さいほどクリックしやすい
    @Published var twistAngle: Double { didSet { d.set(twistAngle, forKey: "twistAngle") } }
    /// スクロール速度の倍率
    @Published var scrollSpeed: Double { didSet { d.set(scrollSpeed, forKey: "scrollSpeed") } }
    /// スクロールが始まる傾き (度)。手ブレ防止の不感帯
    @Published var scrollDeadzone: Double { didSet { d.set(scrollDeadzone, forKey: "scrollDeadzone") } }
    /// 手ブレ除去の強さ (rad/s)。これ以下の回転は無視する
    @Published var jitterFilter: Double { didSet { d.set(jitterFilter, forKey: "jitterFilter") } }
    /// 画面タップで左クリック
    @Published var tapToClick: Bool { didSet { d.set(tapToClick, forKey: "tapToClick") } }
    /// クリック時に振動
    @Published var haptics: Bool { didSet { d.set(haptics, forKey: "haptics") } }

    init() {
        d.register(defaults: [
            "cursorSpeed": 1.0,
            "twistAngle": 25.0,
            "scrollSpeed": 1.0,
            "scrollDeadzone": 6.0,
            "jitterFilter": 0.03,
            "tapToClick": true,
            "haptics": true,
        ])
        cursorSpeed = d.double(forKey: "cursorSpeed")
        twistAngle = d.double(forKey: "twistAngle")
        scrollSpeed = d.double(forKey: "scrollSpeed")
        scrollDeadzone = d.double(forKey: "scrollDeadzone")
        jitterFilter = d.double(forKey: "jitterFilter")
        tapToClick = d.bool(forKey: "tapToClick")
        haptics = d.bool(forKey: "haptics")
    }

    func resetToDefaults() {
        cursorSpeed = 1.0
        twistAngle = 25.0
        scrollSpeed = 1.0
        scrollDeadzone = 6.0
        jitterFilter = 0.03
        tapToClick = true
        haptics = true
    }
}
