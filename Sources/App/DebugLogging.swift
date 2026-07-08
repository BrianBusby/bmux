#if DEBUG
import BMUXDebugLog

@inline(__always)
func bmuxDebugLog(_ message: @autoclosure () -> String) {
    BMUXDebugLog.logDebugEvent(message())
}
#endif
