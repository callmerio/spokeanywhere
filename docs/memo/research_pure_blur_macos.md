# macOS Pure Blur Implementation Research

> **Date:** 2025-12-02 → 2025-12-03 (Updated)
> **Objective:** Achieve a "Pure Gaussian Blur" background (similar to Spotlight or Raycast) without the standard color tint/overlay of `NSVisualEffectView`.
> **Status:** ✅ **SUCCESS** - ScreenCaptureKit + SwiftUI `.blur()` 方案

## 1. The Goal

We wanted a window background that:

1.  Blurs the content behind the window (Desktop/Other Apps).
2.  Has **Zero Tint** (no white/gray/black overlay).
3.  Has **Zero Saturation Boost** (unlike `.sidebar` or `.headerView` materials).

## 2. Attempted Methods

### Method A: The "Forbidden Spell" (`CABackdropLayer`)

This is the underlying Core Animation layer that `NSVisualEffectView` uses. We tried to instantiate it directly using `NSClassFromString("CABackdropLayer")`.

**The Code:**

```swift
let layer = NSClassFromString("CABackdropLayer")!.init() as! CALayer
layer.setValue(true, forKey: "windowServerAware") // Crucial for sampling screen
layer.filters = [gaussianBlurFilter]
```

**Why it failed:**

- **Symptom:** The view remained either completely transparent (showing the desktop clearly) or black.
- **Analysis:** `CABackdropLayer` requires a very specific connection to the WindowServer. In modern macOS (Sonoma+), simply setting `windowServerAware` seems insufficient for a sandboxed app or a standard `NSWindow`. It likely requires specific entitlements or window configurations that are undocumented.

### Method B: The "Surgical Strike" (Hacking `NSVisualEffectView`)

We tried to use a standard `NSVisualEffectView` (which we know samples the screen correctly) and then "remove" the tint layer.

**The Code:**

```swift
// Inside layout() or viewDidMoveToWindow()
for sublayer in layer?.sublayers ?? [] {
    if String(describing: type(of: sublayer)).contains("Backdrop") {
        // Keep this one
    } else {
        // Hide tint layers
        sublayer.isHidden = true
        sublayer.opacity = 0
    }
}
```

**Why it failed:**

- **Symptom:** No visible change, or the blur disappeared along with the tint.
- **Analysis:** `NSVisualEffectView` aggressively manages its layer hierarchy. It likely resets the visibility of its sublayers on every layout pass or state change. Fighting the framework here is a losing battle.

### Method C: The "Filter Injection"

We tried to force a custom `CAFilter` onto the `NSVisualEffectView`'s layer to override the system filters.

**The Code:**

```swift
let blurFilter = NSClassFromString("CAFilter")!.init()
blurFilter.setValue("gaussianBlur", forKey: "name")
blurFilter.setValue(30, forKey: "inputRadius")
layer.filters = [blurFilter]
```

**Why it failed:**

- **Symptom:** `NSVisualEffectView` ignores custom filters or they conflict with its internal material rendering pipeline.

## 3. The Reliable Fallback

We settled on using **`NSVisualEffectView`** with **`.hudWindow`** material.

```swift
let view = NSVisualEffectView()
view.material = .hudWindow // Dark, high blur, designed for HUDs
view.blendingMode = .behindWindow
view.state = .active
```

**Verdict:**

- **Pros:** 100% Stable, Native, No Private APIs (Safe for App Store).
- **Cons:** Has a slight dark tint (it's not perfectly clear).
- **Recommendation:** Unless you are willing to use extremely fragile private APIs (like `CGSSetWindowBackgroundBlurRadius`), stick to `NSVisualEffectView`. For a "lighter" blur, try `.underWindowBackground` or `.contentBackground`, but they often come with vibrancy (color shifting).

## 4. ✅ The Winning Solution (2025-12-03)

We finally achieved pure blur using **ScreenCaptureKit + SwiftUI `.blur()`**!

### Method D: ScreenCaptureKit + SwiftUI Native Blur

**The Code:**

```swift
// 1. Service: 输出原始帧（不做模糊）
func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
        DispatchQueue.main.async { self.currentFrame = cgImage }
    }
}

// 2. View: SwiftUI 原生 GPU 模糊
Image(nsImage: nsImage)
    .resizable()
    .aspectRatio(contentMode: .fill)
    .blur(radius: 20)  // 🎯 GPU 加速！
    .clipShape(RoundedRectangle(cornerRadius: 16))
```

**Why it works:**

- ScreenCaptureKit 提供 App Store 安全的屏幕捕获
- 可以排除自身窗口（`excludingApplications`）避免无限镜
- SwiftUI `.blur(radius:)` 由 GPU 渲染，支持浮点半径，自动插值
- 代码极简，比 CoreImage 或 Metal 方案少 100+ 行

**Verdict:**

- ✅ **App Store Safe** - 无私有 API
- ✅ **Pure Blur** - 无系统色调
- ✅ **GPU Accelerated** - 零 CPU 负担
- ✅ **Animation Friendly** - 支持 `.animation()` 丝滑过渡
- ⚠️ **macOS 12.3+** - 需要 ScreenCaptureKit，老系统需 fallback

**Files:**

- `spoke/UI/Components/ScreenCaptureBlurBackground.swift`
- `spoke/Services/ScreenCaptureBlurService.swift`
