import AppKit
import Testing
@testable import SpokenAnyWhere

@Suite("Screenshot 标注模型测试")
@MainActor
struct AnnotationModelTests {
    @Test("TextAnnotation style round-trips font size, color, and opacity")
    func textAnnotationStyleRoundTrips() {
        let annotation = TextAnnotation(position: CGPoint(x: 24, y: 32), text: "Hello")
        annotation.style = TextAnnotationStyle(
            fontSize: 28,
            color: .systemYellow,
            opacity: 0.55
        )

        #expect(annotation.style.fontSize == 28)
        #expect(annotation.style.color == .systemYellow)
        #expect(annotation.style.opacity == 0.55)
        #expect(annotation.boundingRect().width > 0)
    }

    @Test("PenAnnotation hitTest includes the middle of a stroke segment")
    func penHitTestUsesSegments() {
        let annotation = PenAnnotation(
            points: [CGPoint(x: 10, y: 10), CGPoint(x: 110, y: 10)],
            color: .systemRed,
            lineWidth: 8
        )

        #expect(annotation.hitTest(point: CGPoint(x: 60, y: 12)))
        #expect(!annotation.hitTest(point: CGPoint(x: 60, y: 40)))
    }

    @Test("MarkerAnnotation hitTest includes the middle of a stroke segment")
    func markerHitTestUsesSegments() {
        let annotation = MarkerAnnotation(
            points: [CGPoint(x: 20, y: 20), CGPoint(x: 20, y: 120)],
            color: .systemYellow,
            lineWidth: 24
        )

        #expect(annotation.hitTest(point: CGPoint(x: 18, y: 70)))
        #expect(!annotation.hitTest(point: CGPoint(x: 60, y: 70)))
    }
}
