import Testing
@testable import SpokenAnyWhere

@Suite("PinnedTextZoomDynamics tests")
@MainActor
struct PinnedTextZoomDynamicsTests {
    @Test("ingest accumulates wheel intent into velocity")
    func ingestAccumulatesWheelIntentIntoVelocity() {
        var dynamics = PinnedTextZoomDynamics()
        dynamics.ingest(stepDelta: 0.05)
        let firstVelocity = dynamics.velocity
        dynamics.ingest(stepDelta: 0.05)

        #expect(firstVelocity > 0)
        #expect(dynamics.velocity > firstVelocity)
        #expect(dynamics.velocity < 0.05)
    }

    @Test("nextDecayStep decays velocity to rest")
    func nextDecayStepDecaysVelocityToRest() {
        var dynamics = PinnedTextZoomDynamics()
        dynamics.ingest(stepDelta: 0.08)

        var values: [Double] = []
        while let next = dynamics.nextDecayStep() {
            values.append(next)
        }

        #expect(values.isEmpty == false)
        #expect(abs(dynamics.velocity) <= 0.002)
    }
}
