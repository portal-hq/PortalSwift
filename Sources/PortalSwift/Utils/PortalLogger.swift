import Foundation
import os.log

public enum PortalLogLevel: Int, Comparable {
  case none = 0
  case error = 1
  case warn = 2
  case info = 3
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
