import Foundation
import Network

/// Bonjour で自身を公開し、iPhone からの接続を受ける
final class Server: ObservableObject {
    @Published private(set) var status = "起動中…"
    @Published private(set) var connectedName: String?
    @Published private(set) var pairingCode = Server.newCode()
    @Published var accessibilityGranted = InputInjector.isTrusted

    private var listener: NWListener?
    private var connection: NWConnection?
    private var framer = LineFramer()
    private var authorized = false
    private let injector = InputInjector()

    private let trustedKey = "trustedDevices"
    private var trusted: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: trustedKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: trustedKey) }
    }

    private static func newCode() -> String { String(format: "%04d", Int.random(in: 0...9999)) }

    init() {
        start()
        // アクセシビリティ許可状態をポーリングして表示を更新
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            let t = InputInjector.isTrusted
            if self?.accessibilityGranted != t { self?.accessibilityGranted = t }
        }
    }

    func start() {
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        let params = NWParameters(tls: nil, tcp: tcp)
        params.includePeerToPeer = true
        do {
            let l = try NWListener(using: params)
            l.service = NWListener.Service(name: Host.current().localizedName ?? "Mac", type: PP.serviceType)
            l.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready: self?.status = "iPhoneからの接続を待っています"
                case .failed(let e): self?.status = "エラー: \(e.localizedDescription)"
                default: break
                }
            }
            l.newConnectionHandler = { [weak self] c in self?.accept(c) }
            l.start(queue: .main)
            listener = l
        } catch {
            status = "起動失敗: \(error.localizedDescription)"
        }
    }

    func forgetDevices() {
        trusted = []
        pairingCode = Server.newCode()
        disconnect()
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        connectionClosed()
    }

    private func accept(_ c: NWConnection) {
        connection?.cancel()
        injector.releaseAll()
        connection = c
        authorized = false
        framer.reset()
        c.stateUpdateHandler = { [weak self, weak c] state in
            switch state {
            case .failed, .cancelled:
                if let c, c === self?.connection { self?.connectionClosed() }
            default: break
            }
        }
        c.start(queue: .main)
        receive(on: c)
    }

    private func connectionClosed() {
        injector.releaseAll()
        connectedName = nil
        authorized = false
        status = "iPhoneからの接続を待っています"
    }

    private func receive(on c: NWConnection) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self, c === self.connection else { return }
            if let data {
                for msg in self.framer.append(data) { self.handle(msg, on: c) }
            }
            if isComplete || error != nil {
                c.cancel()
                self.connectionClosed()
                return
            }
            self.receive(on: c)
        }
    }

    private func send(_ msg: PPMessage, on c: NWConnection) {
        c.send(content: LineFramer.encode(msg), completion: .idempotent)
    }

    private func handle(_ msg: PPMessage, on c: NWConnection) {
        if !authorized {
            guard case let .hello(id, name, code) = msg else { return }
            if trusted.contains(id) || code == pairingCode {
                authorized = true
                trusted.insert(id)
                connectedName = name
                status = "\(name) と接続中"
                send(.helloResult(accepted: true), on: c)
            } else {
                status = "\(name) がペアリングを要求しています"
                send(.helloResult(accepted: false), on: c)
            }
            return
        }

        switch msg {
        case let .move(dx, dy): injector.move(dx: dx, dy: dy)
        case .twistBegin: injector.twistBegin()
        case .twistCancel: injector.twistCancel()
        case let .click(button, atStart): injector.click(button, atTwistStart: atStart)
        case .dragBegin: injector.dragBegin()
        case .dragEnd: injector.dragEnd()
        case let .scroll(dy): injector.scroll(dy: dy)
        case .recenter: injector.recenter()
        case .hello, .helloResult: break
        }
    }
}
