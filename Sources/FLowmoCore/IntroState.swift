import Foundation

/// Whether the introduction has already been shown.
///
/// Deliberately kept out of `Preferences`: that struct is what the user edits
/// in the settings window, and its "Reset" button would otherwise clear this
/// flag too, making the introduction reappear out of nowhere. This is program
/// state, not a setting.
public enum IntroState {
    private static let key = "FLowmoIntroSeen"

    public static func hasSeen(_ defaults: UserDefaults = .standard,
                               migratingFromFlosted previous: UserDefaults? =
                                   UserDefaults(suiteName: "dev.flosted.prototype")) -> Bool {
        if defaults.object(forKey: key) == nil, let previous,
           previous.object(forKey: "FlostedIntroSeen") != nil {
            defaults.set(previous.bool(forKey: "FlostedIntroSeen"), forKey: key)
        }
        return defaults.bool(forKey: key)
    }
    public static func markSeen(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key)
    }
    public static func reset(_ defaults: UserDefaults = .standard) {
        // Keep an explicit false so migration cannot undo a later reset.
        defaults.set(false, forKey: key)
    }
}
