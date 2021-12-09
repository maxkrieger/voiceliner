import UIKit
import Flutter
import Speech
@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    
  private func receiveTxRequest(call: FlutterMethodCall, result: @escaping FlutterResult) {
      let uri = (call.arguments as! [String:Any])["path"] as! String
      let url = URL(fileURLWithPath: uri)
      guard let myRecognizer = SFSpeechRecognizer() else {
            // A recognizer is not supported for the current locale
          result(FlutterError(code: "FAILED_REC", message: "unsupported locale", details: nil))
            return
         }
         
         if !myRecognizer.isAvailable {
             result(FlutterError(code: "FAILED_REC", message: "unavailable recognizer", details: nil))
            return
         }

         let request = SFSpeechURLRecognitionRequest(url: url)
         myRecognizer.recognitionTask(with: request) { (res, error) in
            guard let res = res else {
               // Recognition failed, so check error for details and handle it
                result(FlutterError(code: "FAILED_REC", message: error.debugDescription, details: nil))
               return
            }

            // Print the speech that has been recognized so far
            if res.isFinal {
                result(String(res.bestTranscription.formattedString))
            }
         }
  }
    private func requestTxPermission(result: @escaping FlutterResult) {
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization({(status)->Void in
                result(Bool(status == SFSpeechRecognizerAuthorizationStatus.authorized))
            })
        case .denied:
            result(Bool(false))
        case .restricted:
            result(Bool(false))
        case .authorized:
            result(Bool(true))
        default:
            result(Bool(true))
        }
    }
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
      let transcribeChannel = FlutterMethodChannel(name: "voiceoutliner.saga.chat/iostx", binaryMessenger: controller.binaryMessenger)
      transcribeChannel.setMethodCallHandler({(call: FlutterMethodCall, result: @escaping FlutterResult)-> Void in
          switch call.method {
          case "transcribe":
              self.receiveTxRequest(call: call, result: result)
          case "requestPermission":
              self.requestTxPermission(result: result)
          default:
              result(FlutterMethodNotImplemented)
          }
      })
      GeneratedPluginRegistrant.register(with: self)
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
