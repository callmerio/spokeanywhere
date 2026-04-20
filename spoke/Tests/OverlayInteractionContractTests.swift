import Testing
@testable import SpokenAnyWhere

@Suite("OverlayInteractionContract tests")
@MainActor
struct OverlayInteractionContractTests {
    @Test("shared overlay opacity bounds use 0.05 minimum and 1.0 maximum")
    func sharedOpacityBoundsUseExpectedRange() {
        #expect(OverlayInteractionContract.minimumOpacity == 0.05)
        #expect(OverlayInteractionContract.maximumOpacity == 1.0)
    }

    @Test("shared overlay horizontal opacity sensitivity is available to both surfaces")
    func sharedHorizontalOpacitySensitivityExists() {
        #expect(OverlayInteractionContract.horizontalOpacitySensitivity > 0)
    }
}
