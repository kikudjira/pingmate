import Foundation
import ServiceManagement

enum SettingsError: LocalizedError {
    case invalid(String)
    case loginItem(Error)

    var errorDescription: String? {
        switch self {
        case .invalid(let message):
            return message
        case .loginItem(let error):
            return "Could not update Login Items: \(error.localizedDescription)"
        }
    }
}

@MainActor
class SettingsStorage: ObservableObject {
    @Published var settings: Settings

    private let defaults = UserDefaults.standard
    private let settingsKey = "PingMateSettings"

    /// The login-item state we last successfully applied, so `save()` only talks to
    /// `SMAppService` when the toggle actually moved.
    private var appliedLoginState: Bool

    init() {
        let loaded = Self.loadSettings()
        settings = loaded
        appliedLoginState = loaded.startAtLogin
    }

    private static func loadSettings() -> Settings {
        guard let data = UserDefaults.standard.data(forKey: "PingMateSettings") else {
            Log.settings.info("No saved settings found, using defaults")
            return Settings()
        }
        do {
            let settings = try JSONDecoder().decode(Settings.self, from: data)
            Log.settings.info("Loaded settings: target=\(settings.pingTarget), interval=\(settings.pingInterval)ms")
            return settings
        } catch {
            Log.settings.error("Failed to decode settings, falling back to defaults: \(error.localizedDescription)")
            return Settings()
        }
    }

    /// Persists the current settings. Throws so the caller can surface the failure
    /// instead of leaving the UI showing a value that was never applied.
    func save() throws {
        let errors = settings.validate()
        if let first = errors.first {
            Log.settings.error("Cannot save invalid settings: \(first.message)")
            throw SettingsError.invalid(first.message)
        }

        persist()

        guard settings.startAtLogin != appliedLoginState else { return }

        do {
            try updateLoginItem(enabled: settings.startAtLogin)
            appliedLoginState = settings.startAtLogin
        } catch {
            // Put the toggle back where reality is, then report.
            settings.startAtLogin = appliedLoginState
            persist()
            Log.settings.error("Failed to update login item: \(error.localizedDescription)")
            throw SettingsError.loginItem(error)
        }
    }

    func reset() throws {
        settings = Settings()
        try save()
        Log.settings.info("Settings reset to defaults")
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: settingsKey)
            Log.settings.info("Settings saved successfully")
        }
    }

    private func updateLoginItem(enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
            Log.settings.info("Registered for login item")
        } else {
            try SMAppService.mainApp.unregister()
            Log.settings.info("Unregistered from login item")
        }
    }
}
