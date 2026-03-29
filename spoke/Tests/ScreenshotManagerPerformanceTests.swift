import Foundation
import Testing
@testable import SpokenAnyWhere

// MARK: - Screenshot Manager Performance Tests

/// 性能测试：ScreenshotManager 纯逻辑路径
/// 测试 JSON encode/decode 性能，不涉及 UI 组件
@Suite("ScreenshotManager Performance Tests")
@MainActor
struct ScreenshotManagerPerformanceTests {

    // MARK: - Fixture Generation

    /// 生成测试用的 ScreenshotItem 数组
    private func generateFixture(count: Int) -> [ScreenshotItem] {
        var items: [ScreenshotItem] = []
        items.reserveCapacity(count)

        for index in 0..<count {
            let frame = CGRect(
                x: 100 + Double(index * 10),
                y: 100,
                width: 800,
                height: 600
            )
            let item = ScreenshotItem(
                id: UUID(),
                imagePath: "/tmp/screenshot_\(index).png",
                frame: frame,
                originalSize: CGSize(width: 800, height: 600),
                isPinned: true,
                isLocked: index % 3 == 0,
                isMarked: index % 5 == 0,
                opacity: 1.0,
                zoomLevel: 1.0,
                appearance: .default,
                screenLocalizedName: "Built-in Retina Display",
                createdAt: Date()
            )
            items.append(item)
        }

        return items
    }

    // MARK: - JSON Encoding Performance

    @Test("JSON Encoding - 10 items")
    func jsonEncoding10Items() throws {
        let items = generateFixture(count: 10)
        let encoder = JSONEncoder()

        // Warmup
        _ = try encoder.encode(items)

        // Measure
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = try encoder.encode(items)
        }
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000

        // Log result
        print("📊 [Perf] JSON Encoding 10 items (100 iterations): \(String(format: "%.2f", duration))ms")

        // Baseline: should complete in reasonable time
        #expect(duration < 1000) // 100 iterations should take < 1s
    }

    @Test("JSON Encoding - 20 items")
    func jsonEncoding20Items() throws {
        let items = generateFixture(count: 20)
        let encoder = JSONEncoder()

        _ = try encoder.encode(items)

        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = try encoder.encode(items)
        }
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000

        print("📊 [Perf] JSON Encoding 20 items (100 iterations): \(String(format: "%.2f", duration))ms")
        #expect(duration < 2000)
    }

    @Test("JSON Encoding - 50 items")
    func jsonEncoding50Items() throws {
        let items = generateFixture(count: 50)
        let encoder = JSONEncoder()

        _ = try encoder.encode(items)

        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = try encoder.encode(items)
        }
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000

        print("📊 [Perf] JSON Encoding 50 items (100 iterations): \(String(format: "%.2f", duration))ms")
        #expect(duration < 5000)
    }

    // MARK: - JSON Decoding Performance

    @Test("JSON Decoding - 10 items")
    func jsonDecoding10Items() throws {
        let items = generateFixture(count: 10)
        let encoder = JSONEncoder()
        let data = try encoder.encode(items)
        let decoder = JSONDecoder()

        // Warmup
        _ = try decoder.decode([ScreenshotItem].self, from: data)

        // Measure
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = try decoder.decode([ScreenshotItem].self, from: data)
        }
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000

        print("📊 [Perf] JSON Decoding 10 items (100 iterations): \(String(format: "%.2f", duration))ms")
        #expect(duration < 1000)
    }

    @Test("JSON Decoding - 20 items")
    func jsonDecoding20Items() throws {
        let items = generateFixture(count: 20)
        let encoder = JSONEncoder()
        let data = try encoder.encode(items)
        let decoder = JSONDecoder()

        _ = try decoder.decode([ScreenshotItem].self, from: data)

        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = try decoder.decode([ScreenshotItem].self, from: data)
        }
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000

        print("📊 [Perf] JSON Decoding 20 items (100 iterations): \(String(format: "%.2f", duration))ms")
        #expect(duration < 2000)
    }

    @Test("JSON Decoding - 50 items")
    func jsonDecoding50Items() throws {
        let items = generateFixture(count: 50)
        let encoder = JSONEncoder()
        let data = try encoder.encode(items)
        let decoder = JSONDecoder()

        _ = try decoder.decode([ScreenshotItem].self, from: data)

        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = try decoder.decode([ScreenshotItem].self, from: data)
        }
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000

        print("📊 [Perf] JSON Decoding 50 items (100 iterations): \(String(format: "%.2f", duration))ms")
        #expect(duration < 5000)
    }

    // MARK: - Round-trip Performance

    @Test("JSON Round-trip - 20 items")
    func jsonRoundtrip20Items() throws {
        let items = generateFixture(count: 20)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Warmup
        let data = try encoder.encode(items)
        _ = try decoder.decode([ScreenshotItem].self, from: data)

        // Measure full round-trip
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<50 {
            let encoded = try encoder.encode(items)
            _ = try decoder.decode([ScreenshotItem].self, from: encoded)
        }
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000

        print("📊 [Perf] JSON Round-trip 20 items (50 iterations): \(String(format: "%.2f", duration))ms")
        #expect(duration < 2000)
    }
}
