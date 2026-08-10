import Foundation
import Testing

@testable import RemindCore

private final class TestSignal: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Void, Never>?
  private var isRaised = false

  var raised: Bool {
    lock.withLock { isRaised }
  }

  func wait() async {
    await withCheckedContinuation { continuation in
      let resumeImmediately = lock.withLock {
        if isRaised {
          return true
        }
        self.continuation = continuation
        return false
      }
      if resumeImmediately {
        continuation.resume()
      }
    }
  }

  func raise() {
    let continuation = lock.withLock {
      isRaised = true
      let pending = self.continuation
      self.continuation = nil
      return pending
    }
    continuation?.resume()
  }
}

struct AsyncTimeoutTests {
  @Test("Returns when the operation finishes before the deadline")
  func operationWins() async throws {
    let cancelled = TestSignal()
    let value = try await AsyncTimeout.withTimeout(
      after: .seconds(1),
      timeoutError: .operationFailed("timed out")
    ) { completion in
      completion.resume(returning: "ok")
      return { cancelled.raise() }
    }

    #expect(value == "ok")
    #expect(!cancelled.raised)
  }

  @Test("Cancels the operation and returns when the deadline wins")
  func deadlineWins() async {
    let cancelled = TestSignal()

    await #expect(throws: RemindCoreError.operationFailed("timed out")) {
      try await AsyncTimeout.withTimeout(
        after: .milliseconds(20),
        timeoutError: .operationFailed("timed out")
      ) { _ in
        { cancelled.raise() }
      } as String
    }

    #expect(cancelled.raised)
  }

  @Test("A claimed callback remains successful while it converts its result")
  func claimedCallbackWinsBeforeConversion() async throws {
    let cancelled = TestSignal()
    let value: String = try await AsyncTimeout.withTimeout(
      after: .milliseconds(20),
      timeoutError: .operationFailed("timed out")
    ) { completion in
      let claim = completion.claim()
      Task {
        try await Task.sleep(for: .milliseconds(50))
        claim?.resume(returning: "converted")
      }
      return { cancelled.raise() }
    }

    #expect(value == "converted")
    #expect(!cancelled.raised)
  }

  @Test("Caller cancellation cancels the operation")
  func callerCancellation() async {
    let started = TestSignal()
    let cancelled = TestSignal()
    let task = Task {
      try await AsyncTimeout.withTimeout(
        after: .seconds(10),
        timeoutError: .operationFailed("timed out")
      ) { _ in
        started.raise()
        return { cancelled.raise() }
      } as String
    }

    await started.wait()
    task.cancel()
    await #expect(throws: CancellationError.self) {
      try await task.value
    }
    #expect(cancelled.raised)
  }

  @Test("Late operation results are ignored after the deadline")
  func lateResultIsIgnored() async {
    let released = TestSignal()

    await #expect(throws: RemindCoreError.operationFailed("timed out")) {
      try await AsyncTimeout.withTimeout(
        after: .milliseconds(20),
        timeoutError: .operationFailed("timed out")
      ) { completion in
        Task {
          await released.wait()
          completion.resume(returning: "late")
        }
        return { released.raise() }
      } as String
    }
  }
}
