// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import MapKit

/// 旅游导图原型：分天路线 + 编号标记 + 相机动画 + 底部时间轴卡片联动。
struct TravelMapView: View {
    let plan: TripPlan
    @State private var camera: MapCameraPosition = .automatic
    @State private var activeDayIndex = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $camera) {
                // 分天路线
                ForEach(plan.days) { day in
                    let isActive = day.index == activeDayIndex
                    MapPolyline(coordinates: day.routeCoordinates)
                        .stroke(
                            day.color.opacity(isActive ? 1 : 0.28),
                            style: StrokeStyle(
                                lineWidth: isActive ? 5 : 3,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                }
                // 编号地点标记
                ForEach(plan.allPlaces) { place in
                    Annotation(place.name, coordinate: place.coordinate) {
                        NumberBadge(order: place.order, color: plan.days[place.dayIndex].color)
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .ignoresSafeArea(edges: .top)

            timelineCard
        }
        .onAppear {
            camera = .rect(boundingRect(for: plan.allPlaces.map { $0.coordinate }))
        }
    }

    // MARK: - 时间轴卡片

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(plan.city) · \(plan.days.count) 天行程")
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                        camera = .rect(boundingRect(for: plan.allPlaces.map { $0.coordinate }))
                    }
                } label: {
                    Label("全览", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                }
            }

            // 天切换
            HStack(spacing: 8) {
                ForEach(plan.days) { day in
                    Button {
                        activeDayIndex = day.index
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                            camera = .rect(boundingRect(for: day.routeCoordinates))
                        }
                    } label: {
                        Text("第 \(day.index + 1) 天")
                            .font(.subheadline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(activeDayIndex == day.index ? day.color : Color(.secondarySystemGroupedBackground))
                            .foregroundStyle(activeDayIndex == day.index ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }

            timeline(for: plan.days[activeDayIndex])
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func timeline(for day: TripDay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(day.places) { place in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(day.color)
                            .frame(width: 24, height: 24)
                        Text("\(place.order)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name)
                            .font(.subheadline)
                        Text("\(place.arriveTime) 到达 · 停留 \(place.stayDuration)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 辅助

    private func boundingRect(for coordinates: [CLLocationCoordinate2D]) -> MKMapRect {
        var rect = MKMapRect.null
        for coordinate in coordinates {
            let point = MKMapPoint(coordinate)
            rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1))
        }
        return rect.insetBy(dx: -rect.width * 0.35, dy: -rect.height * 0.35)
    }
}

// MARK: - 编号标记

struct NumberBadge: View {
    let order: Int
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            Text("\(order)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
        }
    }
}
