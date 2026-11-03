// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import UIKit

/// 一次待撤销的删除。带 id 是为了让 5 秒计时器只清理自己那一次。
struct PendingUndo: Identifiable {
    let id = UUID()
    let snapshot: DeletedSnapshot
}

/// 撤销横幅的全局状态。
///
/// 横幅挂在 RootView 最上层（TabView 之上），所以滚动列表、收起搜索栏、
/// 切换 tab 都不会把横幅带着一起动；位置固定在安全区顶部，正好盖住导航栏。
final class UndoBannerCenter: ObservableObject {
    static let shared = UndoBannerCenter()

    @Published private(set) var pending: PendingUndo?
    private var timer: Task<Void, Never>?

    private init() {}

    func present(_ snapshot: DeletedSnapshot) {
        timer?.cancel()
        let item = PendingUndo(snapshot: snapshot)
        // 横幅已经在场上就直接换内容；否则等列表收起的那一帧过去再进场，
        // 两段动画错开，避免同一帧里既收列表又弹横幅而掉帧。
        let delay: UInt64 = pending == nil ? 120_000_000 : 0

        timer = Task { [id = item.id] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else { return }
            }
            await MainActor.run {
                withAnimation(.spring(response: 0.40, dampingFraction: 0.86)) {
                    self.pending = item
                }
            }
            // 5 秒倒计时从进场那一刻开始
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                // 只清理自己那一次，避免把后来的删除横幅误关掉
                guard self.pending?.id == id else { return }
                withAnimation(.easeInOut(duration: 0.28)) { self.pending = nil }
            }
        }
    }

    func undo() {
        guard let item = pending else { return }
        Haptics.undo()
        timer?.cancel()
        timer = nil
        withAnimation(.easeOut(duration: 0.24)) {
            ReceiptStore.shared.restore(item.snapshot)
            pending = nil
        }
    }
}

// MARK: - 横幅

/// 挂在根视图最上层的横幅宿主。
///
/// 订阅状态只发生在这一个小视图里：横幅出现/消失时不会把整个 TabView
/// 连同里面所有列表重新求值一遍，落下的最后几帧才不会顿。
struct UndoBannerHost: View {
    @ObservedObject private var center = UndoBannerCenter.shared

    var body: some View {
        ZStack(alignment: .top) {
            if let pending = center.pending {
                UndoBannerView(pending: pending) {
                    center.undo()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(center.pending != nil)
    }
}

/// 顶部系统通知式的撤销横幅：图标 + 标题 + 副标题 + 倒计时，整条可点。
struct UndoBannerView: View {
    let pending: PendingUndo
    let onUndo: () -> Void

    private var count: Int { pending.snapshot.receipts.count }

    /// 浅色=白卡，深色比卡片再亮一档（否则会糊进深色背景）
    private var surface: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.tertiarySystemGroupedBackground
                : UIColor.secondarySystemGroupedBackground
        })
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)

        return Button(action: onUndo) {
            HStack(spacing: 11) {
                icon

                VStack(alignment: .leading, spacing: 1) {
                    Text(count > 1 ? "已删除 \(count) 张票据" : "已删除 1 张票据")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("点按撤销")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                UndoCountdownRing(token: pending.id)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                // 不用毛玻璃：横幅在最上层，材质每帧都要重新采样背景，
                // 落下的收尾几帧反而容易掉帧。改用接近不透明的自适应底色。
                shape
                    .fill(surface)
                    .shadow(color: .black.opacity(0.16), radius: 18, y: 7)
            }
            .overlay {
                shape.strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.6)
            }
            .contentShape(shape)
        }
        .buttonStyle(UndoBannerButtonStyle())
        .padding(.horizontal, 8)
        .padding(.top, 8)
        // 从屏幕上方落下来，带一点回弹；收起时往回收，和系统横幅一致
        .transition(
            .asymmetric(
                insertion: .offset(y: -120).combined(with: .opacity),
                removal: .offset(y: -60).combined(with: .opacity)
            )
        )
    }

    /// 左侧圆形 App 图标（删除符号）
    private var icon: some View {
        RoundedRectangle(cornerRadius: 9.5, style: .continuous)
            .fill(LinearGradient(colors: [Color(red: 0.35, green: 0.55, blue: 0.99),
                                          Color(red: 0.24, green: 0.42, blue: 0.91)],
                                 startPoint: .top,
                                 endPoint: .bottom))
            .frame(width: 38, height: 38)
            .overlay {
                Image(systemName: "trash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

/// 按住时只做极轻微的缩放：系统默认的按压透明度会让毛玻璃一下变脏。
private struct UndoBannerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 5 秒撤销窗口：圆环顺时针走完
private struct UndoCountdownRing: View {
    let token: UUID

    @State private var fraction: CGFloat = 1

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: 2)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.primary.opacity(0.55),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 18, height: 18)
        .onAppear {
            fraction = 1
            withAnimation(.linear(duration: 5)) { fraction = 0 }
        }
        .id(token)
    }
}
