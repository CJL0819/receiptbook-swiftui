// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

/// 类型选择：彩色胶囊，多行平铺。
struct TypeCapsulePicker: View {
    @Binding var selection: ReceiptType

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(ReceiptType.allCases, id: \.self) { type in
                Button {
                    selection = type
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: type.symbolName)
                            .font(.caption)
                        Text(type.displayName)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(selection == type ? type.tintColor : Color(.tertiarySystemFill))
                    .foregroundStyle(selection == type ? .white : .primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 心情选择：彩色胶囊，多行平铺，可点选取消。
struct MoodCapsulePicker: View {
    @Binding var selection: Mood?

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Mood.allCases) { mood in
                let isSelected = (selection == mood)
                Button {
                    selection = isSelected ? nil : mood
                } label: {
                    Text(mood.rawValue)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(isSelected ? mood.color : Color(.tertiarySystemFill))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 地点：定位选择（非手填）+ 具体地址补充。
struct LocationSection: View {
    @Binding var location: String
    @Binding var address: String
    @StateObject private var locator = LocationService()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("地点")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    locator.requestLocation { name in
                        if let name { location = name }
                    }
                } label: {
                    Label(locator.isLocating ? "定位中…" : "使用当前位置",
                          systemImage: locator.isLocating ? "location.fill" : "location")
                        .font(.footnote)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .disabled(locator.isLocating)
            }

            Text(location.isEmpty ? "未选择地点" : location)
                .font(.body)
                .foregroundStyle(location.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("具体地址（选填，如 XX路 100 号）", text: $address)
                .textFieldStyle(.roundedBorder)
        }
    }
}
