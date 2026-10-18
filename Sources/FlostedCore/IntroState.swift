import Foundation

/// Whether the introduction has already been shown.
///
/// Deliberately kept out of `Preferences`: that struct is what the user edits
/// in the settings window, and its "Reset" button would otherwise clear this
/// flag too, making the introduction reappear out of nowhere. This is program
/// state, not a setting.
public enum IntroState {
    private static let key = "FlostedIntroSeen"

    public static func hasSeen(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key)
    }
    public static func markSeen(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key)
    }
    public static func reset(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
