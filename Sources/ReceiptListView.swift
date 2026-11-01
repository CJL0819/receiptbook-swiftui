// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import UIKit

/// 待撤销的一次删除。带 id 是为了让 5 秒计时器只清理自己那一次，不会误清新的撤销条目。
private struct PendingUndo: Identifiable {
    let id = UUID()
    let snapshot: DeletedSnapshot
}

struct ReceiptListView: View {
    enum Filter: Hashable {
        case expense                        // 全部记账
        case type(ReceiptType)              // 某类型（全部时间）
        case typeInMonth(ReceiptType, Date) // 某类型某月
        case day(Date)                      // 某天
    }

    @EnvironmentObject private var store: ReceiptStore
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    @State private var selectedType: ReceiptType?
    @State private var sortOrder: ReceiptSortOrder = .dateNewest
    @State private var showStats = false
    @State private var selection = Set<String>()
    @State private var editMode: EditMode = .inactive
    @State private var openRowID: String?
    @State private var selectedReceipt: Receipt?
    @State private var pendingUndo: PendingUndo?
    @State private var undoTimer: Task<Void, Never>?
    private let filter: Filter

    init(filter: Filter = .expense) {
        self.filter = filter
    }

    private var baseReceipts: [Receipt] {
        switch filter {
        case .expense: return store.receipts.filter { $0.amount != nil }
        case .type(let type): return store.receipts(ofType: type)
        case .typeInMonth(let type, let month):
            return store.receipts(ofType: type).filter {
                Calendar.current.isDate($0.date, equalTo: month, toGranularity: .month)
            }
        case .day(let day): return store.receipts(on: day)
        }
    }

    private var visibleReceipts: [Receipt] {
        var items = baseReceipts
        if let selectedType {
            items = items.filter { $0.type == selectedType }
        }
        if !searchText.isEmpty {
            items = items.filter {
                $0.merchant.localizedCaseInsensitiveContains(searchText)
                    || $0.note.localizedCaseInsensitiveContains(searchText)
                    || $0.type.displayName.localizedCaseInsensitiveContains(searchText)
                    || ($0.location?.localizedCaseInsensitiveContains(searchText) ?? false)
                    || ($0.address?.localizedCaseInsensitiveContains(searchText) ?? false)
                    || $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        return items.sorted(by: sortOrder.areInIncreasingOrder)
    }

    private var isFiltered: Bool {
        if case .expense = filter { return false }
        return true
    }

    private var title: String {
        switch filter {
        case .expense: return "记账"
        case .type(let type): return type.displayName
        case .typeInMonth(let type, let month): return "\(type.displayName) · \(Self.monthFormatter.string(from: month))"
        case .day(let day): return Self.dayFormatter.string(from: day)
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月"
        return formatter
    }()

    var body: some View {
        listContent
    }

    private var listContent: some View {
        ZStack(alignment: .bottom) {
            listScroll

            if let pendingUndo {
                undoBar(for: pendingUndo.snapshot)
            }
        }
    }

    private var listScroll: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(visibleReceipts) { receipt in
                    row(for: receipt)
                }
            }
            .padding(.vertical, 6)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color(.systemGroupedBackground))
        .navigationDestination(item: $selectedReceipt) { receipt in
            ReceiptDetailView(receipt: receipt)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, isPresented: $appState.isSearching, prompt: "搜索商家或备注")
        .onChange(of: searchText) {
            selection.removeAll()
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                // 进入搜索时收起筛选条：导航栏变高会让这条 inset 重新布局，
                // 直接跟着走会「跳」一下；用高度+透明度同步过渡更顺，搜索时界面也更干净。
                ReceiptFilterBar(selectedType: $selectedType,
                                 sortOrder: $sortOrder,
                                 availableTypes: ReceiptType.allCases,
                                 resultCount: visibleReceipts.count)
                    .frame(height: appState.isSearching ? 0 : 50)
                    .opacity(appState.isSearching ? 0 : 1)
                    .clipped()

                if isFiltered && !visibleReceipts.isEmpty {
                    summaryHeader
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .animation(.easeInOut(duration: 0.24), value: appState.isSearching)
        }
        .toolbar {
            if editMode == .active {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") {
                        // 不加动画：编辑态与普通态布局一致，动画反而让整列卡片抖一下
                        editMode = .inactive
                        selection.removeAll()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !selection.isEmpty {
                        Button("删除\(selection.count)项") {
                            deleteSelected()
                        }
                    }
                }
            } else {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("编辑") {
                        openRowID = nil
                        editMode = .active
                    }
                }
                if case .expense = filter {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("统计") {
                            showStats = true
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // 悬浮 Tab 栏是覆盖在内容上的，这里显式留出高度，保证滑到底能看到最后一条
            Color.clear.frame(height: appState.isSearching ? 0 : FloatingTabMetrics.reservedHeight)
        }
        .overlay {
            if visibleReceipts.isEmpty {
                emptyState
            }
        }
        .sheet(isPresented: $showStats) {
            StatsView()
        }
    }

    /// 单条行：普通态可左滑删除并点击进入详情；编辑态在同一套布局上浮动勾选徽章，
    /// 保证切换编辑模式时卡片不位移、不抖动。
    @ViewBuilder
    private func row(for receipt: Receipt) -> some View {
        let isEditing = editMode == .active
        let isSelected = selection.contains(receipt.id)

        SwipeActionRow(id: receipt.id,
                       swipeEnabled: !isEditing,
                       openRowID: $openRowID,
                       onTap: {
                           if isEditing {
                               toggleSelection(receipt)
                           } else {
                               selectedReceipt = receipt
                           }
                       },
                       onDelete: { image, size, frame in
                           BurstCenter.shared.add(DissolveBurst(image: image, size: size, frame: frame))
                           delete([receipt])
                       }) {
            ReceiptRow(receipt: receipt, showsChevron: !isEditing)
                .padding(.horizontal, 12)
                .overlay(alignment: .topLeading) {
                    if isEditing {
                        selectionBadge(isSelected: isSelected)
                    }
                }
        }
        .jiggle(isEditing, seed: abs(receipt.id.hashValue))
        .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .opacity))
    }

    /// 勾选徽章浮在缩略图左上角，不占用布局宽度，所以切换编辑态时内容不漂移。
    private func selectionBadge(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .background(Circle().fill(Color(.secondarySystemGroupedBackground)))
            .padding(5)
    }

    private func toggleSelection(_ receipt: Receipt) {
        if selection.contains(receipt.id) {
            selection.remove(receipt.id)
        } else {
            selection.insert(receipt.id)
        }
    }

    // MARK: - 删除

    private func deleteSelected() {
        delete(visibleReceipts.filter { selection.contains($0.id) })
    }

    /// 立即删除 + 底部「撤销」条；不再用系统弹窗打断。
    private func delete(_ items: [Receipt]) {
        guard !items.isEmpty else { return }
        let snapshot = store.snapshot(items)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            store.delete(items)
        }
        selection.removeAll()
        editMode = .inactive
        presentUndo(for: snapshot)
    }

    private func presentUndo(for snapshot: DeletedSnapshot) {
        undoTimer?.cancel()
        let item = PendingUndo(snapshot: snapshot)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            pendingUndo = item
        }
        undoTimer = Task { [id = item.id] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                // 只清理自己那一次，避免把后来的删除撤销条误关掉
                guard pendingUndo?.id == id else { return }
                withAnimation(.easeInOut(duration: 0.25)) { pendingUndo = nil }
            }
        }
    }

    private func undoDelete() {
        guard let item = pendingUndo else { return }
        Haptics.undo()
        undoTimer?.cancel()
        undoTimer = nil
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            store.restore(item.snapshot)
            pendingUndo = nil
        }
    }

    private func undoBar(for snapshot: DeletedSnapshot) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "trash")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(snapshot.receipts.count > 1 ? "已删除 \(snapshot.receipts.count) 张票据" : "已删除 1 张票据")
                .font(.system(size: 14, weight: .medium))
            Spacer(minLength: 12)
            Button {
                undoDelete()
            } label: {
                Text("撤销")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .contentShape(Capsule())
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.horizontal, 20)
        .padding(.bottom, FloatingTabMetrics.reservedHeight + 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - 其余

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: selectedType == nil ? "tray" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tertiary)
            Text(emptyMessage)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if selectedType != nil, searchText.isEmpty {
                Button("查看全部") {
                    Haptics.selection()
                    withAnimation(.snappy(duration: 0.24)) { selectedType = nil }
                }
                .font(.footnote.weight(.semibold))
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyMessage: String {
        if !searchText.isEmpty { return "没有找到相关票据" }
        if selectedType != nil { return "这个类型还没有票据" }
        if isFiltered { return "暂无记录" }
        return "还没有记账票据\n点下方 + 或「扫描」添加"
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            let total = visibleReceipts.reduce(0) { $0 + ($1.amount ?? 0) }
            Text(headerTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(total.yuan)
                .font(.system(size: 30, weight: .semibold, design: .monospaced))
            Text(headerSubtitle(total: total))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var headerTitle: String {
        switch filter {
        case .type(let type), .typeInMonth(let type, _):
            return "\(type.displayName)支出"
        case .day:
            return "当日支出"
        case .expense:
            return ""
        }
    }

    private func headerSubtitle(total: Double) -> String {
        let expenseCount = visibleReceipts.filter { $0.amount != nil }.count
        let memoCount = visibleReceipts.count - expenseCount

        var base: String
        switch filter {
        case .type:
            let allTotal = store.totalAmount
            let percent = allTotal > 0 ? total / allTotal * 100 : 0
            base = "\(expenseCount) 笔 · 占总支出 \(String(format: "%.0f%%", percent))"
        case .typeInMonth(_, let month):
            let monthTotal = store.totalAmount(inMonthOf: month)
            let percent = monthTotal > 0 ? total / monthTotal * 100 : 0
            base = "\(expenseCount) 笔 · 占当月支出 \(String(format: "%.0f%%", percent))"
        default:
            base = "\(expenseCount) 笔"
        }
        if memoCount > 0 {
            base += " · 纪念 \(memoCount) 张"
        }
        return base
    }
}

// MARK: - 列表行

/// 类型胶囊：用票据类型自带的主题色，浅底 + 同色文字。
struct ReceiptTypePill: View {
    let type: ReceiptType

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: type.symbolName)
                .font(.system(size: 9, weight: .semibold))
            Text(type.displayName)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(type.tintColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(type.tintColor.opacity(0.13), in: Capsule())
    }
}

struct ReceiptRow: View {
    let receipt: Receipt
    var showsChevron: Bool = true
    @EnvironmentObject private var store: ReceiptStore

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()

    /// 今天 / 昨天用相对说法，更接近现代记账 App 的观感。
    private static func dateLabel(for date: Date) -> String {
        let calendar = Calendar.current
        let time = timeFormatter.string(from: date)
        if calendar.isDateInToday(date) { return "今天 \(time)" }
        if calendar.isDateInYesterday(date) { return "昨天 \(time)" }
        if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            return "\(monthDayFormatter.string(from: date)) \(time)"
        }
        return fullDateFormatter.string(from: date)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            thumbnail

            VStack(alignment: .leading, spacing: 7) {
                Text(displayTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                ReceiptTypePill(type: receipt.type)

                if let place = placeText {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 9, weight: .semibold))
                        Text(place)
                            .font(.system(size: 11))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 6) {
                trailing
                Text(Self.dateLabel(for: receipt.date))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.quaternary)
                .opacity(showsChevron ? 1 : 0)

        }
        .padding(.vertical, 10)
    }

    private var displayTitle: String {
        receipt.merchant.isEmpty ? receipt.type.displayName : receipt.merchant
    }

    /// 卡片上展示的地点：优先「地点」，没有时退回「详细地址」，都没有返回 nil。
    private var placeText: String? {
        if let location = receipt.location, !location.isEmpty { return location }
        if let address = receipt.address, !address.isEmpty { return address }
        return nil
    }

    @ViewBuilder
    private var trailing: some View {
        if let amount = receipt.amount {
            Text(amount.yuan)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .fixedSize()
        } else {
            HStack(spacing: 3) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 9, weight: .semibold))
                Text("纪念")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.tertiarySystemFill), in: Capsule())
            .fixedSize()
        }
    }

    /// 没有地点/地址时卡片更紧凑：缩略图跟着变矮，卡片高度自然收敛
    private var thumbnailHeight: CGFloat {
        placeText == nil ? 68 : 84
    }

    private var thumbnail: some View {
        thumbnailImage(0)
            .frame(width: 64, height: thumbnailHeight)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
            }
            .overlay(alignment: .bottomTrailing) {
                if receipt.pageCount > 1 {
                    Text("\(receipt.pageCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(.black.opacity(0.62), in: Capsule())
                        .padding(4)
                }
            }
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    @ViewBuilder
    private func thumbnailImage(_ page: Int) -> some View {
        if let image = store.thumbnail(for: receipt, page: page) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color(.tertiarySystemFill)
                Image(systemName: "doc.text.image")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
