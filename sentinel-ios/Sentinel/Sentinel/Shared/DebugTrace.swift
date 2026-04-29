import Foundation
import SentinelCore

nonisolated func debugTrace(_ message: @autoclosure () -> String) {
#if DEBUG
    let timestamp = ISO8601DateFormatter().string(from: Date())
    print("[Sentinel][\(timestamp)] \(message())")
#endif
}
