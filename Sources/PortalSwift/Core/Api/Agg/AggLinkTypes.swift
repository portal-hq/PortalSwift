//
//  AggLinkTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// A Sign-In with Ethereum challenge. Sign `signParams` verbatim with `personal_sign` and send the
/// signature to `createLink` before `expiresAt`.
public struct AggLinkChallenge: Codable, Equatable {
  /// The sign-in message, for display.
  public let message: String
  /// `[hexMessage, address]`, ready for `personal_sign`.
  public let signParams: [String]
  /// When the challenge stops being accepted.
  public let expiresAt: String

  public init(message: String, signParams: [String], expiresAt: String) {
    self.message = message
    self.signParams = signParams
    self.expiresAt = expiresAt
  }
}

/// A completed link between the client's wallet and its Agg account.
public struct AggLink: Codable, Equatable {
  /// Always `true`.
  public let linked: Bool
  public let aggUserId: String
  public let linkedAddress: String
  /// CAIP-2 chain the sign-in message named.
  public let linkedChainId: String
  public let externalIdLinked: Bool

  public init(
    linked: Bool,
    aggUserId: String,
    linkedAddress: String,
    linkedChainId: String,
    externalIdLinked: Bool
  ) {
    self.linked = linked
    self.aggUserId = aggUserId
    self.linkedAddress = linkedAddress
    self.linkedChainId = linkedChainId
    self.externalIdLinked = externalIdLinked
  }
}

/// The result of unlinking.
public struct AggUnlink: Codable, Equatable {
  /// Always `false`.
  public let linked: Bool

  public init(linked: Bool) {
    self.linked = linked
  }
}

/// The link as `GET /link` reports it, discriminated on `linked`. The Portal API checks the session
/// with Agg, so `.notLinked` also covers an expired session. Only when Agg cannot be reached does it
/// report the stored link, and a session call can then still fail with `AGG_LINK_REQUIRED`.
public enum AggLinkStatus: Codable, Equatable {
  /// `linked: false`.
  case notLinked
  /// `linked: true`.
  case linked(Linked)

  public struct Linked: Codable, Equatable {
    public let aggUserId: String
    public let linkedAddress: String
    /// CAIP-2 chain the sign-in message named.
    public let linkedChainId: String
    public let linkedAt: String

    public init(aggUserId: String, linkedAddress: String, linkedChainId: String, linkedAt: String) {
      self.aggUserId = aggUserId
      self.linkedAddress = linkedAddress
      self.linkedChainId = linkedChainId
      self.linkedAt = linkedAt
    }
  }

  /// The wire discriminator.
  public var isLinked: Bool {
    if case .linked = self {
      return true
    }
    return false
  }

  private enum CodingKeys: String, CodingKey {
    case linked
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if try container.decode(Bool.self, forKey: .linked) {
      self = try .linked(Linked(from: decoder))
    } else {
      self = .notLinked
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .notLinked:
      try container.encode(false, forKey: .linked)
    case let .linked(value):
      try container.encode(true, forKey: .linked)
      try value.encode(to: encoder)
    }
  }
}
