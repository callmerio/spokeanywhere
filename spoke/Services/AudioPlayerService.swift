import AVFoundation
import Combine
import os

/// 音频播放服务
/// 负责历史记录中音频的播放、暂停、进度控制
@MainActor
final class AudioPlayerService: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = AudioPlayerService()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "AudioPlayer")
    
    // MARK: - Published Properties
    
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var progress: Double = 0  // 0.0 ~ 1.0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var currentURL: URL?
    
    // MARK: - Private Properties
    
    private var player: AVAudioPlayer?
    private var progressTimer: Timer?
    
    // MARK: - Init
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public API
    
    /// 播放音频
    /// - Parameter url: 音频文件 URL
    func play(_ url: URL) throws {
        // 如果正在播放其他音频，先停止
        if isPlaying {
            stop()
        }
        
        // 创建播放器
        player = try AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        
        guard let player = player else {
            throw AudioPlayerError.playerCreationFailed
        }
        
        // 更新状态
        currentURL = url
        duration = player.duration
        currentTime = 0
        progress = 0
        
        // 开始播放
        player.play()
        isPlaying = true
        startProgressTimer()
        
        logger.info("▶️ Playing: \(url.lastPathComponent)")
    }
    
    /// 暂停播放
    func pause() {
        player?.pause()
        isPlaying = false
        stopProgressTimer()
        logger.info("⏸️ Paused")
    }
    
    /// 继续播放
    func resume() {
        player?.play()
        isPlaying = true
        startProgressTimer()
        logger.info("▶️ Resumed")
    }
    
    /// 停止播放
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentURL = nil
        currentTime = 0
        progress = 0
        duration = 0
        stopProgressTimer()
        logger.info("⏹️ Stopped")
    }
    
    /// 跳转到指定时间
    /// - Parameter time: 目标时间（秒）
    func seek(to time: TimeInterval) {
        guard let player = player else { return }
        
        let clampedTime = max(0, min(time, duration))
        player.currentTime = clampedTime
        currentTime = clampedTime
        progress = duration > 0 ? clampedTime / duration : 0
    }
    
    /// 跳转到指定进度
    /// - Parameter progress: 目标进度（0.0 ~ 1.0）
    func seek(toProgress newProgress: Double) {
        let targetTime = duration * max(0, min(newProgress, 1))
        seek(to: targetTime)
    }
    
    /// 切换播放/暂停
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }
    
    /// 检查是否正在播放指定 URL
    func isPlaying(url: URL) -> Bool {
        return isPlaying && currentURL == url
    }
    
    // MARK: - Private Methods
    
    private func startProgressTimer() {
        stopProgressTimer()
        
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func updateProgress() {
        guard let player = player else { return }
        
        currentTime = player.currentTime
        progress = duration > 0 ? currentTime / duration : 0
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.progress = 1.0
            self.currentTime = self.duration
            self.stopProgressTimer()
            self.logger.info("✅ Playback finished")
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.logger.error("❌ Decode error: \(error?.localizedDescription ?? "Unknown")")
            self.stop()
        }
    }
}

// MARK: - Errors

enum AudioPlayerError: LocalizedError {
    case playerCreationFailed
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .playerCreationFailed:
            return "无法创建音频播放器"
        case .fileNotFound:
            return "音频文件不存在"
        }
    }
}
