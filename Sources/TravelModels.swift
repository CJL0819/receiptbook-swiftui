// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import MapKit

/// 交通方式
enum Transport: String, Codable {
    case walk, subway, bus, drive, train, flight

    var symbol: String {
        switch self {
        case .walk: return "figure.walk"
        case .subway: return "tram.fill"
        case .bus: return "bus.fill"
        case .drive: return "car.fill"
        case .train: return "train.side.front.car"
        case .flight: return "airplane"
        }
    }
}

/// 地点
struct Place: Identifiable {
    let id = UUID()
    var name: String
    var coordinate: CLLocationCoordinate2D
    var dayIndex: Int
    var order: Int             // 全局顺序（1 起）
    var arriveTime: String     // 展示用（原型阶段简化）
    var stayDuration: String
}

/// 一天行程
struct TripDay: Identifiable {
    let id = UUID()
    var index: Int
    var color: Color
    var places: [Place]

    var routeCoordinates: [CLLocationCoordinate2D] {
        places.map { $0.coordinate }
    }
}

/// 行程
struct TripPlan {
    var city: String
    var days: [TripDay]

    var allPlaces: [Place] {
        days.flatMap { $0.places }
    }

    static let sample = TripPlan(
        city: "北京",
        days: [
            TripDay(index: 0, color: .blue, places: [
                Place(name: "天安门广场", coordinate: .init(latitude: 39.9042, longitude: 116.4074), dayIndex: 0, order: 1, arriveTime: "09:00", stayDuration: "1h"),
                Place(name: "故宫博物院", coordinate: .init(latitude: 39.9163, longitude: 116.3972), dayIndex: 0, order: 2, arriveTime: "10:30", stayDuration: "3h"),
                Place(name: "景山公园", coordinate: .init(latitude: 39.9252, longitude: 116.3906), dayIndex: 0, order: 3, arriveTime: "14:00", stayDuration: "1.5h"),
            ]),
            TripDay(index: 1, color: .purple, places: [
                Place(name: "颐和园", coordinate: .init(latitude: 39.9999, longitude: 116.2755), dayIndex: 1, order: 4, arriveTime: "09:30", stayDuration: "3h"),
                Place(name: "圆明园", coordinate: .init(latitude: 40.0069, longitude: 116.2968), dayIndex: 1, order: 5, arriveTime: "13:30", stayDuration: "2h"),
            ]),
            TripDay(index: 2, color: .orange, places: [
                Place(name: "八达岭长城", coordinate: .init(latitude: 40.3594, longitude: 116.0156), dayIndex: 2, order: 6, arriveTime: "08:00", stayDuration: "5h"),
            ]),
        ]
    )
}
