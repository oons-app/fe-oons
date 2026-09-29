import Flutter
import UIKit
import UserNotifications
import FirebaseCore
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static var pushChannel: FlutterMethodChannel?
  private static var pendingToken: String?
  private var privacyOverlay: UIView?
  private var alertPlayer: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    configureAlertAudioSession()
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
    let messenger = engineBridge.applicationRegistrar.messenger()

    let push = FlutterMethodChannel(name: "oons/push", binaryMessenger: messenger)
    AppDelegate.pushChannel = push
    push.setMethodCallHandler { call, result in
      if call.method == "getToken" {
        result(AppDelegate.pendingToken)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    if let token = AppDelegate.pendingToken {
      push.invokeMethod("token", arguments: token)
    }

    let sound = FlutterMethodChannel(name: "oons/alert_sound", binaryMessenger: messenger)
    sound.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "unlock":
        self?.prepareBundledAlertSound()
        result(nil)
      case "play":
        self?.playBundledAlertSound()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Show banner + play sound even while the app is foregrounded.
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
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

  private func configureAlertAudioSession() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.ambient, options: [.mixWithOthers])
    try? session.setActive(true, options: [])
  }

  private func prepareBundledAlertSound() {
    configureAlertAudioSession()
    if alertPlayer == nil {
      guard let url = Bundle.main.url(forResource: "oons_alert", withExtension: "wav") else { return }
      alertPlayer = try? AVAudioPlayer(contentsOf: url)
      alertPlayer?.prepareToPlay()
    }
  }

  private func playBundledAlertSound() {
    prepareBundledAlertSound()
    alertPlayer?.currentTime = 0
    alertPlayer?.volume = 0.85
    alertPlayer?.play()
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
