import AppKit
import CoreGraphics

/// 受け取った操作を CGEvent に変換して OS に送る
final class InputInjector {
    private var twistStart: CGPoint?
    private var dragging = false
    private var lastClick: (time: TimeInterval, point: CGPoint, button: MouseButton, count: Int)?

    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    private var location: CGPoint { CGEvent(source: nil)?.location ?? .zero }

    private func clamp(_ p: CGPoint) -> CGPoint {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        let bounds = ids.map { CGDisplayBounds($0) }
        if bounds.contains(where: { $0.contains(p) }) { return p }
        // 一番近いディスプレイの内側に収める
        guard let nearest = bounds.min(by: { dist(p, $0) < dist(p, $1) }) else { return p }
        return CGPoint(x: min(max(p.x, nearest.minX), nearest.maxX - 1),
                       y: min(max(p.y, nearest.minY), nearest.maxY - 1))
    }

    private func dist(_ p: CGPoint, _ r: CGRect) -> CGFloat {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX)
        let dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return dx * dx + dy * dy
    }

    private func post(_ type: CGEventType, at p: CGPoint, button: CGMouseButton = .left, clickCount: Int = 1) {
        guard let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: button) else { return }
        e.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
        e.post(tap: .cghidEventTap)
    }

    func move(dx: Double, dy: Double) {
        var p = location
        p.x += dx
        p.y += dy
        p = clamp(p)
        post(dragging ? .leftMouseDragged : .mouseMoved, at: p)
    }

    func recenter() {
        let b = CGDisplayBounds(CGMainDisplayID())
        let p = CGPoint(x: b.midX, y: b.midY)
        CGWarpMouseCursorPosition(p)
        post(dragging ? .leftMouseDragged : .mouseMoved, at: p)
    }

    func twistBegin() { twistStart = location }
    func twistCancel() { twistStart = nil }

    func click(_ button: MouseButton, atTwistStart: Bool) {
        var p = location
        if atTwistStart, let s = twistStart {
            p = s
            CGWarpMouseCursorPosition(p)
        }
        twistStart = nil

        // ダブルクリック判定
        let now = ProcessInfo.processInfo.systemUptime
        var count = 1
        if let last = lastClick, last.button == button,
           now - last.time < NSEvent.doubleClickInterval,
           hypot(last.point.x - p.x, last.point.y - p.y) < 8 {
            count = last.count + 1
        }
        lastClick = (now, p, button, count)

        switch button {
        case .left:
            post(.leftMouseDown, at: p, clickCount: count)
            post(.leftMouseUp, at: p, clickCount: count)
        case .right:
            post(.rightMouseDown, at: p, button: .right, clickCount: count)
            post(.rightMouseUp, at: p, button: .right, clickCount: count)
        }
    }

    func dragBegin() {
        guard !dragging else { return }
        dragging = true
        post(.leftMouseDown, at: location)
    }

    func dragEnd() {
        guard dragging else { return }
        dragging = false
        post(.leftMouseUp, at: location)
    }

    func scroll(dy: Double) {
        let amount = Int32(dy.rounded())
        guard amount != 0,
              let e = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: amount, wheel2: 0, wheel3: 0)
        else { return }
        e.post(tap: .cghidEventTap)
    }

    /// 切断時など、押しっぱなしを残さない
    func releaseAll() {
        dragEnd()
        twistStart = nil
    }
}
