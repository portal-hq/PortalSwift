//
//  PasskeyPrfTypes.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// The client's Passkey PRF credential record, as Portal stores it at
/// `/api/v3/clients/me/passkey-prf-credential`.
///
/// The record is write-once: it binds the client to the one passkey its backups are encrypted
/// with, under the relying party that passkey belongs to.
public struct PasskeyPrfCredential: Codable, Equatable {
  /// The WebAuthn credential ID, as unpadded base64url.
  public let credentialId: String
  /// The relying party ID the passkey was created under, lowercase.
  public let rpId: String
  /// The transports the authenticator reported, when it reported any.
  public let transports: [String]?

  public init(credentialId: String, rpId: String, transports: [String]? = nil) {
    self.credentialId = credentialId
    self.rpId = rpId
    self.transports = transports
  }

  /// Leaves `transports` out of the body when absent, as the other SDKs do.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.credentialId, forKey: .credentialId)
    try container.encode(self.rpId, forKey: .rpId)
    try container.encodeIfPresent(self.transports, forKey: .transports)
  }
}

/// Portal wraps the record as `{ "data": { ... }, "metadata": { ... } }`.
struct PasskeyPrfCredentialEnvelope: Decodable {
  let data: PasskeyPrfCredential
}

/// The user a Passkey PRF passkey is created for, as shown by the passkey provider.
public struct PasskeyPrfUser: Equatable {
  public let name: String
  public let displayName: String

  public init(name: String, displayName: String) {
    self.name = name
    self.displayName = displayName
  }
}

public enum PasskeyPrfConstants {
  /// The salt every Portal SDK evaluates the passkey's PRF with: `SHA-256("portal.backup.prf.v1")`.
  ///
  /// A backup can only be recovered by evaluating the same salt, so this value is part of the
  /// backup format. It is passed to the platform as the WebAuthn PRF `eval.first` input; the
  /// platform applies the WebAuthn `SHA-256("WebAuthn PRF" || 0x00 || salt)` transform itself.
  public static let saltHex = "e8cdf823f6ba01756590c8a09d9da3777b2ade5e40129a2f8ad8097d2945ce0f"
  public static let defaultRelyingParty = "portalhq.io"
  public static let defaultRelyingPartyName = "Portal"
  /// The first iOS release whose passkey APIs evaluate the PRF extension.
  public static let minimumIOSMajorVersion = 18
  /// The length of a PRF output, and of the salt.
  static let outputLength = 32
  /// Waits before the second and third attempt to store the credential record, so a brief 503
  /// or a 429 has time to clear. Matches the React Native SDK.
  static let storeRetryDelaysMs: [UInt64] = [250, 1000]

  static var salt: Data {
    // The constant is valid hex; force-unwrapping documents that.
    PasskeyPrfEncoding.data(fromHex: saltHex)!
  }
}

enum PasskeyPrfEncoding {
  /// Lowercase hex, two characters per byte.
  static func hex<Bytes: Sequence>(_ bytes: Bytes) -> String where Bytes.Element == UInt8 {
    let digits = Array("0123456789abcdef".utf8)
    var characters: [UInt8] = []
    characters.reserveCapacity(64)
    for byte in bytes {
      characters.append(digits[Int(byte >> 4)])
      characters.append(digits[Int(byte & 0x0F)])
    }
    let string = String(decoding: characters, as: UTF8.self)
    // Clear the scratch buffer holding the secret's characters.
    for index in characters.indices {
      characters[index] = 0
    }
    return string
  }

  static func data(fromHex hex: String) -> Data? {
    let characters = Array(hex.utf8)
    guard characters.count % 2 == 0 else { return nil }
    var bytes = Data(capacity: characters.count / 2)
    var index = 0
    while index < characters.count {
      guard let high = nibble(characters[index]), let low = nibble(characters[index + 1]) else {
        return nil
      }
      bytes.append(high << 4 | low)
      index += 2
    }
    return bytes
  }

  /// Unpadded base64url, the encoding Portal stores credential IDs in.
  static func base64Url(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  /// Decodes canonical unpadded base64url. Rejects padding, the standard alphabet, and any
  /// string that does not re-encode to itself, so an ID cannot alias another.
  static func data(fromBase64Url value: String) -> Data? {
    guard !value.isEmpty,
          value.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") })
    else {
      return nil
    }
    var base64 = value
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    let remainder = base64.count % 4
    if remainder == 1 {
      return nil
    }
    if remainder > 0 {
      base64.append(String(repeating: "=", count: 4 - remainder))
    }
    guard let data = Data(base64Encoded: base64), base64Url(data) == value else {
      return nil
    }
    return data
  }

  private static func nibble(_ character: UInt8) -> UInt8? {
    switch character {
    case UInt8(ascii: "0") ... UInt8(ascii: "9"):
      return character - UInt8(ascii: "0")
    case UInt8(ascii: "a") ... UInt8(ascii: "f"):
      return character - UInt8(ascii: "a") + 10
    case UInt8(ascii: "A") ... UInt8(ascii: "F"):
      return character - UInt8(ascii: "A") + 10
    default:
      return nil
    }
  }
}
