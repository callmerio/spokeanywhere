import SwiftUI
import AppKit

// MARK: - NSVisualEffectView Wrapper

/// 🔮 系统原生毛玻璃背景
/// 最稳定可靠的模糊方案，Raycast/Spotlight 同款
struct VisualEffectBlur: NSViewRepresentable {
    
    /// 材质类型
    var material: NSVisualEffectView.Material = .hudWindow
    
    /// 混合模式
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    
    /// 圆角半径
    var cornerRadius: CGFloat = 16
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.layer?.cornerRadius = cornerRadius
    }
}

// MARK: - Convenience Modifiers

extension View {
    /// 应用系统原生毛玻璃背景
    /// - Parameters:
    ///   - material: 材质类型 (默认 .hudWindow 深色高模糊)
    ///   - cornerRadius: 圆角半径
    func visualEffectBackground(
        material: NSVisualEffectView.Material = .hudWindow,
        cornerRadius: CGFloat = 16
    ) -> some View {
        self.background(
            VisualEffectBlur(
                material: material,
                cornerRadius: cornerRadius
            )
        )
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Text("Hello Visual Effect!")
            .font(.title)
            .foregroundColor(.white)
    }
    .frame(width: 300, height: 200)
    .visualEffectBackground(material: .hudWindow, cornerRadius: 16)
}
