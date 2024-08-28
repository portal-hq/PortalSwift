import Foundation
import os.log

protocol PortalLoggerProtocol {
  func debug(_ message: String)
  func error(_ message: String)
  func info(_ message: String)
  func log(_ message: String)
}

class PortalLogger: PortalLoggerProtocol {
  private let logger = OSLog(subsystem: "io.portalhq.ios", category: "General")

  func debug(_ message: String) {
    os_log("%{public}@", log: self.logger, type: .debug, message)
  }

  func error(_ message: String) {
    os_log("%{public}@", log: self.logger, type: .error, message)
  }

  func info(_ message: String) {
    os_log("%{public}@", log: self.logger, type: .info, message)
  }

  func log(_ message: String) {
    os_log("%{public}@", log: self.logger, type: .info, message)
  }
}
