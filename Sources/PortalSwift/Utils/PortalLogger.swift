import Foundation
import os.log

class PortalLogger {
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
