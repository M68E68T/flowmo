import AppKit
import ServiceManagement
import FlowmoCore

/// Start at login through the system's own login items (macOS 13+): it shows
/// up in System Settings → General → Login Items and can be switched off there
/// too. Failures are reported, never fatal: without the login item flowmo
/// still works, it just has to be opened by hand.
@MainActor
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Returns an error text for the settings window, or nil on success.
    private static func register(_ enabled: Bool) -> String? {
        guard enabled != isEnabled else { return nil }
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return nil
        } catch {
            NSLog("flowmo login item: %@", error.localizedDescription)
            return error.localizedDescription
        }
    }

    /// Switches it on by itself on the first launch and again after the app
    /// was moved, never after the user turned it off. Skipped for preview
    /// bundles and for a translocated copy, whose path would not survive a
    /// restart; the next launch from Applications catches up.
    static func registerIfNeeded(previewOnly: Bool) {
        let path = Bundle.main.bundlePath
        guard !previewOnly, LoginItemState.canRegister(bundlePath: path),
              LoginItemState.shouldRegister(at: path) else { return }
        if register(true) == nil { LoginItemState.registered(at: path) }
    }

    /// The settings switch: remembers the choice, so an explicit "off" sticks.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> String? {
        let error = register(enabled)
        if error == nil {
            if enabled { LoginItemState.registered(at: Bundle.main.bundlePath) } else { LoginItemState.declined() }
        }
        return error
    }

    /// True when the system started flowmo as a login item rather than the
    /// user opening it. Must be read while the launch event is still current,
    /// that is in applicationWillFinishLaunching.
    static func launchedAsLoginItem() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == AEEventID(kAEOpenApplication) else { return false }
        return event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue
            == OSType(keyAELaunchedAsLogInItem)
    }
}
