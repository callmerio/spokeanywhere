import Foundation

@MainActor
struct PinnedTextZoomDynamics {
    private(set) var velocity: Double = 0

    mutating func ingest(stepDelta: Double) {
        velocity = (velocity * 0.75) + (stepDelta * 0.25)
    }

    mutating func nextDecayStep() -> Double? {
        guard abs(velocity) >= 0.001 else {
            velocity = 0
            return nil
        }

        let step = velocity
        velocity *= 0.72
        return step
    }

    mutating func reset() {
        velocity = 0
    }
}
