//
//  ClientRegistration.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// The body of `POST {custodianServerUrl}/clients/register`.
///
/// `username` is the Portal `endUserId`: the demo custodian keys its own users by whatever the
/// app calls a username, and for a Client Auth session the only stable identity the app holds
/// is the end user id. The call is idempotent, so a resumed session re-registers with the same
/// payload and gets the same exchange user back.
struct ClientRegistrationRequest: Codable, Equatable {
  /// The Portal Client id this session resolved to.
  let clientId: String
  /// The end user id, used as the custodian's username.
  let username: String
  /// Whether the client is account-abstracted, echoed from the Portal client.
  let isAccountAbstracted: Bool
}

/// The custodian's `exchangeUserId` as it actually arrives on the wire.
///
/// Some PortalEx deployments send it as a JSON string and others as a JSON number, and neither
/// is wrong. Decoding it as a `String` would throw on half of them and decoding it as an `Int`
/// on the other half, so the value keeps its JSON shape until
/// `normalizeExchangeUserId(_:)` renders it — which is also where the "`619692` must not become
/// `619692.0`" rule lives, since a `619692.0` in a custodian path 404s on every route.
///
/// Integers are tried as `Int64` before anything falls back to `Double`: a `Double` only holds
/// 53 bits of integer exactly, so an id above 2^53 decoded through it would round to a
/// neighbouring value and the path would name another user. `Double` remains the shape for a
/// number that is not an `Int64` — one with a fraction, or one beyond `Int64`'s range.
///
/// `other` rather than a thrown `DecodingError` for any third shape: a custodian that answers
/// with something unexpected costs this session its self-managed backup store, which adoption
/// reports and continues past. It must not fail the decode of the whole response and take the
/// login with it.
enum ExchangeUserIdValue: Decodable, Equatable {
  /// A JSON string, verbatim.
  case string(String)
  /// A JSON integer that fits `Int64`, exactly.
  case integer(Int64)
  /// Any other JSON number, as a `Double`: fractional, or outside `Int64`'s range.
  case number(Double)
  /// Any other JSON type (a bool, an object, an array). Unusable, but not fatal.
  case other

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if let value = try? container.decode(String.self) {
      self = .string(value)
      return
    }

    // Before `Double`, so the integer is never rounded on the way in. A number with a fraction
    // or one beyond `Int64` fails this decode and falls through.
    if let value = try? container.decode(Int64.self) {
      self = .integer(value)
      return
    }

    if let value = try? container.decode(Double.self) {
      self = .number(value)
      return
    }

    self = .other
  }
}

/// What `POST /clients/register` returns.
///
/// Every field is optional: the response is a demo server's, the only field the app reads is
/// `exchangeUserId`, and a missing `clientId` or `username` is not worth failing a login over.
struct ClientRegistrationResponse: Decodable {
  /// The Portal Client id the custodian recorded, when it echoed one.
  let clientId: String?
  /// The custodian's id for this user, in whatever JSON shape it arrived.
  let exchangeUserId: ExchangeUserIdValue?
  /// The username the custodian recorded, when it echoed one.
  let username: String?
}

/// The part of a registration the adoption flow consumes.
///
/// A separate type from `ClientRegistrationResponse` so the transport — a real HTTP call in the
/// app, a closure in the tests — is the only thing that has to know the wire shape.
struct ClientRegistrationResult: Equatable {
  /// The custodian's id for this user, still in its JSON shape.
  let exchangeUserId: ExchangeUserIdValue?

  /// Memberwise initializer, spelled out because the type is consumed from another file.
  init(exchangeUserId: ExchangeUserIdValue?) {
    self.exchangeUserId = exchangeUserId
  }
}

/// Renders the custodian's `exchangeUserId` as a `String`, or `nil` when it is unusable.
///
/// Integers are the common case and the easy one: an `Int64` prints exactly, with no decimal
/// point and no exponent, whatever its size.
///
/// The remaining numbers are the interesting half. A JSON `619692.0` decodes as a `Double`, and
/// `String(619692.0)` is `"619692.0"` — an id that every custodian route 404s on. Integral
/// values therefore go through `Int64`, which also keeps large ids out of Swift's exponent
/// notation (`String(1e15)` is `"1e+15"`, and `/mobile/1e+15/cipher-text` is not a path).
/// Non-integral values are written as-is, because a custodian that really does key users by
/// `61.5` is better served by an id that round-trips than by a silent `nil`.
///
/// Strings are trimmed and never re-parsed: `"42.0"` stays `"42.0"`, because the custodian that
/// sent a string chose that spelling and the path has to match it byte for byte.
func normalizeExchangeUserId(_ value: ExchangeUserIdValue?) -> String? {
  switch value {
  case let .some(.string(text)):
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed

  case let .some(.integer(integer)):
    return String(integer)

  case let .some(.number(number)):
    guard number.isFinite else {
      return nil
    }

    // `Int64(exactly:)` covers every id a custodian could plausibly issue and renders it
    // without a decimal point or an exponent. `-0.0` lands on `0` through it, which is the
    // reading anyone would expect. Beyond `Int64`'s range the value is still integral, so it is
    // printed with no fractional digits rather than dropped.
    if number == number.rounded(.towardZero) {
      if let integral = Int64(exactly: number) {
        return String(integral)
      }

      return String(format: "%.0f", number)
    }

    return String(number)

  case .some(.other), .none:
    return nil
  }
}
