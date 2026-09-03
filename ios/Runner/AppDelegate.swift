import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  private let channelName = "radius/screen_guard"
  private var methodChannel: FlutterMethodChannel?
  // The overlay dropped over the window's contents right before iOS
  // snapshots it for the app switcher. Nothing else on iOS can hide
  // window content on demand like this.
  private var privacyOverlay: UIView?
  private var guardEnabled = false

  override func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Fires the instant a screenshot is taken. There is no way to stop
    // it — this only lets the app react afterwards.
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(screenshotTaken),
        name: UIApplication.userDidTakeScreenshotNotification,
        object: nil
    )
    // App switcher snapshot is captured right as the app resigns
    // active, so the overlay has to go up in that window, not later.
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(willResignActive),
        name: UIApplication.willResignActiveNotification,
        object: nil
    )
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(didBecomeActive),
        name: UIApplication.didBecomeActiveNotification,
        object: nil
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
        name: channelName,
        binaryMessenger: engineBridge.binaryMessenger
    )
    methodChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "enable":
        self?.guardEnabled = true
        result(true)
      case "disable":
        self?.guardEnabled = false
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @objc private func screenshotTaken() {
    methodChannel?.invokeMethod("screenshotTaken", arguments: nil)
  }

  @objc private func willResignActive() {
    guard guardEnabled, let window = self.window else { return }
    let overlay = UIView(frame: window.bounds)
    overlay.backgroundColor = .black
    overlay.tag = 999_888
    window.addSubview(overlay)
    privacyOverlay = overlay
  }

  @objc private func didBecomeActive() {
    privacyOverlay?.removeFromSuperview()
    privacyOverlay = nil
  }
}