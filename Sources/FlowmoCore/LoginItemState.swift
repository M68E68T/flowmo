import Foundation

/// When flowmo should put itself into the login items on its own.
///
/// Program state, not a setting: kept out of `Preferences` so the settings
/// window's Reset cannot clear it. The system remembers whether the login item
/// is on; this records where flowmo registered it and whether the user turned
/// it off, so it is switched on once per location and never against the user.
public enum LoginItemState {
    private static let pathKey = "flowmoLoginItemPath"
    private static let declinedKey = "flowmoLoginItemDeclined"

    /// First launch, or the app was moved since (Downloads → Applications):
    /// the old entry would point nowhere. Never after the user turned it off.
    public static func shouldRegister(at bundlePath: String, _ defaults: UserDefaults = .standard) -> Bool {
        !defaults.bool(forKey: declinedKey) && defaults.string(forKey: pathKey) != bundlePath
    }
    public static func registered(at bundlePath: String, _ defaults: UserDefaults = .standard) {
        defaults.set(bundlePath, forKey: pathKey)
        defaults.set(false, forKey: declinedKey)
    }
    public static func declined(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: declinedKey)
    }
    /// A quarantined app run from Downloads is moved to a random read-only
    /// path by macOS; a login item pointing there breaks after the next restart.
    public static func canRegister(bundlePath: String) -> Bool {
        !bundlePath.contains("/AppTranslocation/")
    }
}

/// What a launch should put on screen.
public struct LaunchPlan: Equatable {
    public let showsDashboard: Bool
    public let showsIntroduction: Bool

    /// Started by the system at login: stay in the menu bar, nothing pops up.
    /// Started by the user: the dashboard, plus the introduction the first time.
    public static func make(launchedAtLogin: Bool, introSeen: Bool) -> LaunchPlan {
        launchedAtLogin
            ? LaunchPlan(showsDashboard: false, showsIntroduction: false)
            : LaunchPlan(showsDashboard: true, showsIntroduction: !introSeen)
    }
}
