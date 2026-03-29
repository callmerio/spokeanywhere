import Foundation

func runAnswerPanelRecordingWaveform(
    isRecording: @escaping @MainActor () -> Bool,
    updateLevels: @escaping @MainActor ([Float]) -> Void
) {
    Task { @MainActor in
        while isRecording() {
            updateLevels(Array(repeating: 0, count: 40).map { _ in Float.random(in: 0.1...1.0) })
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
}
