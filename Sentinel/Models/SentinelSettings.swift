import Foundation

struct SentinelSettings: Codable, Equatable {
    var lockHotKey: GlobalHotKey
    var forceQuitHotKey: GlobalHotKey
    var touchIDEnabled: Bool

    static let `default` = SentinelSettings(
        lockHotKey: .defaultLock,
        forceQuitHotKey: .defaultForceQuit,
        touchIDEnabled: false
    )
}

enum SettingsPersistence {
    private static let storageKey = "SentinelSettings.v1"

    static func load() -> SentinelSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(SentinelSettings.self, from: data)
        else {
            return .default
        }

        return settings
    }

    static func save(_ settings: SentinelSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
