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

    @Test("TextAnnotation style clamps opacity below lower bound")
    func textAnnotationStyleClampsLowOpacity() {
        let annotation = TextAnnotation(position: CGPoint(x: 24, y: 32), text: "Hello")
        annotation.style = TextAnnotationStyle(
            fontSize: 20,
            color: .systemBlue,
            opacity: 0.1
        )

        #expect(annotation.style.opacity == 0.3)
    }

    @Test("TextAnnotation style clamps opacity above upper bound")
    func textAnnotationStyleClampsHighOpacity() {
        let annotation = TextAnnotation(position: CGPoint(x: 24, y: 32), text: "Hello")
        annotation.style = TextAnnotationStyle(
            fontSize: 20,
            color: .systemBlue,
            opacity: 1.5
        )

        #expect(annotation.style.opacity == 1.0)
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

    @Test("PenAnnotation hitTest covers a single-point stroke")
    func penHitTestForSinglePointStroke() {
        let annotation = PenAnnotation(
            points: [CGPoint(x: 40, y: 40)],
            color: .systemRed,
            lineWidth: 10
        )

        #expect(annotation.hitTest(point: CGPoint(x: 44, y: 43)))
        #expect(!annotation.hitTest(point: CGPoint(x: 70, y: 70)))
    }

    @Test("PenAnnotation hitTest covers the middle segment of a bent stroke")
    func penHitTestForBentStrokeMiddleSegment() {
        let annotation = PenAnnotation(
            points: [
                CGPoint(x: 20, y: 20),
                CGPoint(x: 80, y: 20),
                CGPoint(x: 80, y: 100)
            ],
            color: .systemRed,
            lineWidth: 8
        )

        #expect(annotation.hitTest(point: CGPoint(x: 82, y: 60)))
        #expect(!annotation.hitTest(point: CGPoint(x: 40, y: 60)))
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

    @Test("MarkerAnnotation hitTest covers a single-point stroke")
    func markerHitTestForSinglePointStroke() {
        let annotation = MarkerAnnotation(
            points: [CGPoint(x: 50, y: 50)],
            color: .systemYellow,
            lineWidth: 24
        )

        #expect(annotation.hitTest(point: CGPoint(x: 56, y: 54)))
        #expect(!annotation.hitTest(point: CGPoint(x: 90, y: 90)))
    }

    @Test("MarkerAnnotation hitTest covers the middle segment of a bent stroke")
    func markerHitTestForBentStrokeMiddleSegment() {
        let annotation = MarkerAnnotation(
            points: [
                CGPoint(x: 30, y: 30),
                CGPoint(x: 120, y: 30),
                CGPoint(x: 120, y: 130)
            ],
            color: .systemYellow,
            lineWidth: 24
        )

        #expect(annotation.hitTest(point: CGPoint(x: 126, y: 80)))
        #expect(!annotation.hitTest(point: CGPoint(x: 70, y: 80)))
    }
}
