//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  FrameCollector.swift
//  Starscream
//
//  Created by Dalton Cherry on 1/24/19.
//  Copyright © 2019 Vluxe. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

import Foundation

public protocol FrameCollectorDelegate: AnyObject {
  func didForm(event: FrameCollector.Event)
  func decompress(data: Data, isFinal: Bool) -> Data?
}

public class FrameCollector {
  public enum Event {
    case text(String)
    case binary(Data)
    case pong(Data?)
    case ping(Data?)
    case error(Error)
    case closed(String, UInt16)
  }

  weak var delegate: FrameCollectorDelegate?
  var buffer = Data()
  var frameCount = 0
  var isText = false // was the first frame a text frame or a binary frame?
  var needsDecompression = false

  public func add(frame: Frame) {
    // check single frame action and out of order frames
    if frame.opcode == .connectionClose {
      var code = frame.closeCode
      var reason = "connection closed by server"
      if let customCloseReason = String(data: frame.payload, encoding: .utf8) {
        reason = customCloseReason
      } else {
        code = CloseCode.protocolError.rawValue
      }
      self.delegate?.didForm(event: .closed(reason, code))
      return
    } else if frame.opcode == .pong {
      self.delegate?.didForm(event: .pong(frame.payload))
      return
    } else if frame.opcode == .ping {
      self.delegate?.didForm(event: .ping(frame.payload))
      return
    } else if frame.opcode == .continueFrame, self.frameCount == 0 {
      let errCode = CloseCode.protocolError.rawValue
      self.delegate?.didForm(event: .error(WSError(type: .protocolError, message: "first frame can't be a continue frame", code: errCode)))
      self.reset()
      return
    } else if self.frameCount > 0, frame.opcode != .continueFrame {
      let errCode = CloseCode.protocolError.rawValue
      self.delegate?.didForm(event: .error(WSError(type: .protocolError, message: "second and beyond of fragment message must be a continue frame", code: errCode)))
      self.reset()
      return
    }
    if self.frameCount == 0 {
      self.isText = frame.opcode == .textFrame
      self.needsDecompression = frame.needsDecompression
    }

    let payload: Data
    if self.needsDecompression {
      payload = self.delegate?.decompress(data: frame.payload, isFinal: frame.isFin) ?? frame.payload
    } else {
      payload = frame.payload
    }
    self.buffer.append(payload)
    self.frameCount += 1

    if frame.isFin {
      if self.isText {
        if let string = String(data: buffer, encoding: .utf8) {
          self.delegate?.didForm(event: .text(string))
        } else {
          let errCode = CloseCode.protocolError.rawValue
          self.delegate?.didForm(event: .error(WSError(type: .protocolError, message: "not valid UTF-8 data", code: errCode)))
        }
      } else {
        self.delegate?.didForm(event: .binary(self.buffer))
      }
      self.reset()
    }
  }

  func reset() {
    self.buffer = Data()
    self.frameCount = 0
  }
}
