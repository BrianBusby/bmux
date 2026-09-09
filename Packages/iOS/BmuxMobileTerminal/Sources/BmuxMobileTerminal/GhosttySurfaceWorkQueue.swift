import Foundation
import GhosttyKit

/// Owns the serial libghostty work queue for one surface generation.
/// All mutable state is accessed only from `queue`; main-actor code replaces whole instances on recovery.
final class GhosttySurfaceWorkQueue: @unchecked Sendable {
    let queue: DispatchQueue
    #if DEBUG
    /// Accessed only from ``queue`` while producing DEBUG accessibility snapshots.
    var lastAccessibilityTextTime: CFTimeInterval = 0
    #endif

    init(generation: UInt64) {
        // carve-out justification: serial event-delivery queue for low-level libghostty C calls; not used as a lock.
        queue = DispatchQueue(
            label: "dev.bmux.GhosttySurfaceView.output.\(generation)",
            qos: .userInitiated
        )
    }

    func async(_ work: @escaping @Sendable () -> Void) {
        queue.async(execute: work)
    }

    func async(
        surface: ghostty_surface_t,
        _ work: @escaping @Sendable (GhosttySurfaceHandle) -> Void
    ) {
        let handle = GhosttySurfaceHandle(surface: surface)
        queue.async { work(handle) }
    }
}

/// Surface pointer payload captured by the off-main output queue.
///
/// The C surface pointer is dereferenced only on `GhosttySurfaceWorkQueue`,
/// which is the same FIFO queue that owns `process_output` and surface free.
struct GhosttySurfaceHandle: @unchecked Sendable {
    let surface: ghostty_surface_t
}
