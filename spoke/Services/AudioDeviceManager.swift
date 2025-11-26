import Foundation
import AVFoundation
import CoreAudio

@MainActor
class AudioDeviceManager: ObservableObject {
    @Published var devices: [AudioDevice] = []
    @Published var currentInputDeviceId: String? {
        didSet {
            if let id = currentInputDeviceId {
                UserDefaults.standard.set(id, forKey: "SelectedMicrophoneId")
            }
        }
    }
    
    struct AudioDevice: Identifiable, Hashable {
        let id: String
        let name: String
    }
    
    init() {
        self.currentInputDeviceId = UserDefaults.standard.string(forKey: "SelectedMicrophoneId")
        refreshDevices()
        
        // 监听设备变化
        // 在实际应用中，应该监听 CoreAudio 的属性变化，这里简化为每次出现 Settings 时刷新
    }
    
    func refreshDevices() {
        var newDevices: [AudioDevice] = []
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        
        for device in discoverySession.devices {
            newDevices.append(AudioDevice(id: device.uniqueID, name: device.localizedName))
        }
        
        self.devices = newDevices
        
        // 如果没有选中的设备，或者选中的设备不存在了，选择第一个
        if currentInputDeviceId == nil || !newDevices.contains(where: { $0.id == currentInputDeviceId }) {
            currentInputDeviceId = newDevices.first?.id
        }
    }
}
