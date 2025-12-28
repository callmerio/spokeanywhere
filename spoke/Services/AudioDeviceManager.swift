import AVFoundation
import CoreAudio
import Foundation

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
    
    // MARK: - CoreAudio Device ID Conversion
    
    /// 将设备 UID (String) 转换为 AudioDeviceID (UInt32)
    /// 用于 AVAudioEngine 显式绑定输入设备
    static func getAudioDeviceID(fromUID uid: String) -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // 使用 withUnsafePointer 安全传递 CFString
        var uidCF: CFString = uid as CFString
        let status = withUnsafePointer(to: &uidCF) { uidPtr in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                UInt32(MemoryLayout<CFString>.size),
                uidPtr,
                &size,
                &deviceID
            )
        }
        
        guard status == noErr, deviceID != 0 else {
            return nil
        }
        
        return deviceID
    }
    
    /// 获取当前选中设备的 AudioDeviceID
    /// 若设备不存在则返回 nil (调用方应 fallback 到系统默认)
    static func getSelectedAudioDeviceID() -> AudioDeviceID? {
        guard let uid = UserDefaults.standard.string(forKey: "SelectedMicrophoneId") else {
            return nil
        }
        return getAudioDeviceID(fromUID: uid)
    }
}
