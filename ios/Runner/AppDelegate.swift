import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "radius/screen_guard"
  private var methodChannel: FlutterMethodChannel?
  private var privacyOverlay: UIView?
  private var guardEnabled = false

  override func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    NotificationCenter.default.addObserver(
        self,
        selector: #selector(screenshotTaken),
        name: UIApplication.userDidTakeScreenshotNotification,
        object: nil
    )

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

    return super.application(
        application,
        didFinishLaunchingWithOptions: launchOptions
    )
  }

  func didInitializeImplicitFlutterEngine(
      _ engineBridge: FlutterImplicitEngineBridge
  ) {
    GeneratedPluginRegistrant.register(
        with: engineBridge.pluginRegistry
    )

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: channelName) else {
      return
    }

    let channel = FlutterMethodChannel(
        name: channelName,
        binaryMessenger: registrar.messenger()
    )
    methodChannel = channel

    channel.setMethodCallHandler { [weak self] (
        call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) in

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
    methodChannel?.invokeMethod(
        "screenshotTaken",
        arguments: nil
    )
  }

  @objc private func willResignActive() {
    guard guardEnabled,
          let window = self.window else {
      return
    }

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