import Cocoa
import FlutterMacOS
import Security

class MainFlutterWindow: NSWindow {
  private var wake: WindowWake?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    wake = WindowWake(window: self, controller: flutterViewController)

    super.awakeFromNib()
  }
}

/// Tells the app the window may be back without macOS saying so (screen unlocked, Mac woken, display back
/// on, window uncovered): it redraws and recovers its lifecycle (lib/core/platform/frame_recovery.dart).
final class WindowWake {
  private let channel: FlutterMethodChannel
  private weak var window: NSWindow?
  private var observers: [(NotificationCenter, NSObjectProtocol)] = []

  init(window: NSWindow, controller: FlutterViewController) {
    self.window = window
    channel = FlutterMethodChannel(
      name: "paper_agent/window", binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler(DesktopCredentialStore.handle)
    let system = NSWorkspace.shared.notificationCenter
    observe(system, NSWorkspace.screensDidWakeNotification, "display on")
    observe(system, NSWorkspace.didWakeNotification, "resume")
    observe(system, NSWorkspace.sessionDidBecomeActiveNotification, "session connected")
    observe(DistributedNotificationCenter.default(), Notification.Name("com.apple.screenIsUnlocked"), "unlock")
    let app = NotificationCenter.default
    observe(app, NSWindow.didChangeOcclusionStateNotification, "window uncovered", object: window)
    observe(app, NSWindow.didChangeScreenNotification, "display changed", object: window)
    observe(app, NSWindow.didChangeBackingPropertiesNotification, "display changed", object: window)
    observe(app, NSApplication.didChangeScreenParametersNotification, "display changed")
  }

  deinit {
    for (center, token) in observers { center.removeObserver(token) }
  }

  private func observe(
    _ center: NotificationCenter, _ name: Notification.Name, _ reason: String, object: AnyObject? = nil
  ) {
    let token = center.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
      self?.notify(reason)
    }
    observers.append((center, token))
  }

  private func notify(_ reason: String) {
    // A minimised, hidden or covered window is not back: macOS will say so when it is.
    guard let window = window, window.isVisible, !window.isMiniaturized,
      window.occlusionState.contains(.visible) || reason != "window uncovered"
    else { return }
    channel.invokeMethod("visible", arguments: reason)
  }
}

/// The login Keychain, local to this Mac. Stable Developer ID signing preserves access across updates.
enum DesktopCredentialStore {
  static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      execute(call) { value in DispatchQueue.main.async { result(value) } }
    }
  }

  private static func execute(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], let key = args["key"] as? String,
      key.hasPrefix("daylex."), key.count <= 80,
      key.range(of: "^[a-z0-9._-]+$", options: .regularExpression) != nil else {
      result(FlutterError(code: "invalid", message: "Invalid credential name", details: nil)); return
    }
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "it.daylex.desktop", kSecAttrAccount as String: key,
      kSecAttrSynchronizable as String: false]
    if call.method == "readCredential" {
      var read = query
      read[kSecReturnData as String] = true
      read[kSecMatchLimit as String] = kSecMatchLimitOne
      var found: CFTypeRef?
      let status = SecItemCopyMatching(read as CFDictionary, &found)
      if status == errSecItemNotFound { result(nil); return }
      guard status == errSecSuccess, let data = found as? Data, let value = String(data: data, encoding: .utf8) else {
        result(FlutterError(code: "vault", message: "Keychain unavailable", details: status)); return
      }
      result(value)
    } else if call.method == "writeCredential" {
      guard let value = args["value"] as? String, let data = value.data(using: .utf8), data.count <= 2560 else {
        result(FlutterError(code: "invalid", message: "Invalid credential length", details: nil)); return
      }
      var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
      if status == errSecItemNotFound {
        var item = query
        item[kSecValueData as String] = data
        status = SecItemAdd(item as CFDictionary, nil)
      }
      if status == errSecSuccess { result(nil) }
      else { result(FlutterError(code: "vault", message: "Keychain write failed", details: status)) }
    } else if call.method == "deleteCredential" {
      let status = SecItemDelete(query as CFDictionary)
      if status == errSecSuccess || status == errSecItemNotFound { result(nil) }
      else { result(FlutterError(code: "vault", message: "Keychain deletion failed", details: status)) }
    } else { result(FlutterMethodNotImplemented) }
  }
}
