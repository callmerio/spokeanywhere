import Foundation

func runMicrophoneTesterOnMain(
    _ tester: MicrophoneTester?,
    level: Float
) {
    runtimeRunOnMain(owner: tester) { owner in
        owner.level = level
    }
}
