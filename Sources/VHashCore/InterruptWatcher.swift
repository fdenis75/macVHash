import Darwin
import Dispatch
import os

/// Turns the first SIGINT into a cancellation callback; a second SIGINT exits immediately with 130.
final class InterruptWatcher: Sendable {
    private let source: any DispatchSourceSignal
    private let state = OSAllocatedUnfairLock(initialState: false)

    init(onInterrupt: @escaping @Sendable () -> Void) {
        signal(SIGINT, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
        self.source = source
        let state = state
        source.setEventHandler {
            let alreadyInterrupted = state.withLock { flag -> Bool in
                let previous = flag
                flag = true
                return previous
            }
            if alreadyInterrupted { _exit(130) }
            onInterrupt()
        }
        source.resume()
    }

    /// Stops watching and reports whether SIGINT was received.
    func finish() -> Bool {
        source.cancel()
        signal(SIGINT, SIG_DFL)
        return state.withLock { $0 }
    }
}
