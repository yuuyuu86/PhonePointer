import Foundation
import Network
import UIKit

/// Bonjour で Mac を探して接続する
final class ConnectionManager: ObservableObject {
    enum State: Equatable {
        case idle
        case connecting(String)
        case needsCode(String)
        case connected(String)
        case failed(String)
    }

    @Published private(set) var hosts: [NWBrowser.Result] = []
    @Published private(set) var state: State = .idle

    var isConnected: Bool { if case .connected = state { return true } else { return false } }

    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var framer = LineFramer()
    private var pendingCode: String?

    private let lastHostKey = "lastHost"
    private var deviceID: String {
        if let id = UserDefaults.standard.string(forKey: "deviceID") { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "deviceID")
        return id
    }

    static func name(of result: NWBrowser.Result) -> String {
        if case let .service(name, _, _, _) = result.endpoint { return name }
        return "\(result.endpoint)"
    }

    func startBrowsing() {
        guard browser == nil else { return }
        let b = NWBrowser(for: .bonjour(type: PP.serviceType, domain: nil), using: .tcp)
        b.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            self.hosts = results.sorted { Self.name(of: $0) < Self.name(of: $1) }
            self.autoConnectIfPossible()
        }
        b.start(queue: .main)
        browser = b
    }

    private func autoConnectIfPossible() {
        guard state == .idle, let last = UserDefaults.standard.string(forKey: lastHostKey),
              let r = hosts.first(where: { Self.name(of: $0) == last }) else { return }
        connect(to: r)
    }

    func connect(to result: NWBrowser.Result) {
        connection?.cancel()
        let name = Self.name(of: result)
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        let params = NWParameters(tls: nil, tcp: tcp)
        params.includePeerToPeer = true
        let c = NWConnection(to: result.endpoint, using: params)
        connection = c
        framer.reset()
        state = .connecting(name)
        c.stateUpdateHandler = { [weak self, weak c] s in
            guard let self, let c, c === self.connection else { return }
            switch s {
            case .ready:
                self.sendRaw(.hello(deviceID: self.deviceID, name: UIDevice.current.name, code: nil))
            case .failed(let e):
                self.state = .failed(e.localizedDescription)
                self.connection = nil
            case .cancelled:
                if self.state != .idle { self.state = .idle }
                self.connection = nil
            default: break
            }
        }
        c.start(queue: .main)
        receive(on: c, hostName: name)
    }

    func submitCode(_ code: String) {
        sendRaw(.hello(deviceID: deviceID, name: UIDevice.current.name, code: code))
    }

    func disconnect() {
        UserDefaults.standard.removeObject(forKey: lastHostKey)
        state = .idle
        connection?.cancel()
        connection = nil
    }

    /// 操作メッセージ送信(接続済みのときだけ)
    func send(_ msg: PPMessage) {
        guard isConnected else { return }
        sendRaw(msg)
    }

    private func sendRaw(_ msg: PPMessage) {
        connection?.send(content: LineFramer.encode(msg), completion: .idempotent)
    }

    private func receive(on c: NWConnection, hostName: String) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self, c === self.connection else { return }
            if let data {
                for msg in self.framer.append(data) {
                    if case let .helloResult(accepted) = msg {
                        if accepted {
                            self.state = .connected(hostName)
                            UserDefaults.standard.set(hostName, forKey: self.lastHostKey)
                        } else {
                            self.state = .needsCode(hostName)
                        }
                    }
                }
            }
            if isComplete || error != nil {
                c.cancel()
                self.connection = nil
                self.state = .failed("接続が切れました")
                return
            }
            self.receive(on: c, hostName: hostName)
        }
    }
}
