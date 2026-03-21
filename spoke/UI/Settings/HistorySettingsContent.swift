import AppKit
import Foundation
import SwiftData
import SwiftUI

private typealias DS = DesignTokens

@MainActor
struct HistorySettingsDependencies {
    let historyManager: HistoryManager
    let llmSettings: LLMSettings
    let audioPlayer: AudioPlayerService
    let copyText: (String) -> Void
}

@MainActor
extension HistorySettingsDependencies {
    static let live = HistorySettingsDependencies(
        historyManager: .shared,
        llmSettings: .shared,
        audioPlayer: .shared,
        copyText: { text in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    )
}

// MARK: - History Settings

struct HistorySettingsContent: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HistoryItem.createdAt, order: .reverse) private var historyItems: [HistoryItem]
    private let dependencies: HistorySettingsDependencies
    @State private var searchText = ""

    init() {
        self.dependencies = .live
    }

    init(dependencies: HistorySettingsDependencies) {
        self.dependencies = dependencies
    }
    
    /// 按日期分组的历史记录
    private var groupedItems: [(String, [HistoryItem])] {
        let filtered = historyItems.filter { item in
            searchText.isEmpty || item.rawText.localizedCaseInsensitiveContains(searchText)
        }
        
        let grouped = Dictionary(grouping: filtered) { item -> String in
            let calendar = Calendar.current
            if calendar.isDateInToday(item.createdAt) {
                return "今天"
            } else if calendar.isDateInYesterday(item.createdAt) {
                return "昨天"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy年M月d日"
                return formatter.string(from: item.createdAt)
            }
        }
        
        // 按日期排序（今天 > 昨天 > 具体日期倒序）
        return grouped.sorted { lhs, rhs in
            if lhs.key == "今天" { return true }
            if rhs.key == "今天" { return false }
            if lhs.key == "昨天" { return true }
            if rhs.key == "昨天" { return false }
            return lhs.key > rhs.key
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 搜索栏
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DS.Colors.textSecondary)
                TextField("搜索", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(DS.Colors.textPrimary)
            }
            .padding(10)
            .background(DS.Colors.settingsCardBackground)
            .cornerRadius(DS.CornerRadius.md)
            .padding(.bottom, 20)
            
            // 列表
            if historyItems.isEmpty {
                emptyStateView
            } else if groupedItems.isEmpty {
                noResultsView
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(groupedItems, id: \.0) { dateString, items in
                            VStack(alignment: .leading, spacing: 12) {
                                // 日期分组标题
                                Text(dateString)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(DS.Colors.textPrimary)
                                    .padding(.top, 4)
                                
                                // 该日期下的记录
                                VStack(spacing: 8) {
                                    ForEach(items) { item in
                                        HistoryItemRow(
                                            item: item,
                                            dependencies: dependencies,
                                            onDelete: { deleteItem(item) }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 40))
                .foregroundStyle(DS.Colors.textSecondary.opacity(0.4))
            Text("还没有录音记录")
                .font(.system(size: 14))
                .foregroundStyle(DS.Colors.textSecondary)
            Text("使用快捷键开始录音后，记录会显示在这里")
                .font(.system(size: 12))
                .foregroundStyle(DS.Colors.textSecondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(DS.Colors.textSecondary.opacity(0.4))
            Text("没有找到匹配的记录")
                .font(.system(size: 14))
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func deleteItem(_ item: HistoryItem) {
        // 删除音频文件
        if let audioPath = item.audioPath {
            let audioURL = dependencies.historyManager.audioStorageURL.appendingPathComponent(audioPath)
            try? FileManager.default.removeItem(at: audioURL)
        }
        modelContext.delete(item)
    }
}

// MARK: - Reprocess Sheet

struct ReprocessSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: HistoryItem
    private let dependencies: HistorySettingsDependencies
    
    @State private var customPrompt = ""
    @State private var isProcessing = false
    @State private var resultText: String?
    @State private var errorMessage: String?

    init(item: HistoryItem, dependencies: HistorySettingsDependencies) {
        self.item = item
        self.dependencies = dependencies
    }

    init(item: HistoryItem) {
        self.init(item: item, dependencies: .live)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题
            HStack {
                Text("重新处理")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DS.Colors.textPrimary)
                Spacer()
                Button(action: { dismiss() }, label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DS.Colors.textSecondary)
                })
                .buttonStyle(.plain)
            }
            
            // 原始文本预览
            VStack(alignment: .leading, spacing: 8) {
                Text("原始文本")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DS.Colors.textSecondary)
                Text(item.rawText)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Colors.textPrimary.opacity(0.8))
                    .lineLimit(3)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Colors.rowHover)
                    .cornerRadius(DS.CornerRadius.md)
            }
            
            // 自定义 Prompt 输入
            VStack(alignment: .leading, spacing: 8) {
                Text("自定义指令（可选）")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DS.Colors.textSecondary)
                TextEditor(text: $customPrompt)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(height: 80)
                    .background(DS.Colors.rowHover)
                    .cornerRadius(DS.CornerRadius.md)
                Text("留空则使用当前系统 Prompt")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Colors.textSecondary.opacity(0.6))
            }
            
            // 结果显示
            if let result = resultText {
                VStack(alignment: .leading, spacing: 8) {
                    Text("处理结果")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.Colors.success)
                    Text(result)
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Colors.textPrimary.opacity(0.9))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DS.Colors.success.opacity(0.1))
                        .cornerRadius(DS.CornerRadius.md)
                        .textSelection(.enabled)
                }
            }
            
            // 错误信息
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Colors.error)
            }
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 12) {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(DS.Colors.rowHover)
                .cornerRadius(DS.CornerRadius.md)
                
                Button(action: reprocess, label: {
                    HStack(spacing: 6) {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isProcessing ? "处理中..." : "重新处理")
                    }
                })
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(DS.Colors.accentProcessing)
                .foregroundStyle(DS.Colors.textPrimary)
                .cornerRadius(DS.CornerRadius.md)
                .disabled(isProcessing)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .frame(width: 400, height: 420)
        .background(DS.Colors.settingsCardBackground)
    }
    
    private func reprocess() {
        isProcessing = true
        errorMessage = nil
        resultText = nil
        
        Task {
            let prompt = customPrompt.isEmpty ? nil : customPrompt
            let result = await dependencies.historyManager.reprocess(item, with: prompt ?? dependencies.llmSettings.systemPrompt)
            
            await MainActor.run {
                isProcessing = false
                switch result {
                case .success(let text):
                    resultText = text
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct HistoryItemRow: View {
    let item: HistoryItem
    private let dependencies: HistorySettingsDependencies
    var onDelete: () -> Void
    
    @ObservedObject private var audioPlayer: AudioPlayerService
    @State private var isHovering = false
    @State private var showCopied = false
    @State private var isReprocessing = false

    init(
        item: HistoryItem,
        dependencies: HistorySettingsDependencies,
        onDelete: @escaping () -> Void
    ) {
        self.item = item
        self.dependencies = dependencies
        self.onDelete = onDelete
        self.audioPlayer = dependencies.audioPlayer
    }

    init(item: HistoryItem, onDelete: @escaping () -> Void) {
        self.init(item: item, dependencies: .live, onDelete: onDelete)
    }
    
    /// 当前是否正在播放此条目的音频
    private var isPlayingThis: Bool {
        guard let audioPath = item.audioPath else { return false }
        let url = HistoryManager.shared.audioStorageURL.appendingPathComponent(audioPath)
        return audioPlayer.isPlaying(url: url)
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "a h:mm"
        formatter.amSymbol = "上午"
        formatter.pmSymbol = "下午"
        return formatter.string(from: item.createdAt)
    }
    
    private var displayText: String {
        item.processedText ?? item.rawText
    }

    private var reprocessOpacity: Double {
        if isReprocessing {
            return 0.25
        }
        return 0.15
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // 左侧：时间戳 + 内容
            VStack(alignment: .leading, spacing: 8) {
                // 时间戳
                Text(timeString)
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Colors.textSecondary.opacity(0.7))
                
                // 内容
                Text(displayText)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Colors.textPrimary.opacity(0.9))
                    .lineLimit(4)
                    .lineSpacing(3)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 右侧：操作按钮
            HStack(spacing: 10) {
                // 复制按钮 - 更透明磨砂
                Button(action: copyToClipboard, label: {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13))
                        .foregroundStyle(showCopied ? DS.Colors.success : DS.Colors.textPrimary.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(DS.Colors.rowHover)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                })
                .buttonStyle(.plain)
                .help("复制")
                
                // 播放按钮 - 蓝色透明磨砂
                Button(action: togglePlay, label: {
                    Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Colors.accentPrimary)
                        .frame(width: 32, height: 32)
                        .background(DS.Colors.accentPrimary.opacity(isPlayingThis ? 0.25 : 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                })
                .buttonStyle(.plain)
                .help(isPlayingThis ? "暂停" : "播放")
                .opacity(item.audioPath != nil ? 1 : 0.3)
                .disabled(item.audioPath == nil)
                
                // 重处理按钮 - 紫色透明磨砂
                Button(action: reprocess, label: {
                    Group {
                        if isReprocessing {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 13, height: 13)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13))
                        }
                    }
                })
                    .foregroundStyle(DS.Colors.accentProcessing)
                    .frame(width: 32, height: 32)
                    .background(DS.Colors.accentProcessing.opacity(reprocessOpacity))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                .buttonStyle(.plain)
                .help("重新处理")
                .disabled(isReprocessing)
                
                // 删除按钮 - 红色透明磨砂
                Button(action: onDelete, label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Colors.error)
                        .frame(width: 32, height: 32)
                        .background(DS.Colors.error.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                })
                .buttonStyle(.plain)
                .help("删除")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(DS.Colors.surfaceThin)
        .cornerRadius(DS.CornerRadius.lg)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
    
    private func copyToClipboard() {
        dependencies.copyText(displayText)
        
        withAnimation {
            showCopied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopied = false
            }
        }
    }
    
    private func togglePlay() {
        guard let audioPath = item.audioPath else { return }
        let url = dependencies.historyManager.audioStorageURL.appendingPathComponent(audioPath)
        
        if isPlayingThis {
            // 正在播放此条目，暂停
            audioPlayer.pause()
        } else if audioPlayer.currentURL == url {
            // 暂停了此条目，继续播放
            audioPlayer.resume()
        } else {
            // 播放新的音频
            do {
                try audioPlayer.play(url)
            } catch {
                print("❌ 播放失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func reprocess() {
        isReprocessing = true
        
        Task {
            // 使用当前系统 Prompt 重处理
            let result = await dependencies.historyManager.reprocess(item, with: dependencies.llmSettings.systemPrompt)
            
            await MainActor.run {
                isReprocessing = false
                
                switch result {
                case .success:
                    // 成功后 item.processedText 已更新，SwiftData 会自动刷新 UI
                    break
                case .failure(let error):
                    print("❌ 重处理失败: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("History Item Row") {
    let item = HistoryItem(
        rawText: "这是一段测试文本，用来预览历史记录行的样式效果。",
        processedText: "这是经过 LLM 处理后的文本，用来预览历史记录行的样式效果。",
        audioPath: "test.caf"
    )
    
    return VStack(spacing: 12) {
        HistoryItemRow(item: item, onDelete: {})
        
        HistoryItemRow(
            item: HistoryItem(rawText: "短文本测试"),
            onDelete: {}
        )
        
        HistoryItemRow(
            item: HistoryItem(
                rawText: "这是一段很长很长的文本，用来测试多行显示的效果。这是一段很长很长的文本，用来测试多行显示的效果。这是一段很长很长的文本，用来测试多行显示的效果。",
                audioPath: nil
            ),
            onDelete: {}
        )
    }
    .padding()
    .background(DS.Colors.settingsBackground)
}

#Preview("History Settings") {
    HistorySettingsContent()
        .frame(width: 500, height: 400)
        .background(DS.Colors.settingsBackground)
        .modelContainer(for: HistoryItem.self, inMemory: true)
}

// MARK: - Microphone Tester
