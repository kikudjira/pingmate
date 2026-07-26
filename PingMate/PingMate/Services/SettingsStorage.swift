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
    private let loginPromptKey = "PingMateDidAskAboutLoginItem"

    /// The login-item state we last successfully applied, so `save()` only talks to
    /// `SMAppService` when the toggle actually moved.
    private var appliedLoginState: Bool

    init() {
        var loaded = Self.loadSettings()

        // The system owns this setting, not us. A login item can be removed in System Settings,
        // survive an app deletion in our own defaults, or fail to register in the first place —
        // and a stored `true` that the system disagrees with used to jam the toggle in both
        // directions: enabling was skipped as already-applied, disabling threw and rolled back.
        let registered = Self.isRegisteredAsLoginItem
        if loaded.startAtLogin != registered {
            Log.settings.info("Login item state disagreed with the system; using the system's \(registered)")
            loaded.startAtLogin = registered
        }

        settings = loaded
        appliedLoginState = registered
        persist()
    }

    private static var isRegisteredAsLoginItem: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Re-reads the system's view before the user can act on ours. `SMAppService` can be changed
    /// from System Settings at any time, with nothing to tell the app about it.
    func syncLoginItemState() {
        let registered = Self.isRegisteredAsLoginItem
        appliedLoginState = registered
        guard settings.startAtLogin != registered else { return }
        Log.settings.info("Login item changed outside the app; now \(registered)")
        settings.startAtLogin = registered
        persist()
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

    /// True until the login-item question has been put to the user once. Asking again after a
    /// "no" would be nagging, and asking after the toggle has been used at all would be noise.
    var shouldAskAboutLoginItem: Bool {
        guard !defaults.bool(forKey: loginPromptKey) else { return false }
        // A login item can already exist from an earlier install: don't ask about a setting
        // that is visibly already on.
        guard !Self.isRegisteredAsLoginItem else {
            markLoginItemAsked()
            return false
        }
        return true
    }

    func markLoginItemAsked() {
        defaults.set(true, forKey: loginPromptKey)
    }

    /// Turns the login item on in response to the first-launch prompt. Returns whether it stuck —
    /// an ad-hoc signed build is exactly the kind that `SMAppService` can refuse.
    @discardableResult
    func enableLoginItemFromPrompt() -> Bool {
        markLoginItemAsked()
        settings.startAtLogin = true
        do {
            try save()
            return true
        } catch {
            Log.settings.error("Login item declined by the system: \(error.localizedDescription)")
            return false
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: settingsKey)
            Log.settings.info("Settings saved successfully")
        }
    }

    private func updateLoginItem(enabled: Bool) throws {
        // Asking for the state it is already in is not a failure. Unregistering an item the
        // system has never heard of throws, which is how a stale `true` used to become a toggle
        // that could not be switched off.
        guard enabled != Self.isRegisteredAsLoginItem else {
            Log.settings.info("Login item already \(enabled ? "registered" : "unregistered")")
            return
        }

        if enabled {
            try SMAppService.mainApp.register()
            Log.settings.info("Registered for login item")
        } else {
            try SMAppService.mainApp.unregister()
            Log.settings.info("Unregistered from login item")
        }
    }
}
