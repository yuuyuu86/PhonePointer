import SwiftUI

@main
struct PhonePointerApp: App {
    @StateObject private var connection: ConnectionManager
    @StateObject private var settings: Settings
    @StateObject private var motion: MotionController

    init() {
        let c = ConnectionManager()
        let s = Settings()
        _connection = StateObject(wrappedValue: c)
        _settings = StateObject(wrappedValue: s)
        _motion = StateObject(wrappedValue: MotionController(connection: c, settings: s))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connection)
                .environmentObject(settings)
                .environmentObject(motion)
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                    connection.startBrowsing()
                    motion.start()
                }
        }
    }
}
