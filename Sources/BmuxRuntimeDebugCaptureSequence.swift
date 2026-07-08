import Foundation

actor BmuxRuntimeDebugCaptureSequence {
    private var sequence = 0

    func next() -> Int {
        sequence += 1
        return sequence
    }
}
