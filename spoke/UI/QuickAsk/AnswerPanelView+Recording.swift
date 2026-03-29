import SwiftUI

extension AnswerPanelView {
    // MARK: - Recording Waveform
    
    /// 录音波纹动画（红色风格）
    var recordingWaveform: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .opacity(isRecording ? 1 : 0.5)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRecording)
            
            Text("Recording")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
            
            Spacer()
            
            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { index in
                    let level = audioLevels[index % audioLevels.count]
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 2, height: CGFloat(level) * 16 + 4)
                        .animation(.easeInOut(duration: 0.1), value: level)
                }
            }
            .frame(height: 24)
            
            Spacer()
            
            Button(action: { toggleRecording() }, label: {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.red)
            })
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .frame(height: 32)
        .onAppear {
            startWaveformAnimation()
        }
        .onDisappear {
            stopWaveformAnimation()
        }
    }
    
    // MARK: - Recording Actions
    
    func toggleRecording() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isRecording.toggle()
        }
        
        if isRecording {
            startWaveformAnimation()
        } else {
            stopWaveformAnimation()
        }
    }
    
    func startWaveformAnimation() {
        runAnswerPanelRecordingWaveform(
            isRecording: { isRecording }
        ) { levels in
            withAnimation(.easeInOut(duration: 0.1)) {
                self.audioLevels = levels
            }
        }
    }
    
    func stopWaveformAnimation() {
        audioLevels = Array(repeating: 0.05, count: 40)
    }
}
