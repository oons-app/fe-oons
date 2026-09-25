import Flutter
import UIKit
import UserNotifications
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static var pushChannel: FlutterMethodChannel?
  private static var pendingToken: String?
  private var privacyOverlay: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
      guard granted else { return }
      DispatchQueue.main.async {
        application.registerForRemoteNotifications()
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(name: "oons/push", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    AppDelegate.pushChannel = channel
    channel.setMethodCallHandler { call, result in
      if call.method == "getToken" {
        result(AppDelegate.pendingToken)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    if let token = AppDelegate.pendingToken {
      channel.invokeMethod("token", arguments: token)
    }
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    hidePrivacyOverlay()
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    // Hide content in the app switcher snapshot.
    showPrivacyOverlay()
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
    AppDelegate.pendingToken = hex
    AppDelegate.pushChannel?.invokeMethod("token", arguments: hex)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  private func windows() -> [UIWindow] {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
  }

  private func showPrivacyOverlay() {
    guard privacyOverlay == nil, let window = windows().first(where: { $0.isKeyWindow }) ?? windows().first else { return }
    let overlay = UIView(frame: window.bounds)
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overlay.backgroundColor = UIColor(red: 0.97, green: 0.95, blue: 0.93, alpha: 1)
    window.addSubview(overlay)
    privacyOverlay = overlay
  }

  private func hidePrivacyOverlay() {
    privacyOverlay?.removeFromSuperview()
    privacyOverlay = nil
  }
}
