// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import Foundation
import CoreLocation

/// 获取当前位置并反地理编码为地点名称。
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var isLocating = false

    private let manager = CLLocationManager()
    private var completion: ((String?) -> Void)?

    func requestLocation(completion: @escaping (String?) -> Void) {
        self.completion = completion
        isLocating = true
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            finish(nil)
            return
        }
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            DispatchQueue.main.async {
                let name = placemarks?.first.map { Self.placeName(from: $0) }
                self?.finish(name)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(nil)
    }

    private func finish(_ name: String?) {
        isLocating = false
        completion?(name)
        completion = nil
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
