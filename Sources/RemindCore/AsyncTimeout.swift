import Foundation

enum AsyncTimeout {
  typealias Cancellation = @Sendable () -> Void

  final class Completion<Value: Sendable>: @unchecked Sendable {
    private let state: AsyncTimeoutState<Value>

    fileprivate init(state: AsyncTimeoutState<Value>) {
      self.state = state
    }

    /// Claim the operation result before doing synchronous result conversion.
    func claim() -> Claim<Value>? {
      state.claim() ? Claim(state: state) : nil
    }

    func resume(with result: Result<Value, any Error>) {
      claim()?.resume(with: result)
    }

    func resume(returning value: Value) {
      resume(with: .success(value))
    }

    func resume(throwing error: any Error) {
      resume(with: .failure(error))
    }
  }

  struct Claim<Value: Sendable>: @unchecked Sendable {
    private let state: AsyncTimeoutState<Value>

    fileprivate init(state: AsyncTimeoutState<Value>) {
      self.state = state
    }

    func resume(with result: Result<Value, any Error>) {
      state.finish(with: result)
    }

    func resume(returning value: Value) {
      resume(with: .success(value))
    }

    func resume(throwing error: any Error) {
      resume(with: .failure(error))
    }
  }

  static func withTimeout<Value: Sendable>(
    after duration: Duration,
    timeoutError: RemindCoreError,
    start: @Sendable (Completion<Value>) -> Cancellation?
  ) async throws -> Value {
    let state = AsyncTimeoutState<Value>()

    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        state.install(continuation)
        state.installCancellation(start(Completion(state: state)))

        let timeoutTask = Task {
          do {
            try await Task.sleep(for: duration)
          } catch {
            return
          }
          state.timeout(with: timeoutError)
        }
        state.installTimeoutTask(timeoutTask)
      }
    } onCancel: {
      state.cancel()
    }
  }
}

private final class AsyncTimeoutState<Value: Sendable>: @unchecked Sendable {
  private enum Phase {
    case waiting
    case claimed
    case finished
  }

  private let lock = NSLock()
  private var phase = Phase.waiting
  private var continuation: CheckedContinuation<Value, any Error>?
  private var pendingResult: Result<Value, any Error>?
  private var timeoutTask: Task<Void, Never>?
  private var cancellation: AsyncTimeout.Cancellation?
  private var shouldCancelOperation = false

  func install(_ continuation: CheckedContinuation<Value, any Error>) {
    let pendingResult = lock.withLock { () -> Result<Value, any Error>? in
      guard let pendingResult = self.pendingResult else {
        self.continuation = continuation
        return nil
      }
      self.pendingResult = nil
      return pendingResult
    }
    if let pendingResult {
      continuation.resume(with: pendingResult)
    }
  }

  func installCancellation(_ cancellation: AsyncTimeout.Cancellation?) {
    let cancellationToRun = lock.withLock {
      guard phase != .finished else {
        return shouldCancelOperation ? cancellation : nil
      }
      self.cancellation = cancellation
      return nil
    }
    cancellationToRun?()
  }

  func installTimeoutTask(_ timeoutTask: Task<Void, Never>) {
    let shouldCancel = lock.withLock {
      guard phase == .waiting else { return true }
      self.timeoutTask = timeoutTask
      return false
    }
    if shouldCancel {
      timeoutTask.cancel()
    }
  }

  func claim() -> Bool {
    let outcome = lock.withLock { () -> (Bool, Task<Void, Never>?) in
      guard phase == .waiting else { return (false, nil) }
      phase = .claimed
      let pending = self.timeoutTask
      self.timeoutTask = nil
      return (true, pending)
    }
    guard outcome.0 else { return false }
    outcome.1?.cancel()
    return true
  }

  func finish(with result: Result<Value, any Error>) {
    let continuation = lock.withLock {
      guard phase == .claimed else { return nil as CheckedContinuation<Value, any Error>? }
      phase = .finished
      cancellation = nil
      if let continuation = self.continuation {
        self.continuation = nil
        return continuation
      }
      pendingResult = result
      return nil
    }
    continuation?.resume(with: result)
  }

  func timeout(with error: RemindCoreError) {
    abort(with: .failure(error))
  }

  func cancel() {
    abort(with: .failure(CancellationError()))
  }

  private func abort(with result: Result<Value, any Error>) {
    let outcome = lock.withLock {
      () -> (
        CheckedContinuation<Value, any Error>?, AsyncTimeout.Cancellation?, Task<Void, Never>?
      )? in
      guard phase == .waiting else { return nil }
      phase = .finished
      shouldCancelOperation = true
      let continuation = self.continuation
      self.continuation = nil
      if continuation == nil {
        pendingResult = result
      }
      let cancellation = self.cancellation
      self.cancellation = nil
      let timeoutTask = self.timeoutTask
      self.timeoutTask = nil
      return (continuation, cancellation, timeoutTask)
    }
    guard let outcome else { return }
    outcome.2?.cancel()
    outcome.1?()
    outcome.0?.resume(with: result)
  }
}
