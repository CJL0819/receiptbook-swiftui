// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

/// 卡片风格的自定义滑动删除容器。
///
/// - 左滑露出与卡片同圆角的红色删除区，滑过阈值直接删除；
/// - 拖动会屏蔽点击，避免「滑一下却进了详情页」；
/// - 删除时把整行渲染成快照，碎成粒子飘散后再从数据层移除。
struct SwipeActionRow<Content: View>: View {
    let id: String
    /// 编辑态关掉左滑，但保留完全一致的卡片布局
    var swipeEnabled: Bool = true
    @Binding var openRowID: String?
    let onTap: () -> Void
    /// 参数：卡片快照、卡片尺寸、卡片在屏幕上的位置
    let onDelete: (UIImage, CGSize, CGRect) -> Void
    @ViewBuilder var content: Content

    @State private var offset: CGFloat = 0
    @State private var dragStart: CGFloat?
    @State private var didDrag = false
    @State private var cardSize: CGSize = .zero
    @State private var deleting = false
    /// 手势被系统取消（例如 ScrollView 接管）时 onEnded 不会回调，
    /// 卡片会停在半开位置；用这个看门狗兜底吸附。
    /// `@GestureState` 在手势结束「或被系统取消」时一定会复位到初始值，
    /// 用它判断「手指是否还在屏幕上」，比时间轮询可靠：
    /// 手指没离开时绝不会触发吸附（时间看门狗会在停顿 0.45s 时误收回）。
    @GestureState private var isTracking = false
    /// 吸附动画进行中：期间忽略拖动回调，防止收尾动画被半途写回、停在非端点位置
    @State private var isSettling = false
    /// 是否正在拖动：只用来在拖动期间关掉阴影（阴影每帧重绘是主要卡顿来源之一）
    @State private var isDragging = false
    @State private var globalFrame: CGRect = .zero
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var store: ReceiptStore

    private let actionWidth: CGFloat = 92
    /// 卡片与删除区之间的间距，避免两块贴在一起
    private let actionGap: CGFloat = 10
    private var openOffset: CGFloat { -(actionWidth + actionGap) }

    /// 删除区的实时宽度：跟着卡片位移走，被「拉」开而不是露出来。
    /// 卡片右侧与红色区域之间始终保留 actionGap 的间距。
    private var stretchedActionWidth: CGFloat {
        max(0, -offset - actionGap)
    }
    private let cornerRadius: CGFloat = 20
    private let spring = Animation.spring(response: 0.34, dampingFraction: 0.86)

    /// 滑出进度 0…1（0 = 完全收起，1 = 完全展开）
    private var revealProgress: Double {
        min(1, max(0, Double(-offset / -openOffset)))
    }

    /// 红色区域宽度到 40→90pt 之间时，文案淡入
    private var labelOpacity: Double {
        min(1, max(0, Double((stretchedActionWidth - 40) / 50)))
    }

    /// 跟着滑出距离由淡红过渡到系统红：拉得越开颜色越实。
    private var actionColor: Color {
        let progress = revealProgress
        return Color(red: 1.0,
                     green: 0.74 + (0.23 - 0.74) * progress,
                     blue: 0.72 + (0.19 - 0.72) * progress)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            content
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                // 拖动时关掉阴影：阴影每帧随位移重绘，是横向拖动掉帧的主要来源
                .shadow(color: .black.opacity(isDragging ? 0 : 0.05),
                        radius: isDragging ? 0 : 6,
                        y: isDragging ? 0 : 2)
                .offset(x: offset)
                .contentShape(Rectangle())
                .onTapGesture { handleTap() }
                .simultaneousGesture(swipeEnabled ? dragGesture : nil)

            if swipeEnabled {
                // 只有一份删除区：宽度由位移推导，永远和卡片保持 actionGap，
                // 不会出现「前后两份切换」导致的偶发错位闪红。
                deleteAction
                    .allowsHitTesting(offset <= openOffset + 0.5)
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        cardSize = proxy.size
                        globalFrame = proxy.frame(in: .global)
                    }
                    .onChange(of: proxy.size) { _, newValue in cardSize = newValue }
                    .onChange(of: proxy.frame(in: .global)) { _, newValue in
                        // 拖动时 offset 每帧变化、全局 frame 也跟着变，
                        // 若每帧写 @State 会拖慢手势；只在静止时记录即可（删除前会先归位）。
                        guard offset == 0 else { return }
                        globalFrame = newValue
                    }
            }
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .onChange(of: isTracking) { _, tracking in
            handleTrackingChange(tracking)
        }
        .onChange(of: offset) { _, newValue in
            // 兜底自愈：没在拖动、也没有吸附动画，却停在了非端点位置
            // （动画被打断 / 状态被外部写坏），立刻补一次吸附，不会「卡住」。
            guard !isTracking, !isSettling, dragStart == nil else { return }
            guard newValue != 0, newValue != openOffset else { return }
            settleIfNeeded()
        }
        .onChange(of: openRowID) { _, newValue in
            guard newValue != id, offset != 0 else { return }
            withAnimation(spring) { offset = 0 }
        }
        .onDisappear {
            // 撤销会把同 id 的行插回来并复用 @State，这里恢复干净状态
            offset = 0
            didDrag = false
            isDragging = false
            deleting = false
        }
    }

    // MARK: - 删除区

    private var deleteAction: some View {
        Button {
            closeRow()
            startDissolve()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(actionColor)

                // 文案始终在「当前拉伸宽度」里居中，而不是钉死在右侧
                VStack(spacing: 5) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                    Text("删除")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize()
                }
                .foregroundStyle(.white)
                // 刚被拉出来时宽度不够，先不显示文案，避免挤压换行。
                // 注意：这里不能加 .animation —— 隐式动画会连容器宽度一起补间，
                // 导致红色区域追着手指走（不跟手）、反向拖动时还会突然闪一下。
                .opacity(labelOpacity)
                .fixedSize()
            }
            .frame(width: stretchedActionWidth)
            .frame(maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("删除")
    }

    // MARK: - 点击 / 手势

    private func handleTap() {
        guard !deleting else { return }
        if offset != 0 {
            closeRow()
            return
        }
        guard !didDrag else { return }
        onTap()
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($isTracking) { _, state, _ in state = true }
            .onChanged { value in
                // 吸附动画进行中不接收拖动数据，避免把动画写停在半路
                guard !isSettling else { return }
                // 竖直方向交给 ScrollView 滚动，只有横向占优才接管
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if !didDrag, abs(value.translation.width) > 6 { didDrag = true }
                if dragStart == nil {
                    dragStart = offset
                    isDragging = true
                }
                let next = clampOffset((dragStart ?? 0) + value.translation.width)
                // 位移变化很小就不写状态，减少无谓的 body 重算
                if abs(next - offset) > 0.2 { offset = next }
            }
            .onEnded { value in
                isDragging = false
                dragStart = nil
                let projected = offset + value.predictedEndTranslation.width * 0.2

                // 只吸附「露出删除按钮」，不做滑到底直接删除
                if projected <= openOffset / 2 {
                    open()
                } else {
                    closeRow()
                }
                // 拖动结束后短暂屏蔽点击，避免回弹瞬间被判定成 tap
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    didDrag = false
                }
            }
    }

    /// 左滑到头有阻尼，右滑只给很小的回弹空间。
    private func clampOffset(_ value: CGFloat) -> CGFloat {
        if value > 0 { return value * 0.12 }
        return max(value, openOffset - 70)
    }

    private func open() {
        settle(to: openOffset, opening: true)
    }

    /// 统一吸附入口：加锁 + 动画完成时把位移校准到精确端点，
    /// 避免动画被打断后停在中间（表现为「卡住不动」）。
    private func settle(to target: CGFloat, opening: Bool) {
        guard !isSettling else { return }
        isSettling = true
        withAnimation(spring) {
            offset = target
        } completion: {
            offset = target
            isSettling = false
        }
        if opening {
            openRowID = id
        } else if openRowID == id {
            openRowID = nil
        }
    }

    /// 手势被系统取消时 onEnded 不回调，但 `isTracking` 一定会复位；
    /// 这时按当前位置吸附。正常结束（onEnded 已处理）不会走到这里。
    private func handleTrackingChange(_ tracking: Bool) {
        if tracking {
            // 新手势开始：解除上一次吸附的锁
            isSettling = false
            dragStart = nil
            return
        }
        guard dragStart != nil else { return }
        isDragging = false
        settleIfNeeded()
    }

    private func settleIfNeeded() {
        guard offset != 0, offset != openOffset else { return }
        dragStart = nil
        if offset <= openOffset / 2 {
            open()
        } else {
            closeRow()
        }
    }

    private func closeRow() {
        settle(to: 0, opening: false)
    }

    // MARK: - 粒子消散

    private func startDissolve() {
        guard !deleting else { return }
        deleting = true
        Haptics.delete()

        // 先把卡片瞬间归位（无动画），保证快照与卡片位置完全对齐，不会「跳一下」
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { offset = 0 }

        // 连卡片底色一起渲染，碎片才是「卡片的一部分」；暗色模式要显式带上
        let card = content
            .environmentObject(store)          // 预览快照也要能取到缩略图
            .frame(width: cardSize.width, height: cardSize.height)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .environment(\.colorScheme, colorScheme)
        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale

        guard let image = renderer.uiImage else {
            // 渲染失败兜底：直接删，不做粒子
            onDelete(UIImage(), cardSize, globalFrame)
            return
        }
        // 立刻回调：行马上消失、列表同步上移，粒子由列表层接着画
        onDelete(image, cardSize, globalFrame)
    }
}
