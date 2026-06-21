import Flutter
import UIKit
import GoogleSignIn
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // 채널이 해제되지 않도록 강한 참조로 보관.
  private var ocrChannel: FlutterMethodChannel?
  private var screenTimeChannel: FlutterMethodChannel?

  // Apple Vision 온디바이스 한국어 텍스트 인식.
  // observation들을 위→아래(boundingBox.y 내림차순) 순으로 정렬해 줄 단위로 합쳐 반환.
  private func recognizeText(in data: Data, result: @escaping FlutterResult) {
    guard let cgImage = UIImage(data: data)?.cgImage else {
      result(FlutterError(code: "bad_image", message: "이미지를 읽을 수 없어요", details: nil))
      return
    }

    let request = VNRecognizeTextRequest { request, error in
      if let error = error {
        DispatchQueue.main.async {
          result(FlutterError(code: "vision_error", message: error.localizedDescription, details: nil))
        }
        return
      }
      let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
      // Vision 좌표계는 좌하단 원점 → maxY가 큰 줄이 위쪽. 위에서 아래로 정렬.
      let lines = observations
        .sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
        .compactMap { $0.topCandidates(1).first?.string }
      DispatchQueue.main.async {
        result(lines.joined(separator: "\n"))
      }
    }
    request.recognitionLanguages = ["ko-KR"]
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "vision_perform", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  // Google Sign-In URL 콜백 핸들러
  // Google 인증 완료 후 앱으로 돌아올 때 호출됨
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if GIDSignIn.sharedInstance.handle(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Apple Vision OCR MethodChannel 등록. implicit engine에서는 view controller
    // 타이밍에 의존하지 않도록 plugin registrar의 messenger로 붙인다.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ChorokOcr") {
      let channel = FlutterMethodChannel(
        name: "chorok/ocr",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "recognizeText" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard
          let args = call.arguments as? [String: Any],
          let data = args["bytes"] as? FlutterStandardTypedData
        else {
          result(FlutterError(code: "bad_args", message: "이미지 바이트가 없어요", details: nil))
          return
        }
        self?.recognizeText(in: data.data, result: result)
      }
      ocrChannel = channel
    }

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ChorokScreenTime") {
      let channel = FlutterMethodChannel(
        name: "chorok/screen_time",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        guard #available(iOS 16.0, *) else {
          result("unsupported")
          return
        }

        switch call.method {
        case "startDetox":
          guard ScreenTimeDetoxService.shared.isCapabilityEnabled else {
            result("unsupported")
            return
          }
          guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let presenter = scene.windows.first(where: \.isKeyWindow)?.rootViewController?
              .chorokTopViewController()
          else {
            result(
              FlutterError(
                code: "no_presenter",
                message: "디톡스 앱 선택 화면을 열 수 없어요.",
                details: nil
              )
            )
            return
          }
          ScreenTimeDetoxService.shared.start(from: presenter) { startResult in
            switch startResult {
            case .success(let status):
              result(status)
            case .failure(let error):
              result(
                FlutterError(
                  code: "screen_time_error",
                  message: error.localizedDescription,
                  details: nil
                )
              )
            }
          }
        case "stopDetox":
          ScreenTimeDetoxService.shared.stop()
          result(nil)
        case "isDetoxEnabled":
          result(
            ScreenTimeDetoxService.shared.isCapabilityEnabled
              && ScreenTimeDetoxService.shared.isEnabled
          )
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      screenTimeChannel = channel
    }
  }
}
