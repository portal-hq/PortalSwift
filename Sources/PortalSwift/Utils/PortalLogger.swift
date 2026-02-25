import Foundation
import os.log

/// Controls the verbosity of the PortalSwift SDK logging output.
///
/// Each level includes everything above it in the hierarchy:
/// - `.none`  — **default**, no logs emitted.
/// - `.error` — only things that broke (failed transactions, network failures, binary crashes).
/// - `.warn`  — something is off but not broken (deprecated method usage, retry attempts, slow responses).
/// - `.info`  — normal operational milestones (signing started, share generated, connection established).
/// - `.debug` — everything, including internals (request/response payloads, timing, state transitions).
public enum PortalLogLevel: Int, Comparable {
  /// No logs emitted. This is the default.
  case none = 0
  /// Only things that broke (failed transactions, network failures, binary crashes).
  case error = 1
  /// Something is off but not broken (deprecated method usage, retry attempts, slow responses).
  case warn = 2
  /// Normal operational milestones (signing started, share generated, connection established).
  case info = 3
  /// Everything, including internals (request/response payloads, timing, state transitions).
  case debug = 4

  public static func < (lhs: PortalLogLevel, rhs: PortalLogLevel) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

protocol PortalLoggerProtocol {
  var logLevel: PortalLogLevel { get }
  func setLogLevel(_ level: PortalLogLevel)
  func debug(_ message: String)
  func info(_ message: String)
  func warn(_ message: String)
  func error(_ message: String)
}

class PortalLogger: PortalLoggerProtocol {
  static let shared = PortalLogger()

  private let osLog = OSLog(subsystem: "io.portalhq.ios", category: "General")
  private let lock = NSLock()
  private var _logLevel: PortalLogLevel = .none

  private init() {}

  var logLevel: PortalLogLevel {
    lock.lock()
    defer { lock.unlock() }
    return _logLevel
  }

  func setLogLevel(_ level: PortalLogLevel) {
    lock.lock()
    defer { lock.unlock() }
    _logLevel = level
  }

  func debug(_ message: String) {
    guard logLevel >= .debug else { return }
    os_log("%{public}@", log: osLog, type: .debug, message)
  }

  func info(_ message: String) {
    guard logLevel >= .info else { return }
    os_log("%{public}@", log: osLog, type: .info, message)
  }

  func warn(_ message: String) {
    guard logLevel >= .warn else { return }
    os_log("%{public}@", log: osLog, type: .default, message)
  }

  func error(_ message: String) {
    guard logLevel >= .error else { return }
    os_log("%{public}@", log: osLog, type: .error, message)
  }
}
