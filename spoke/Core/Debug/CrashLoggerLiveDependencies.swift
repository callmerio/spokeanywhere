import Foundation

@MainActor
func currentCrashLogger() -> CrashLogger {
    CrashLogger.shared
}
