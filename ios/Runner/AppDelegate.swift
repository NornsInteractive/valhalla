import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, UIDocumentInteractionControllerDelegate {
  private var documentController: UIDocumentInteractionController?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      FlutterMethodChannel(name: "valhalla/downloads", binaryMessenger: controller.binaryMessenger)
        .setMethodCallHandler { [weak self] call, result in
          guard call.method == "openFile" else {
            result(call.method == "reportProgress" ? false : FlutterMethodNotImplemented)
            return
          }
          guard let self = self,
                let args = call.arguments as? [String: Any], let path = args["path"] as? String,
                FileManager.default.fileExists(atPath: path),
                let view = self.window?.rootViewController?.view else {
            result(FlutterError(code: "DOWNLOAD_FILE_MISSING", message: nil, details: nil))
            return
          }
          let document = UIDocumentInteractionController(url: URL(fileURLWithPath: path))
          document.delegate = self
          self.documentController = document
          let opened = document.presentOptionsMenu(from: view.bounds, in: view, animated: true)
          result(opened ? nil : FlutterError(code: "DOWNLOAD_NO_HANDLER", message: nil, details: nil))
        }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
    return window!.rootViewController!
  }
}
