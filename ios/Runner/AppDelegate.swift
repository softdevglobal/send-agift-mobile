import FBSDKCoreKit
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // The Facebook plugin is registered with the implicit engine, which can be
    // after launch, so start the Facebook SDK here.
    ApplicationDelegate.shared.application(
      application, didFinishLaunchingWithOptions: launchOptions)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FacebookSceneURLs") {
      registrar.addSceneDelegate(FacebookSceneURLs.shared)
    }
  }
}

/// With the UIScene lifecycle, iOS hands URLs that open the app to the scene,
/// not the app delegate. flutter_facebook_auth only listens on the app
/// delegate, so pass the Facebook login callback (fb<app id>://) on to the
/// Facebook SDK here.
final class FacebookSceneURLs: NSObject, FlutterSceneLifeCycleDelegate {
  static let shared = FacebookSceneURLs()

  func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) -> Bool {
    var handled = false
    for context in urlContexts {
      if ApplicationDelegate.shared.application(
        UIApplication.shared,
        open: context.url,
        sourceApplication: context.options.sourceApplication,
        annotation: context.options.annotation
      ) {
        handled = true
      }
    }
    return handled
  }
}
