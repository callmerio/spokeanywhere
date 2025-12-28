import AVFoundation
import Combine

class MicrophoneTester: ObservableObject {
    @Published var level: Float = 0
    @Published var isRunning = false
    
    private var audioEngine: AVAudioEngine?
    
    func start() {
        guard !isRunning else { return }
        
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }
        
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }
        
        do {
            try engine.start()
            isRunning = true
        } catch {
            print("❌ Failed to start audio engine: \(error)")
        }
    }
    
    func stop() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRunning = false
        level = 0
    }
    
    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        var sumSquares: Float = 0
        
        for i in stride(from: 0, to: frameLength, by: 4) {
            let sample = channelData[i]
            sumSquares += sample * sample
        }
        
        let rms = sqrt(sumSquares / Float(frameLength / 4))
        let newLevel = min((rms * 5.0) + (sqrt(rms) * 2.0), 1.0)
        
        Task { @MainActor in
            self.level = newLevel
        }
    }
}
