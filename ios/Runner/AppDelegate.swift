import Flutter
import UIKit
import Vision
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OddoCameraGuidance")!
    let reminders = FlutterMethodChannel(name: "app.oddo.oddo/diary_reminder",
                                        binaryMessenger: registrar.messenger())
    reminders.setMethodCallHandler { call, result in
      let center = UNUserNotificationCenter.current()
      if call.method == "requestPermission" {
        center.requestAuthorization(options: [.alert, .sound]) { allowed, _ in
          DispatchQueue.main.async { result(allowed) }
        }
      } else if call.method == "configure", let args = call.arguments as? [String: Any],
                let enabled = args["enabled"] as? Bool,
                let hour = args["hour"] as? Int, let minute = args["minute"] as? Int,
                (0...23).contains(hour), (0...59).contains(minute) {
        let id = "oddo_diary_reminder"
        center.removePendingNotificationRequests(withIdentifiers: [id])
        if !enabled {
          center.removeDeliveredNotifications(withIdentifiers: [id])
          result(true)
          return
        }
        center.getNotificationSettings { settings in
          guard settings.authorizationStatus == .authorized ||
                  settings.authorizationStatus == .provisional else {
            DispatchQueue.main.async { result(false) }
            return
          }
          let content = UNMutableNotificationContent()
          content.title = "오늘 이야기를 들려주세요"
          content.body = "탄카츄와 오늘의 마음을 짧게 기록해볼까요?"
          content.sound = .default
          let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: hour, minute: minute), repeats: true)
          center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) { error in
            DispatchQueue.main.async { result(error == nil) }
          }
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    let channel = FlutterMethodChannel(name: "app.oddo.oddo/camera_guidance",
                                      binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "inspect" else { result(FlutterMethodNotImplemented); return }
      guard let path = call.arguments as? String else { result(nil); return }
      DispatchQueue.global(qos: .utility).async {
        let values = Self.inspectCamera(path)
        DispatchQueue.main.async { result(values) }
      }
    }
  }

  private static func inspectCamera(_ path: String) -> [String: Any]? {
    guard let source = UIImage(contentsOfFile: path) else { return nil }
    // Drawing respects EXIF orientation and bounds processing/memory to a thumbnail.
    let scale = min(1, 640 / max(source.size.width, source.size.height))
    let size = CGSize(width: max(1, floor(source.size.width * scale)),
                      height: max(1, floor(source.size.height * scale)))
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
      source.draw(in: CGRect(origin: .zero, size: size))
    }
    guard let cgImage = image.cgImage else { return nil }
    let request = VNDetectFaceRectanglesRequest()
    do { try VNImageRequestHandler(cgImage: cgImage).perform([request]) }
    catch { return nil }
    let face = request.results?.filter { $0.confidence >= 0.4 }.max {
      $0.boundingBox.width < $1.boundingBox.width
    }
    let width = cgImage.width, height = cgImage.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    return pixels.withUnsafeMutableBytes { buffer -> [String: Any]? in
      guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                    bitsPerComponent: 8, bytesPerRow: width * 4,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
                                      CGBitmapInfo.byteOrder32Big.rawValue) else { return nil }
      context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
      let bounds = face?.boundingBox ?? CGRect(x: 0, y: 0, width: 1, height: 1)
      let left = max(0, min(width - 1, Int(bounds.minX * CGFloat(width))))
      let right = max(left + 1, min(width, Int(bounds.maxX * CGFloat(width))))
      let top = max(0, min(height - 1, Int((1 - bounds.maxY) * CGFloat(height))))
      let bottom = max(top + 1, min(height, Int((1 - bounds.minY) * CGFloat(height))))
      let bytes = buffer.bindMemory(to: UInt8.self)
      var luminance = 0.0, count = 0.0
      for y in stride(from: top, to: bottom, by: 4) {
        for x in stride(from: left, to: right, by: 4) {
          let offset = (y * width + x) * 4
          luminance += 0.2126 * Double(bytes[offset]) +
            0.7152 * Double(bytes[offset + 1]) + 0.0722 * Double(bytes[offset + 2])
          count += 1
        }
      }
      return ["brightness": luminance / count,
              "faceWidth": face.map { $0.boundingBox.width as Any } ?? NSNull()]
    }
  }
}
