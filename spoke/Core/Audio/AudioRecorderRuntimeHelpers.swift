import AVFoundation
import Foundation

func runAudioRecorderOnMain(
    _ service: AudioRecorderService?,
    _ action: @escaping @MainActor (AudioRecorderService) -> Void
) {
    runtimeRunOnMain(owner: service, action)
}

func runAudioRecorderAsync(
    _ service: AudioRecorderService?,
    _ action: @escaping @MainActor (AudioRecorderService) async -> Void
) {
    runtimeRunOnMainAsync(owner: service, action)
}

func makeAudioConfigurationObserver(
    audioEngine: AVAudioEngine,
    owner: AudioRecorderService?,
    notificationCenter: NotificationCenter = .default,
    onChange: @escaping @MainActor (AudioRecorderService) -> Void
) -> NSObjectProtocol {
    notificationCenter.addObserver(
        forName: .AVAudioEngineConfigurationChange,
        object: audioEngine,
        queue: .main
    ) { _ in
        runAudioRecorderOnMain(owner, onChange)
    }
}

func removeAudioConfigurationObserver(
    _ observer: NSObjectProtocol,
    notificationCenter: NotificationCenter = .default
) {
    notificationCenter.removeObserver(observer)
}

func scheduleAudioConfigurationChange(
    _ workItem: DispatchWorkItem,
    delaySeconds: Double = 0.5
) {
    runtimeRunOnMain(after: delaySeconds) {
        guard !workItem.isCancelled else { return }
        workItem.perform()
    }
}
