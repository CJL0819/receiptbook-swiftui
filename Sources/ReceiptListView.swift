// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import UIKit

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
    @State private var showStats = false
    @State private var selection = Set<String>()
    @State private var editMode: EditMode = .inactive
    @State private var deleteCandidates: [Receipt] = []
    @State private var showDeleteConfirm = false
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
        guard !searchText.isEmpty else { return baseReceipts }
        return baseReceipts.filter {
            $0.merchant.localizedCaseInsensitiveContains(searchText)
                || $0.note.localizedCaseInsensitiveContains(searchText)
                || $0.type.displayName.localizedCaseInsensitiveContains(searchText)
                || ($0.location?.localizedCaseInsensitiveContains(searchText) ?? false)
                || $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
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
        List(selection: $selection) {
            ForEach(visibleReceipts) { receipt in
                NavigationLink {
                    ReceiptDetailView(receipt: receipt)
                } label: {
                    ReceiptRow(receipt: receipt)
                }
                .tag(receipt.id)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteCandidates = [receipt]
                        showDeleteConfirm = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .listRowSeparator(.hidden)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .environment(\.editMode, $editMode)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, isPresented: $appState.isSearching, prompt: "搜索商家或备注")
        .onChange(of: searchText) {
            selection.removeAll()
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if isFiltered && !visibleReceipts.isEmpty {
                summaryHeader
            }
        }
        .toolbar {
            if editMode == .active {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        withAnimation { editMode = .inactive }
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
                if case .expense = filter {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showStats = true
                        } label: {
                            Image(systemName: "chart.bar")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("编辑") {
                        withAnimation { editMode = .active }
                    }
                }
            }
        }
        .overlay {
            if visibleReceipts.isEmpty {
                emptyState
            }
        }
        .sheet(isPresented: $showStats) {
            StatsView()
        }
        .alert("删除票据", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) {
                confirmDelete()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除 \(deleteCandidates.count) 张票据，此操作无法撤销。")
        }
    }

    // MARK: - 删除

    private func delete(at offsets: IndexSet) {
        deleteCandidates = offsets.map { visibleReceipts[$0] }
        showDeleteConfirm = true
    }

    private func deleteSelected() {
        deleteCandidates = visibleReceipts.filter { selection.contains($0.id) }
        showDeleteConfirm = true
    }

    private func confirmDelete() {
        for receipt in deleteCandidates {
            store.delete(receipt)
        }
        deleteCandidates = []
        selection.removeAll()
        editMode = .inactive
    }

    // MARK: - 其余

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(isFiltered ? "暂无记录" : "还没有记账票据\n点下方 + 或「扫描」添加")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
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

struct ReceiptRow: View {
    let receipt: Receipt
    @EnvironmentObject private var store: ReceiptStore

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(receipt.merchant.isEmpty
                     ? receipt.type.displayName
                     : "\(receipt.type.displayName) · \(receipt.merchant)")
                    .font(.body)
                    .lineLimit(1)
                Text(Self.dateFormatter.string(from: receipt.date))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let amount = receipt.amount {
                Text(amount.yuan)
                    .font(.system(.body, design: .monospaced).weight(.medium))
            } else {
                Text("纪念")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }

    private var thumbnail: some View {
        Group {
            if let image = store.thumbnail(for: receipt, page: 0) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "doc.text.image")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 56, height: 72)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
