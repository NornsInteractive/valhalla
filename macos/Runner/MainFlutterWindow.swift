import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 480, height: 400)

    RegisterGeneratedPlugins(registry: flutterViewController)
    FlutterMethodChannel(name: "valhalla/downloads", binaryMessenger: flutterViewController.engine.binaryMessenger)
      .setMethodCallHandler { call, result in
        guard call.method == "openFile" else {
          result(call.method == "reportProgress" ? false : FlutterMethodNotImplemented)
          return
        }
        guard let args = call.arguments as? [String: Any], let path = args["path"] as? String,
              FileManager.default.fileExists(atPath: path) else {
          result(FlutterError(code: "DOWNLOAD_FILE_MISSING", message: nil, details: nil))
          return
        }
        let opened = NSWorkspace.shared.open(URL(fileURLWithPath: path))
        result(opened ? nil : FlutterError(code: "DOWNLOAD_NO_HANDLER", message: nil, details: nil))
      }

    super.awakeFromNib()
  }
}
