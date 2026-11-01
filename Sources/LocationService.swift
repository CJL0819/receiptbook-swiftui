// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import Foundation
import CoreLocation

/// 获取当前位置并反地理编码为地点名称。
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var isLocating = false
    /// 失败原因（权限被拒 / 定位失败），由界面弹提示，避免按钮无声卡住。
    @Published var errorMessage: String?

    private let manager = CLLocationManager()
    private var completion: ((String?) -> Void)?
    private var waitingForAuthorization = false

    func requestLocation(completion: @escaping (String?) -> Void) {
        self.completion = completion
        errorMessage = nil
        isLocating = true
        manager.delegate = self

        // 授权还没确定时先申请，等回调到 didChangeAuthorization 再真正请求位置。
        // 直接连发 requestLocation 会因为授权尚未生效而必然失败。
        switch manager.authorizationStatus {
        case .notDetermined:
            waitingForAuthorization = true
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            fail("定位权限未开启。请到「设置 → 隐私与安全性 → 定位服务」里允许「小票收纳」使用定位。")
        default:
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard waitingForAuthorization else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            break
        case .denied, .restricted:
            waitingForAuthorization = false
            fail("定位权限未开启。请到「设置 → 隐私与安全性 → 定位服务」里允许「小票收纳」使用定位。")
        default:
            waitingForAuthorization = false
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            fail("没能获取到当前位置，请稍后重试。")
            return
        }
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if let placemark = placemarks?.first {
                    self.finish(Self.placeName(from: placemark))
                } else {
                    // 定位成功但解析不出地名时退化成经纬度，至少不丢信息
                    let lat = String(format: "%.4f", location.coordinate.latitude)
                    let lon = String(format: "%.4f", location.coordinate.longitude)
                    self.finish("\(lat), \(lon)")
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        fail("定位失败：\(error.localizedDescription)")
    }

    private func fail(_ message: String) {
        errorMessage = message
        finish(nil)
    }

    private func finish(_ name: String?) {
        isLocating = false
        waitingForAuthorization = false
        let callback = completion
        completion = nil
        callback?(name)
    }

    private static func placeName(from placemark: CLPlacemark) -> String {
        if let street = placemark.thoroughfare {
            return [placemark.locality, placemark.subLocality, street]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined()
        }
        return placemark.name ?? placemark.locality ?? placemark.administrativeArea ?? "当前位置"
    }
}
