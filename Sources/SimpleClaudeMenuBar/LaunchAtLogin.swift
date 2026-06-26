import Foundation
import ServiceManagement

/// Wraps `SMAppService.mainApp` so the app can register/unregister itself as a
/// login item. Registration is per-user and survives reinstalls; macOS exposes
/// it in System Settings → General → Login Items.
enum LaunchAtLogin {
    /// Whether the app is currently set to launch at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers or unregisters the app as a login item.
    /// Errors are logged rather than thrown — the toggle reflects the real
    /// status afterwards, so a failed change simply leaves the UI unchanged.
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("LaunchAtLogin: failed to set enabled=\(enabled): \(error)")
        }
    }
}
