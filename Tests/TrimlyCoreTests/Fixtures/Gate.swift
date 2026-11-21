/// Lets a test pause a provider call deterministically: the call blocks in `enterAndWait()` until `release()`.
actor Gate {
    private var entered = false
    private var released = false
    private var enterWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func enterAndWait() async {
        entered = true
        enterWaiters.forEach { $0.resume() }
        enterWaiters = []
        guard released == false else { return }
        await withCheckedContinuation { releaseWaiters.append($0) }
    }

    func waitUntilEntered() async {
        guard entered == false else { return }
        await withCheckedContinuation { enterWaiters.append($0) }
    }

    func release() {
        released = true
        releaseWaiters.forEach { $0.resume() }
        releaseWaiters = []
    }
}
