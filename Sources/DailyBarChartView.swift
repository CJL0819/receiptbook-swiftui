// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

/// 每日支出柱状图卡片（纯 SwiftUI 绘制，支持左右滑动与点击看当天）。
struct DailyBarChartView: View {
    let values: [Double]
    var onTapDay: (Int) -> Void = { _ in }

    private let barWidth: CGFloat = 10
    private let spacing: CGFloat = 4
    private let chartHeight: CGFloat = 110

    private var maxValue: Double {
        max(values.max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("每日支出")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(maxValue.yuan)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 4) {
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(values.indices, id: \.self) { index in
                            barSlot(for: index)
                        }
                    }

                    HStack(spacing: spacing) {
                        ForEach(values.indices, id: \.self) { index in
                            Text(dayLabel(for: index))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .frame(width: barWidth, alignment: .center)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }

            Text("左右滑动查看整月 · 点柱子看当天")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func barSlot(for index: Int) -> some View {
        let value = values[index]
        VStack {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: min(barWidth / 2, 3))
                .fill(Color.accentColor)
                .frame(width: barWidth, height: barHeight(for: value))
                .opacity(value > 0 ? 1 : 0)
        }
        .frame(width: barWidth, height: chartHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            if value > 0 {
                onTapDay(index + 1)
            }
        }
    }

    private func barHeight(for value: Double) -> CGFloat {
        guard value > 0 else { return 0 }
        return max(CGFloat(value / maxValue) * chartHeight, 2)
    }

    private func dayLabel(for index: Int) -> String {
        if index == 0 || index == values.count - 1 || (index >= 4 && (index - 4) % 5 == 0) {
            return "\(index + 1)"
        }
        return ""
    }
}
