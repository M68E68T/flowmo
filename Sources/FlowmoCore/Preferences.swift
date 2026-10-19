import Foundation

/// Modifier keys usable as the drag trigger. Deliberately limited to modifiers:
/// detection polls the current flags during an active drag session, where a
/// registered hotkey for a letter key would not fire reliably. Polling also
/// needs no Accessibility permission.
public struct ModifierCombo: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let shift = ModifierCombo(rawValue: 1 << 0)
    public static let control = ModifierCombo(rawValue: 1 << 1)
    public static let option = ModifierCombo(rawValue: 1 << 2)
    public static let command = ModifierCombo(rawValue: 1 << 3)
    public static let all: ModifierCombo = [.shift, .control, .option, .command]

    /// Order follows the usual macOS notation ⌃⌥⇧⌘.
    public static let ordered: [(key: ModifierCombo, symbol: String, name: String)] = [
        (.control, "⌃", "modifier.control"), (.option, "⌥", "modifier.option"),
        (.shift, "⇧", "modifier.shift"), (.command, "⌘", "modifier.command")
    ]

    /// Satisfied when every required key is held. Additional keys do not break
    /// it, otherwise the extra tools modifier would cancel the open trigger.
    public func isSatisfied(by pressed: ModifierCombo) -> Bool {
        !isEmpty && isSubset(of: pressed)
    }
    public var symbols: String {
        Self.ordered.filter { contains($0.key) }.map(\.symbol).joined()
    }
}

public struct Preferences: Equatable, Sendable {
    public var openCombo: ModifierCombo
    public var toolsExtra: ModifierCombo
    public var menuOpacity: Double

    public static let opacityRange: ClosedRange<Double> = 0.35...1.0
    public static let `default` = Preferences(
        openCombo: .shift, toolsExtra: .option, menuOpacity: 0.85)

    public init(openCombo: ModifierCombo, toolsExtra: ModifierCombo, menuOpacity: Double) {
        self.openCombo = openCombo
        self.toolsExtra = toolsExtra
        self.menuOpacity = Self.clamp(menuOpacity)
    }
    public static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return opacityRange.upperBound }
        return min(max(value, opacityRange.lowerBound), opacityRange.upperBound)
    }

    public enum Problem: Equatable, Sendable {
        case openComboEmpty, combosOverlap
        /// Key resolved against Bundle.main, which is the app at runtime.
        public var messageKey: String {
            switch self {
            case .openComboEmpty: return "settings.problem.openComboEmpty"
            case .combosOverlap: return "settings.problem.combosOverlap"
            }
        }
    }
    /// nil means the combination is usable.
    public var problem: Problem? {
        if openCombo.isEmpty { return .openComboEmpty }
        if !openCombo.isDisjoint(with: toolsExtra) { return .combosOverlap }
        return nil
    }

    private struct Key {
        let open, tools, menu: String
        static let current = Key(open: "flowmoOpenCombo", tools: "flowmoToolsExtra",
                                 menu: "flowmoMenuOpacity")
        /// Written by 0.4 under the same bundle id, before the name settled on flowmo.
        static let mixedCase = Key(open: "FLowmoOpenCombo", tools: "FLowmoToolsExtra",
                                   menu: "FLowmoMenuOpacity")
        static let previous = Key(open: "FlostedOpenCombo", tools: "FlostedToolsExtra",
                                  menu: "FlostedMenuOpacity")
        /// Only used to carry settings over from the OrbitDrop build. UserDefaults
        /// are tied to the bundle id, so the rename would otherwise lose them.
        static let legacy = Key(open: "OrbitDropOpenCombo", tools: "OrbitDropToolsExtra",
                                menu: "OrbitDropMenuOpacity")
    }
    /// Unreadable or invalid stored values fall back to the defaults so a bad
    /// write can never leave the app without a working trigger. `legacy` is a
    /// parameter so tests can isolate themselves from the real OrbitDrop domain.
    public static func load(from defaults: UserDefaults = .standard,
                            migratingFrom legacy: UserDefaults? =
                                UserDefaults(suiteName: "dev.orbitdrop.prototype"),
                            migratingFromFlosted previous: UserDefaults? =
                                UserDefaults(suiteName: "dev.flosted.prototype")) -> Preferences {
        if let stored = read(from: defaults, keys: .current) { return stored }
        if let migrated = read(from: defaults, keys: .mixedCase) {
            migrated.save(to: defaults)
            return migrated
        }
        // Read old names only for migration; all future writes use flowmo keys.
        if let previous, let migrated = read(from: previous, keys: .previous) {
            migrated.save(to: defaults)
            return migrated
        }
        guard let legacy, let migrated = read(from: legacy, keys: .legacy) else { return .default }
        migrated.save(to: defaults)
        return migrated
    }
    private static func read(from defaults: UserDefaults, keys: Key) -> Preferences? {
        guard defaults.object(forKey: keys.open) != nil else { return nil }
        let candidate = Preferences(
            openCombo: ModifierCombo(rawValue: defaults.integer(forKey: keys.open))
                .intersection(.all),
            toolsExtra: ModifierCombo(rawValue: defaults.integer(forKey: keys.tools))
                .intersection(.all),
            menuOpacity: defaults.object(forKey: keys.menu) as? Double ?? Self.default.menuOpacity)
        return candidate.problem == nil ? candidate : nil
    }
    public func save(to defaults: UserDefaults = .standard) {
        let keys = Key.current
        defaults.set(openCombo.rawValue, forKey: keys.open)
        defaults.set(toolsExtra.rawValue, forKey: keys.tools)
        defaults.set(menuOpacity, forKey: keys.menu)
    }
}
