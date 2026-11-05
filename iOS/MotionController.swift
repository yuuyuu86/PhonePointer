import CoreMotion
import UIKit

/// センサー値を操作(移動・ひねりクリック・傾きスクロール)に変換する。
///
/// 持ち方: 画面を上に向け、iPhone の上端を PC 画面に向ける。
/// - 左右に向ける (重力軸まわりの回転) → カーソル左右
/// - 上下に向ける (端末 x 軸まわりの回転) → カーソル上下
/// - 手首のひねり (端末 y 軸 = 長辺まわりの回転) → クリック
final class MotionController: ObservableObject {
    @Published private(set) var thumbDown = false
    @Published private(set) var dragging = false
    @Published var paused = false
    /// UI 表示用: 現在のスクロール速度 (-1...1 程度)
    @Published private(set) var scrollLevel: Double = 0
    @Published private(set) var lastClick: MouseButton?

    private let motion = CMMotionManager()
    private let connection: ConnectionManager
    private let settings: Settings
    private let hz = 100.0

    // カーソル
    private var residual = CGPoint.zero
    private var smoothed = CGPoint.zero

    // ひねり
    private var twisting = false
    private var twistDir: Double = 0
    private var twistAccum: Double = 0
    private var twistStart: TimeInterval = 0
    private var cooldownUntil: TimeInterval = 0

    // スクロール / タップ
    private var scrollRefPitch: Double?
    private var scrollActivated = false
    private var thumbDownAt: TimeInterval = 0
    private var scrollResidual: Double = 0

    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)

    var isAvailable: Bool { motion.isDeviceMotionAvailable }

    init(connection: ConnectionManager, settings: Settings) {
        self.connection = connection
        self.settings = settings
    }

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1 / hz
        motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] m, _ in
            if let m { self?.process(m) }
        }
    }

    func stop() { motion.stopDeviceMotionUpdates() }

    // MARK: - UI からの入力

    func thumbBegan() {
        guard !thumbDown else { return }
        thumbDown = true
        thumbDownAt = ProcessInfo.processInfo.systemUptime
        scrollRefPitch = nil
        scrollActivated = false
        scrollResidual = 0
        cancelTwist()
    }

    func thumbEnded() {
        guard thumbDown else { return }
        thumbDown = false
        scrollLevel = 0
        let held = ProcessInfo.processInfo.systemUptime - thumbDownAt
        // 傾けずに短く触れただけならタップクリック
        if settings.tapToClick, !scrollActivated, held < 0.25, !paused {
            sendClick(.left, atTwistStart: false)
        }
    }

    func dragBegan() {
        guard !dragging else { return }
        dragging = true
        cancelTwist()
        connection.send(.dragBegin)
        if settings.haptics { lightImpact.impactOccurred() }
    }

    func dragEnded() {
        guard dragging else { return }
        dragging = false
        connection.send(.dragEnd)
    }

    func recenter() {
        smoothed = .zero
        residual = .zero
        cancelTwist()
        connection.send(.recenter)
        if settings.haptics { lightImpact.impactOccurred() }
    }

    // MARK: - センサー処理

    private func process(_ m: CMDeviceMotion) {
        guard connection.isConnected, !paused else { return }
        let dt = 1 / hz
        let now = m.timestamp
        let g = m.gravity
        let gLen = max(sqrt(g.x * g.x + g.y * g.y + g.z * g.z), 0.0001)
        let r = m.rotationRate

        // 親指を置いている間: カーソル固定・ひねり無効・傾きでスクロール
        if thumbDown {
            handleScroll(gravityY: g.y / gLen, dt: dt)
            return
        }

        // ひねりクリック (ドラッグ中は無効)
        if !dragging { handleTwist(rollRate: r.y, now: now, dt: dt) }
        if twisting { return } // ひねり中はカーソルを動かさない

        // カーソル移動
        let yawRate = (r.x * g.x + r.y * g.y + r.z * g.z) / gLen // 重力軸まわり
        let pitchRate = r.x
        var vx = deadzone(yawRate, settings.jitterFilter)
        var vy = deadzone(pitchRate, settings.jitterFilter)

        // 軽い加速カーブ: ゆっくり動かすと精密、速く振ると遠くまで
        let speed = hypot(vx, vy)
        let accel = 1 + min(speed, 4) * 0.6
        let gain = 900 * settings.cursorSpeed * accel * dt
        vx *= gain
        vy *= -gain

        // 平滑化
        smoothed.x = smoothed.x * 0.4 + vx * 0.6
        smoothed.y = smoothed.y * 0.4 + vy * 0.6

        residual.x += smoothed.x
        residual.y += smoothed.y
        let dx = residual.x.rounded(.towardZero)
        let dy = residual.y.rounded(.towardZero)
        if dx != 0 || dy != 0 {
            residual.x -= dx
            residual.y -= dy
            connection.send(.move(dx: dx, dy: dy))
        }
    }

    private func deadzone(_ v: Double, _ dz: Double) -> Double {
        if abs(v) < dz { return 0 }
        return v - dz * (v > 0 ? 1 : -1)
    }

    private func handleTwist(rollRate: Double, now: TimeInterval, dt: Double) {
        let startRate = 2.0     // rad/s: これ以上の速さでひねり始めたら判定開始
        let maxDuration = 0.35  // 秒: この時間内に角度に達しなければキャンセル

        if !twisting {
            guard now >= cooldownUntil, abs(rollRate) > startRate else { return }
            twisting = true
            twistDir = rollRate > 0 ? 1 : -1
            twistAccum = 0
            twistStart = now
            connection.send(.twistBegin)
        }

        twistAccum += rollRate * dt
        let angle = twistAccum * twistDir * 180 / .pi
        if angle >= settings.twistAngle {
            twisting = false
            // 戻す動きで逆クリックしないようクールダウン
            cooldownUntil = now + 0.5
            smoothed = .zero
            residual = .zero
            // 右ひねり (+y) = 左クリック / 左ひねり = 右クリック
            sendClick(twistDir > 0 ? .left : .right, atTwistStart: true)
        } else if now - twistStart > maxDuration || rollRate * twistDir < 0 {
            cancelTwist()
        }
    }

    private func cancelTwist() {
        guard twisting else { return }
        twisting = false
        connection.send(.twistCancel)
    }

    private func sendClick(_ button: MouseButton, atTwistStart: Bool) {
        connection.send(.click(button: button, atTwistStart: atTwistStart))
        lastClick = button
        if settings.haptics { impact.impactOccurred() }
    }

    private func handleScroll(gravityY: Double, dt: Double) {
        // 上端を持ち上げる(手前に傾ける)ほど正
        let pitch = asin(max(-1, min(1, -gravityY))) * 180 / .pi
        guard let ref = scrollRefPitch else { scrollRefPitch = pitch; return }
        let delta = pitch - ref
        let dz = settings.scrollDeadzone
        guard abs(delta) > dz else {
            scrollLevel = 0
            return
        }
        scrollActivated = true
        let over = abs(delta) - dz
        // 傾きが大きいほど速く (2次カーブ)
        let pxPerSec = (over * 25 + over * over * 1.2) * settings.scrollSpeed
        let dir: Double = delta > 0 ? -1 : 1 // 手前 = 下スクロール(負)
        scrollLevel = min(over / 30, 1) * -dir
        scrollResidual += pxPerSec * dt * dir
        let amount = scrollResidual.rounded(.towardZero)
        if amount != 0 {
            scrollResidual -= amount
            connection.send(.scroll(dy: amount))
        }
    }
}
